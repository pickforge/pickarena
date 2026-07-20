import 'dart:async';
import 'dart:io';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/factory_custom_model_environment.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/bounded_subprocess.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class DroidProcessResult {
  const DroidProcessResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
  final String stdout;
  final String stderr;
  final int exitCode;
}

typedef DroidProcessRunner =
    Future<DroidProcessResult> Function(
      String executable,
      List<String> arguments,
      Duration? timeout,
    );

class DroidExecProvider implements ModelProvider, ModelRuntimeMetadataProvider {
  DroidExecProvider({
    DroidProcessRunner? runner,
    String? droidPath,
    Iterable<String> deniedEnvironmentKeys = const [],
    int maxProcessOutputChars = 1024 * 1024,
  }) : _runner = runner,
       _exe = droidPath ?? _findDroid(),
       _deniedEnvironmentKeys = {...deniedEnvironmentKeys},
       _maxProcessOutputChars = maxProcessOutputChars,
       assert(maxProcessOutputChars > 0);

  static String _findDroid() {
    // Desktop apps don't inherit shell PATH; try common locations.
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final candidates = [
      '$home/.local/bin/droid',
      '$home/.npm-global/bin/droid',
      '/usr/local/bin/droid',
      'droid', // fallback: hope it's in PATH
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return 'droid';
  }

  static Future<DroidProcessResult> _defaultRunner(
    String exe,
    List<String> args,
    Duration? timeout,
    Iterable<String> deniedEnvironmentKeys,
    Iterable<String> allowedSensitiveEnvironmentKeys,
    int maxProcessOutputChars,
  ) async {
    final processResult = await runBoundedSubprocess(
      executable: exe,
      arguments: args,
      workingDirectory: Directory.current.path,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: deniedEnvironmentKeys,
        allowedSensitiveKeys: allowedSensitiveEnvironmentKeys,
      ),
      maxOutputBytes: maxEncodedOutputBytes(maxProcessOutputChars),
      maxOutputCharacters: maxProcessOutputChars,
      timeout: timeout,
      capture: BoundedSubprocessCapture.trailing,
    );
    if (processResult.termination == BoundedSubprocessTermination.timedOut) {
      throw TimeoutException('droid exec timed out', timeout);
    }
    final stderrWithLimit = processResult.outputLimitExceeded
        ? [
            'droid exec output exceeded $maxProcessOutputChars characters',
            if (processResult.stderr.isNotEmpty) processResult.stderr,
          ].join('\n')
        : processResult.stderr;
    return DroidProcessResult(
      stdout: processResult.stdout,
      stderr: stderrWithLimit,
      exitCode: processResult.outputLimitExceeded && processResult.exitCode == 0
          ? -1
          : processResult.exitCode,
    );
  }

  static String _diagnosticHint({
    required String model,
    required String stderr,
  }) {
    final hints = <String>[];
    if (stderr.trim() == 'Error during droid execution: Exec failed') {
      hints.add(
        'Droid CLI returned only its generic wrapper error; inspect the latest '
        'Droid session log for the detailed cause.',
      );
    }
    if (model.startsWith('custom:')) {
      hints.add(
        'The selected model is a Droid custom/BYOK model; verify its API key '
        'and base URL in Factory settings, or use a built-in model such as '
        'gpt-5.5 or gpt-5.3-codex.',
      );
    }
    if (hints.isEmpty) return '';
    return '  hint       : ${hints.join(' ')}\n';
  }

  final DroidProcessRunner? _runner;
  final String _exe;
  final Set<String> _deniedEnvironmentKeys;
  final int _maxProcessOutputChars;
  static const String _directAutonomyMode = 'medium';
  static const String _directOutputFormat = 'text';

  void addDeniedEnvironmentKeys(Iterable<String> keys) {
    _deniedEnvironmentKeys.addAll(keys);
  }

  @override
  String get id => 'droid';
  @override
  String get displayName => 'Factory Droid';
  @override
  ProviderMode get mode => ProviderMode.agent;

  @override
  Map<String, Object?> providerRuntimeConfig() => {
    'providerMode': mode.name,
    'execution': 'droid_exec',
    'secretsRedacted': true,
  };

  @override
  Map<String, Object?> modelRuntimeConfig(String modelId) => {
    ...factoryCustomModelRuntimeConfig(modelId),
    'executionMode': 'direct_prompt',
    'autonomyMode': _directAutonomyMode,
    'outputFormat': _directOutputFormat,
    'temperature': {'configured': false, 'status': 'provider_default'},
    'toolsEnabled': false,
    'toolPolicy': 'disabled',
  };

  @override
  void dispose() {}

  @override
  Future<List<ModelInfo>> listModels() async {
    const builtIn = [
      ModelInfo(id: 'gpt-5.5'),
      ModelInfo(id: 'gpt-5.4'),
      ModelInfo(id: 'gpt-5.3-codex'),
      ModelInfo(id: 'claude-sonnet-4-6'),
      ModelInfo(id: 'claude-opus-4-7'),
      ModelInfo(id: 'gemini-3-flash'),
    ];
    final settings = readFactorySettings();
    if (settings == null) return builtIn;
    final customModels = settings['customModels'];
    if (customModels is! List) return builtIn;
    final customs = <ModelInfo>[];
    for (final item in customModels) {
      if (item is! Map) continue;
      final id = item['id'];
      final model = item['model'];
      if (id is String) {
        customs.add(ModelInfo(id: id));
      } else if (model is String) {
        customs.add(ModelInfo(id: model));
      }
    }
    return [...builtIn, ...customs];
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    final directPrompt =
        'Do not use tools, inspect files, run commands, or edit the repository. '
        'Answer directly from the prompt.\n\n$prompt';
    final args = [
      'exec',
      '--auto',
      _directAutonomyMode,
      '--enabled-tools',
      '',
      '--output-format',
      _directOutputFormat,
      '--model',
      model,
      directPrompt,
    ];
    final res = _runner == null
        ? await _defaultRunner(
            _exe,
            args,
            timeout,
            _deniedEnvironmentKeys,
            factoryCustomModelEnvironmentReferences(model),
            _maxProcessOutputChars,
          )
        : await _runner(_exe, args, timeout);
    sw.stop();
    if (res.exitCode != 0) {
      final stdoutPreview = res.stdout.substring(
        0,
        res.stdout.length.clamp(0, 4000),
      );
      final stderrPreview = res.stderr.substring(
        0,
        res.stderr.length.clamp(0, 4000),
      );
      throw Exception(
        'droid exec failed\n'
        '  exit code  : ${res.exitCode}\n'
        '  model      : $model\n'
        '  executable : configured droid executable\n'
        '  argc       : ${args.length}\n'
        '  promptLen  : ${directPrompt.length}\n'
        '  duration   : ${sw.elapsedMilliseconds}ms\n'
        '${_diagnosticHint(model: model, stderr: res.stderr)}'
        '  stdout (${res.stdout.length}B):\n'
        '$stdoutPreview\n'
        '  stderr (${res.stderr.length}B):\n'
        '$stderrPreview',
      );
    }
    return ModelResponse(
      rawText: res.stdout,
      extractedCode: null,
      promptTokens: null,
      completionTokens: null,
      latency: sw.elapsed,
    );
  }
}
