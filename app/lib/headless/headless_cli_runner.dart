import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/command_template_agent_harness.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/agent/minimal_agent_harness.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/headless/headless_benchmark_runner.dart';
import 'package:dart_arena/headless/headless_cli_config.dart';
import 'package:dart_arena/providers/anthropic_provider.dart';
import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dart_arena/providers/openai_provider.dart';
import 'package:dart_arena/providers/opencode_go_provider.dart';
import 'package:dart_arena/providers/openrouter_provider.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/plan_dao.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

typedef HeadlessCliLineWriter = void Function(String line);
typedef HeadlessCliEnvironmentReader = String? Function(String name);
typedef HeadlessCliProviderBuilder =
    ModelProvider Function(HeadlessCliProviderConfig config, String? apiKey);
typedef HeadlessCliTaskRegistryBuilder = TaskRegistry Function();
typedef HeadlessCliAgentHarnessBuilder =
    List<AgentHarness> Function(
      HeadlessCliConfig config,
      List<ModelProvider> providers,
      GeneratedCodeSandbox? generatedCodeSandbox,
    );
typedef HeadlessCliGeneratedCodeSandboxBuilder =
    Future<GeneratedCodeSandbox?> Function(HeadlessCliConfig config);

class HeadlessCliDependencies {
  const HeadlessCliDependencies({
    this.environmentReader = _platformEnvironmentReader,
    this.providerBuilder = _defaultProviderBuilder,
    this.taskRegistryBuilder = _emptyTaskRegistry,
    this.agentHarnessBuilder = _defaultAgentHarnessBuilder,
    this.now = _now,
    this.provenanceEnvironmentProviderBuilder =
        _defaultProvenanceEnvironmentProviderBuilder,
    this.exportEnvironmentProvider = _defaultExportEnvironmentProvider,
    this.exportAppVersionProvider = _defaultExportAppVersionProvider,
    this.generatedCodeSandboxBuilder = _defaultGeneratedCodeSandboxBuilder,
    this.runner = const HeadlessBenchmarkRunner(),
  });

  final HeadlessCliEnvironmentReader environmentReader;
  final HeadlessCliProviderBuilder providerBuilder;
  final HeadlessCliTaskRegistryBuilder taskRegistryBuilder;
  final HeadlessCliAgentHarnessBuilder agentHarnessBuilder;
  final DateTime Function() now;
  final RunProvenanceEnvironmentProvider Function()
  provenanceEnvironmentProviderBuilder;
  final Future<Map<String, Object?>> Function() exportEnvironmentProvider;
  final Future<String> Function() exportAppVersionProvider;
  final HeadlessCliGeneratedCodeSandboxBuilder generatedCodeSandboxBuilder;
  final HeadlessBenchmarkRunner runner;
}

TaskRegistry _emptyTaskRegistry() => TaskRegistry();

Future<int> runHeadlessCli(
  List<String> args, {
  HeadlessCliDependencies dependencies = const HeadlessCliDependencies(),
  HeadlessCliLineWriter? stdoutWriter,
  HeadlessCliLineWriter? stderrWriter,
}) async {
  final out = stdoutWriter ?? stdout.writeln;
  final err = stderrWriter ?? stderr.writeln;
  final secrets = <String>{};
  AppDatabase? database;
  List<ModelProvider> providers = const [];
  var runnerInvoked = false;

  try {
    final configPath = _parseConfigArg(args);
    if (configPath == null) {
      out(jsonEncode(_helpJson()));
      return 0;
    }

    final cliConfig = await loadHeadlessCliConfig(File(configPath));
    final generatedCodeSandbox = await dependencies.generatedCodeSandboxBuilder(
      cliConfig,
    );
    final registry = dependencies.taskRegistryBuilder();
    await _registerFileBackedTasks(registry, cliConfig.taskBundleRoots);
    final tasks = [
      for (final taskId in cliConfig.tasks) _resolveTask(registry, taskId),
    ];
    providers = _buildProviders(cliConfig, dependencies, secrets);
    final providersById = {
      for (final provider in providers) provider.id: provider,
    };
    final judge = cliConfig.judge;
    final evaluatorConfig = judge == null
        ? const EvaluatorConfig()
        : EvaluatorConfig(
            judgeProvider: providersById[judge.providerId],
            judgeModel: judge.model,
          );

    await Directory(p.dirname(cliConfig.databasePath)).create(recursive: true);
    await Directory(cliConfig.outputDir).create(recursive: true);
    database = AppDatabase(NativeDatabase(File(cliConfig.databasePath)));

    final agentHarnesses = dependencies.agentHarnessBuilder(
      cliConfig,
      providers,
      generatedCodeSandbox,
    );
    runnerInvoked = true;
    final result = await dependencies.runner.run(
      HeadlessBenchmarkConfig(
        runId: cliConfig.runId,
        name: cliConfig.name,
        tasks: tasks,
        providers: providers,
        modelsByProvider: {
          for (final provider in cliConfig.providers)
            provider.id: provider.models,
        },
        agentHarnesses: agentHarnesses,
        agentHarnessProvenance: {
          for (final harness in agentHarnesses)
            harness.id: _agentHarnessProvenance(harness),
        },
        evaluatorConfig: evaluatorConfig,
        evaluatorWeights: cliConfig.evaluatorWeights,
        workdirManager: WorkdirManager(
          root: Directory(cliConfig.workdirRoot),
          deniedEnvironmentKeys: _configuredApiKeyEnvNames(cliConfig),
        ),
        runDao: RunDao(database),
        planDao: PlanDao(database),
        bundleOutputParent: Directory(cliConfig.outputDir),
        now: dependencies.now,
        idGenerator: () => cliConfig.runId,
        provenanceEnvironmentProvider: dependencies
            .provenanceEnvironmentProviderBuilder(),
        exportEnvironmentProvider: dependencies.exportEnvironmentProvider,
        exportAppVersionProvider: dependencies.exportAppVersionProvider,
        allowedTrajectoryRoots: [
          Directory(p.join(cliConfig.workdirRoot, 'runs')),
        ],
        maxConcurrency: cliConfig.maxConcurrency,
        trialsPerTask: cliConfig.trialsPerTask,
        useReferencePlan: cliConfig.useReferencePlan,
        generatedCodeSandboxRequired: cliConfig.requireGeneratedCodeSandbox,
        generatedCodeSandboxEnforced: generatedCodeSandbox != null,
        generatedCodeSandboxBackend: generatedCodeSandbox?.backend,
        generatedCodeSandbox: generatedCodeSandbox,
        timeout: cliConfig.timeout,
      ),
    );

    out(
      jsonEncode({
        'status': 'completed',
        'runId': result.runId,
        'bundlePath': p.normalize(
          p.absolute(result.exportedBundleDirectory.path),
        ),
        'taskRunCount': result.taskRunCount,
        'evaluationCount': result.evaluationCount,
        'bundleWarningCount': result.bundleWarningCount,
      }),
    );
    return 0;
  } on Object catch (error) {
    err(
      jsonEncode({
        'status': 'failed',
        'error': _redactSecrets(error.toString(), secrets),
      }),
    );
    if (!runnerInvoked) {
      for (final provider in providers) {
        provider.dispose();
      }
    }
    return 1;
  } finally {
    await database?.close();
  }
}

Future<GeneratedCodeSandbox?> _defaultGeneratedCodeSandboxBuilder(
  HeadlessCliConfig config,
) async {
  if (!config.requireGeneratedCodeSandbox) return null;
  await BubblewrapGeneratedCodeSandbox.ensureAvailable();
  return const BubblewrapGeneratedCodeSandbox();
}

Iterable<String> _configuredApiKeyEnvNames(HeadlessCliConfig config) sync* {
  for (final provider in config.providers) {
    final apiKeyEnv = provider.apiKeyEnv;
    if (apiKeyEnv != null && apiKeyEnv.isNotEmpty) yield apiKeyEnv;
  }
}

Future<void> _registerFileBackedTasks(
  TaskRegistry registry,
  List<String> taskBundleRoots,
) async {
  for (final root in taskBundleRoots) {
    final tasks = await loadFileBackedTasks(Directory(root));
    for (final task in tasks) {
      registry.register(task);
    }
  }
}

String? _parseConfigArg(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    return null;
  }
  String? configPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--config') {
      if (i + 1 >= args.length) {
        throw const HeadlessCliConfigException('--config requires a path');
      }
      if (configPath != null) {
        throw const HeadlessCliConfigException(
          '--config may only be provided once',
        );
      }
      configPath = args[++i];
    } else {
      throw HeadlessCliConfigException('unknown argument: $arg');
    }
  }
  if (configPath == null) {
    throw const HeadlessCliConfigException('--config is required');
  }
  return configPath;
}

Map<String, Object?> _helpJson() {
  return const {
    'status': 'help',
    'usage':
        'dart run --verbosity=error dart_arena:dart_arena_headless --config run.json',
    'options': [
      {'name': '--config', 'value': 'path', 'required': true},
      {'name': '--help', 'required': false},
    ],
    'configFormat': 'json',
  };
}

List<ModelProvider> _buildProviders(
  HeadlessCliConfig config,
  HeadlessCliDependencies dependencies,
  Set<String> secrets,
) {
  final deniedEnvNames = _configuredApiKeyEnvNames(config).toList();
  return [
    for (final providerConfig in config.providers)
      _withProviderDeniedEnvironmentKeys(
        dependencies.providerBuilder(
          providerConfig,
          _readApiKey(providerConfig, dependencies.environmentReader, secrets),
        ),
        deniedEnvNames,
      ),
  ];
}

ModelProvider _withProviderDeniedEnvironmentKeys(
  ModelProvider provider,
  Iterable<String> deniedEnvNames,
) {
  if (provider is DroidExecProvider) {
    provider.addDeniedEnvironmentKeys(deniedEnvNames);
  }
  return provider;
}

String? _readApiKey(
  HeadlessCliProviderConfig provider,
  HeadlessCliEnvironmentReader environmentReader,
  Set<String> secrets,
) {
  final envName = provider.apiKeyEnv;
  if (envName == null || envName.isEmpty) return null;
  final value = environmentReader(envName);
  if (value == null || value.isEmpty) {
    throw HeadlessCliConfigException('missing environment variable: $envName');
  }
  secrets.add(value);
  return value;
}

String _redactSecrets(String value, Set<String> secrets) {
  var redacted = value;
  for (final secret in secrets) {
    if (secret.isNotEmpty) {
      redacted = redacted.replaceAll(secret, '[redacted]');
    }
  }
  return redacted;
}

ModelProvider _defaultProviderBuilder(
  HeadlessCliProviderConfig config,
  String? apiKey,
) {
  switch (config.type) {
    case 'openai':
      return OpenAIProvider(apiKey: apiKey!);
    case 'openrouter':
      return OpenRouterProvider(apiKey: apiKey!);
    case 'deepseek':
      return DeepSeekProvider(apiKey: apiKey!);
    case 'anthropic':
      return AnthropicProvider(apiKey: apiKey!);
    case 'opencode_go':
      return OpenCodeGoProvider(apiKey: apiKey!);
    case 'ollama_local':
      return OllamaProvider(
        id: config.id,
        displayName: config.displayName,
        baseUrl: config.baseUrl ?? 'http://localhost:11434',
        apiKey: apiKey,
      );
    case 'ollama_cloud':
      return OllamaProvider(
        id: config.id,
        displayName: config.displayName,
        baseUrl: config.baseUrl ?? 'https://ollama.com',
        apiKey: apiKey!,
      );
    case 'openai_compatible':
      return OpenAiCompatibleProvider(
        null,
        id: config.id,
        displayName: config.displayName,
        baseUrl: config.baseUrl!,
        apiKey: apiKey ?? '',
        extraHeaders: config.extraHeaders,
        defaultEfforts: config.defaultEfforts,
      );
    case 'droid':
      return DroidExecProvider();
    case 'agent_cli':
      return _AgentCliProvider(config);
    default:
      throw HeadlessCliConfigException(
        'unsupported provider type: ${config.type}',
      );
  }
}

List<AgentHarness> _defaultAgentHarnessBuilder(
  HeadlessCliConfig config,
  List<ModelProvider> providers,
  GeneratedCodeSandbox? generatedCodeSandbox,
) {
  final providersById = {
    for (final provider in providers) provider.id: provider,
  };
  return [
    for (final configProvider in config.providers)
      if (configProvider.harness == 'droid' ||
          (configProvider.harness == null && configProvider.type == 'droid'))
        DroidAgentHarness(
          deniedEnvironmentKeys: _configuredApiKeyEnvNames(config),
          generatedCodeSandbox: generatedCodeSandbox,
        )
      else if (configProvider.harness == 'minimal' ||
          configProvider.harness == null)
        _minimalHarness(
          configProvider,
          providersById[configProvider.id],
          config,
          generatedCodeSandbox,
        )
      else if (configProvider.commandTemplate != null ||
          CommandTemplateAgentConfig.presets.containsKey(
            configProvider.harness,
          ))
        CommandTemplateAgentHarness(
          providerId: configProvider.id,
          config:
              configProvider.commandTemplate ??
              CommandTemplateAgentConfig.preset(
                configProvider.harness!,
                version: configProvider.agentVersion!,
              ),
          deniedEnvironmentKeys: _configuredApiKeyEnvNames(config),
          allowedSensitiveEnvironmentKeys: [
            if (configProvider.apiKeyEnv != null) configProvider.apiKeyEnv!,
          ],
          generatedCodeSandbox: generatedCodeSandbox,
        ),
  ];
}

class _AgentCliProvider implements ModelProvider {
  const _AgentCliProvider(this.config);

  final HeadlessCliProviderConfig config;

  @override
  String get id => config.id;

  @override
  String get displayName => config.displayName;

  @override
  ProviderMode get mode => ProviderMode.agent;

  @override
  Future<List<ModelInfo>> listModels() async => [
    for (final model in config.models) ModelInfo(id: model),
  ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) => throw StateError(
    'agent_cli providers are only available via an agent harness',
  );

  @override
  void dispose() {}
}

AgentHarness _minimalHarness(
  HeadlessCliProviderConfig configProvider,
  ModelProvider? provider,
  HeadlessCliConfig config,
  GeneratedCodeSandbox? generatedCodeSandbox,
) {
  if (provider is! StreamingModelProvider) {
    throw HeadlessCliConfigException(
      'providers with harness "minimal" must support streaming: '
      '${configProvider.id}',
    );
  }
  return MinimalAgentHarness(
    provider: provider,
    harnessId: configProvider.id,
    deniedEnvironmentKeys: _configuredApiKeyEnvNames(config),
    generatedCodeSandbox: generatedCodeSandbox,
    requireGeneratedCodeSandbox: config.requireGeneratedCodeSandbox,
  );
}

BenchmarkTask _resolveTask(TaskRegistry registry, String taskId) {
  final task = registry.byId(taskId);
  if (task == null) {
    throw HeadlessCliConfigException('unknown task id: $taskId');
  }
  return task;
}

String? _platformEnvironmentReader(String name) => Platform.environment[name];

Map<String, Object?> _agentHarnessProvenance(AgentHarness harness) {
  if (harness is AgentHarnessProvenance) {
    return (harness as AgentHarnessProvenance).provenance;
  }
  return const {'kind': 'unknown', 'track': 'scaffold-dependent'};
}

DateTime _now() => DateTime.now();

RunProvenanceEnvironmentProvider
_defaultProvenanceEnvironmentProviderBuilder() {
  return DefaultRunProvenanceEnvironmentProvider();
}

Future<Map<String, Object?>> _defaultExportEnvironmentProvider() {
  return DefaultRunProvenanceEnvironmentProvider().capture();
}

Future<String> _defaultExportAppVersionProvider() async {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (await pubspec.exists()) {
      for (final line in await pubspec.readAsLines()) {
        final trimmed = line.trim();
        if (trimmed.startsWith('version:')) {
          return trimmed.substring('version:'.length).trim();
        }
      }
      return 'unknown';
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return 'unknown';
}
