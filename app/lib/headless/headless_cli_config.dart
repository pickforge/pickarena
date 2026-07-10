import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/path_safety.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/agent/command_template_agent_harness.dart';
import 'package:path/path.dart' as p;

class HeadlessCliConfigException implements Exception {
  const HeadlessCliConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HeadlessCliConfig {
  const HeadlessCliConfig({
    required this.configPath,
    required this.runId,
    required this.tasks,
    required this.providers,
    required this.evaluatorWeights,
    required this.workdirRoot,
    required this.outputDir,
    required this.databasePath,
    required this.timeout,
    this.name,
    this.judge,
    this.taskBundleRoots = const [],
    this.maxConcurrency = 4,
    this.trialsPerTask = 1,
    this.useReferencePlan = false,
    this.requireGeneratedCodeSandbox = false,
  });

  final String configPath;
  final String runId;
  final String? name;
  final List<String> tasks;
  final List<HeadlessCliProviderConfig> providers;
  final HeadlessCliJudgeConfig? judge;
  final List<String> taskBundleRoots;
  final Map<String, double> evaluatorWeights;
  final int maxConcurrency;
  final int trialsPerTask;
  final bool useReferencePlan;
  final bool requireGeneratedCodeSandbox;
  final String workdirRoot;
  final String outputDir;
  final String databasePath;
  final Duration timeout;
}

class HeadlessCliProviderConfig {
  const HeadlessCliProviderConfig({
    required this.type,
    required this.id,
    required this.displayName,
    required this.models,
    this.apiKeyEnv,
    this.baseUrl,
    this.harness,
    this.commandTemplate,
    this.agentVersion,
    this.defaultEfforts = const [],
    this.extraHeaders = const {},
  });

  final String type;
  final String id;
  final String displayName;
  final List<String> models;
  final String? apiKeyEnv;
  final String? baseUrl;
  final String? harness;
  final CommandTemplateAgentConfig? commandTemplate;
  final String? agentVersion;
  final List<String> defaultEfforts;
  final Map<String, String> extraHeaders;
}

class HeadlessCliJudgeConfig {
  const HeadlessCliJudgeConfig({required this.providerId, required this.model});

  final String providerId;
  final String model;
}

Future<HeadlessCliConfig> loadHeadlessCliConfig(File file) async {
  Object? decoded;
  try {
    decoded = jsonDecode(await file.readAsString());
  } on FormatException catch (e) {
    throw HeadlessCliConfigException('invalid JSON: ${e.message}');
  } on FileSystemException catch (e) {
    throw HeadlessCliConfigException('unable to read config: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw const HeadlessCliConfigException('config must be a JSON object');
  }
  return parseHeadlessCliConfig(
    decoded,
    configPath: p.normalize(p.absolute(file.path)),
  );
}

HeadlessCliConfig parseHeadlessCliConfig(
  Map<String, Object?> json, {
  required String configPath,
}) {
  final configDir = p.dirname(p.normalize(p.absolute(configPath)));
  final runId = _requiredString(json, 'runId');
  _validateSafeSegment(runId, 'runId');

  final tasks = _requiredStringList(json, 'tasks');
  if (tasks.isEmpty) {
    throw const HeadlessCliConfigException('tasks must not be empty');
  }

  final providersJson = _requiredList(json, 'providers');
  if (providersJson.isEmpty) {
    throw const HeadlessCliConfigException('providers must not be empty');
  }
  final providers = <HeadlessCliProviderConfig>[];
  final providerIds = <String>{};
  for (var i = 0; i < providersJson.length; i++) {
    final item = providersJson[i];
    if (item is! Map<String, Object?>) {
      throw HeadlessCliConfigException('providers[$i] must be an object');
    }
    final provider = _parseProvider(item, index: i);
    if (!providerIds.add(provider.id)) {
      throw HeadlessCliConfigException('duplicate provider id: ${provider.id}');
    }
    providers.add(provider);
  }

  final judge = _parseJudge(json['judge']);
  if (judge != null && !providerIds.contains(judge.providerId)) {
    throw HeadlessCliConfigException(
      'judge providerId does not match a configured provider: '
      '${judge.providerId}',
    );
  }

  final workdirRoot = _resolvePath(
    _requiredString(json, 'workdirRoot'),
    configDir,
  );
  final outputDir = _resolvePath(_requiredString(json, 'outputDir'), configDir);
  final databasePath = _resolvePath(
    _requiredString(json, 'databasePath'),
    configDir,
  );
  _validateOutputDir(workdirRoot: workdirRoot, outputDir: outputDir);

  return HeadlessCliConfig(
    configPath: configPath,
    runId: runId,
    name: _optionalString(json, 'name'),
    tasks: List.unmodifiable(tasks),
    providers: List.unmodifiable(providers),
    judge: judge,
    taskBundleRoots: List.unmodifiable(
      _optionalStringList(
        json,
        'taskBundleRoots',
      ).map((path) => _resolvePath(path, configDir)),
    ),
    evaluatorWeights: Map.unmodifiable(_parseEvaluatorWeights(json)),
    maxConcurrency: _positiveInt(json, 'maxConcurrency', defaultValue: 4),
    trialsPerTask: _positiveInt(json, 'trialsPerTask', defaultValue: 1),
    useReferencePlan: _optionalBool(
      json,
      'useReferencePlan',
      defaultValue: false,
    ),
    requireGeneratedCodeSandbox: _optionalBool(
      json,
      'requireGeneratedCodeSandbox',
      defaultValue: false,
    ),
    workdirRoot: workdirRoot,
    outputDir: outputDir,
    databasePath: databasePath,
    timeout: Duration(
      seconds: _positiveInt(json, 'timeoutSeconds', defaultValue: 600),
    ),
  );
}

String safeModelPathSegment(String modelId) {
  return safePathSegment(modelId, prefix: 'model');
}

HeadlessCliProviderConfig _parseProvider(
  Map<String, Object?> json, {
  required int index,
}) {
  final type = _requiredString(json, 'type', path: 'providers[$index].type');
  final models = _requiredStringList(
    json,
    'models',
    path: 'providers[$index].models',
  );
  if (models.isEmpty) {
    throw HeadlessCliConfigException(
      'providers[$index].models must not be empty',
    );
  }

  final id = switch (type) {
    'openai' => 'openai',
    'openrouter' => 'openrouter',
    'deepseek' => 'deepseek',
    'anthropic' => 'anthropic',
    'opencode_go' => 'opencode_go',
    'ollama_local' => 'ollama_local',
    'ollama_cloud' => 'ollama_cloud',
    'droid' => 'droid',
    'agent_cli' => _requiredString(json, 'id', path: 'providers[$index].id'),
    'openai_compatible' => _requiredString(
      json,
      'id',
      path: 'providers[$index].id',
    ),
    _ => throw HeadlessCliConfigException('unsupported provider type: $type'),
  };
  _validateSafeSegment(id, 'providers[$index].id');

  final displayName = type == 'openai_compatible' || type == 'agent_cli'
      ? _requiredString(
          json,
          'displayName',
          path: 'providers[$index].displayName',
        )
      : _defaultDisplayName(type);
  final baseUrl = type == 'openai_compatible'
      ? _requiredString(json, 'baseUrl', path: 'providers[$index].baseUrl')
      : _optionalString(json, 'baseUrl', path: 'providers[$index].baseUrl');
  final apiKeyEnv = _optionalString(
    json,
    'apiKeyEnv',
    path: 'providers[$index].apiKeyEnv',
  );
  final agentVersion = _optionalString(
    json,
    'agentVersion',
    path: 'providers[$index].agentVersion',
  );
  final harnessValue = json['harness'];
  String? harness;
  CommandTemplateAgentConfig? commandTemplate;
  if (harnessValue is Map<String, Object?>) {
    harness = 'command-template';
    commandTemplate = _parseCommandTemplate(
      harnessValue,
      path: 'providers[$index].harness',
    );
  } else {
    harness = _optionalString(
      json,
      'harness',
      path: 'providers[$index].harness',
    );
    if (harness == 'command-template') {
      final templateJson = json['commandTemplate'];
      if (templateJson is! Map<String, Object?>) {
        throw HeadlessCliConfigException(
          'providers[$index].commandTemplate must be an object',
        );
      }
      commandTemplate = _parseCommandTemplate(
        templateJson,
        path: 'providers[$index].commandTemplate',
      );
    } else if (harness != null &&
        harness != 'droid' &&
        harness != 'minimal' &&
        !CommandTemplateAgentConfig.presets.containsKey(harness)) {
      throw HeadlessCliConfigException(
        'providers[$index].harness must be "minimal", "droid", a command-template preset, or a command template object',
      );
    }
  }
  if (harness == 'droid' && type != 'droid') {
    throw HeadlessCliConfigException(
      'providers[$index].harness "droid" requires provider type "droid"',
    );
  }
  if (type == 'droid' &&
      (harness == 'command-template' ||
          CommandTemplateAgentConfig.presets.containsKey(harness))) {
    throw HeadlessCliConfigException(
      'providers[$index].harness command-template agents cannot use provider type "droid"',
    );
  }
  if (type == 'agent_cli' &&
      (harness == null || harness == 'minimal' || harness == 'droid')) {
    throw HeadlessCliConfigException(
      'providers[$index] type "agent_cli" requires a command-template harness',
    );
  }
  if (CommandTemplateAgentConfig.presets.containsKey(harness) &&
      (agentVersion == null || agentVersion.isEmpty)) {
    throw HeadlessCliConfigException(
      'providers[$index].agentVersion is required for command-template presets',
    );
  }

  if (_requiresApiKeyEnv(type) && (apiKeyEnv == null || apiKeyEnv.isEmpty)) {
    throw HeadlessCliConfigException(
      'providers[$index].apiKeyEnv is required for $type',
    );
  }

  return HeadlessCliProviderConfig(
    type: type,
    id: id,
    displayName: displayName,
    models: List.unmodifiable(models),
    apiKeyEnv: apiKeyEnv,
    baseUrl: baseUrl,
    harness: harness,
    commandTemplate: commandTemplate,
    agentVersion: agentVersion,
    defaultEfforts: List.unmodifiable(
      _optionalStringList(
        json,
        'defaultEfforts',
        path: 'providers[$index].defaultEfforts',
      ),
    ),
    extraHeaders: Map.unmodifiable(
      _optionalStringMap(
        json,
        'extraHeaders',
        path: 'providers[$index].extraHeaders',
      ),
    ),
  );
}

CommandTemplateAgentConfig _parseCommandTemplate(
  Map<String, Object?> json, {
  required String path,
}) {
  final name = _requiredString(json, 'name', path: '$path.name');
  final executable = _requiredString(
    json,
    'executable',
    path: '$path.executable',
  );
  final arguments = _requiredStringList(
    json,
    'arguments',
    path: '$path.arguments',
  );
  final version = _requiredString(json, 'version', path: '$path.version');
  try {
    return CommandTemplateAgentConfig(
      name: name,
      executable: executable,
      arguments: List.unmodifiable(arguments),
      version: version,
    );
  } on ArgumentError catch (error) {
    throw HeadlessCliConfigException('$path is invalid: $error');
  }
}

HeadlessCliJudgeConfig? _parseJudge(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    throw const HeadlessCliConfigException('judge must be an object');
  }
  final providerId = _requiredString(
    value,
    'providerId',
    path: 'judge.providerId',
  );
  _validateSafeSegment(providerId, 'judge.providerId');
  final model = _requiredString(value, 'model', path: 'judge.model');
  if (model.trim().isEmpty) {
    throw const HeadlessCliConfigException('judge.model must not be empty');
  }
  return HeadlessCliJudgeConfig(providerId: providerId, model: model);
}

Map<String, double> _parseEvaluatorWeights(Map<String, Object?> json) {
  final value = json['evaluatorWeights'];
  if (value == null) return defaultEvaluatorWeights;
  if (value is! Map<String, Object?>) {
    throw const HeadlessCliConfigException(
      'evaluatorWeights must be an object',
    );
  }
  final out = Map<String, double>.of(defaultEvaluatorWeights);
  for (final entry in value.entries) {
    final raw = entry.value;
    if (raw is! num) {
      throw HeadlessCliConfigException(
        'evaluatorWeights.${entry.key} must be a number',
      );
    }
    final weight = raw.toDouble();
    if (!weight.isFinite || weight < 0) {
      throw HeadlessCliConfigException(
        'evaluatorWeights.${entry.key} must be finite and non-negative',
      );
    }
    out[entry.key] = weight;
  }
  return out;
}

String _requiredString(Map<String, Object?> json, String key, {String? path}) {
  final value = json[key];
  final label = path ?? key;
  if (value is! String) {
    throw HeadlessCliConfigException('$label must be a string');
  }
  if (value.trim().isEmpty) {
    throw HeadlessCliConfigException('$label must not be empty');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key, {String? path}) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw HeadlessCliConfigException('${path ?? key} must be a string');
  }
  return value;
}

List<Object?> _requiredList(
  Map<String, Object?> json,
  String key, {
  String? path,
}) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw HeadlessCliConfigException('${path ?? key} must be a list');
  }
  return value;
}

List<String> _requiredStringList(
  Map<String, Object?> json,
  String key, {
  String? path,
}) {
  return _stringList(_requiredList(json, key, path: path), path ?? key);
}

List<String> _optionalStringList(
  Map<String, Object?> json,
  String key, {
  String? path,
}) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List<Object?>) {
    throw HeadlessCliConfigException('${path ?? key} must be a list');
  }
  return _stringList(value, path ?? key);
}

List<String> _stringList(List<Object?> values, String path) {
  final out = <String>[];
  for (var i = 0; i < values.length; i++) {
    final value = values[i];
    if (value is! String) {
      throw HeadlessCliConfigException('$path[$i] must be a string');
    }
    if (value.trim().isEmpty) {
      throw HeadlessCliConfigException('$path[$i] must not be empty');
    }
    out.add(value);
  }
  return out;
}

Map<String, String> _optionalStringMap(
  Map<String, Object?> json,
  String key, {
  String? path,
}) {
  final value = json[key];
  if (value == null) return const {};
  if (value is! Map<String, Object?>) {
    throw HeadlessCliConfigException('${path ?? key} must be an object');
  }
  final out = <String, String>{};
  for (final entry in value.entries) {
    if (entry.value is! String) {
      throw HeadlessCliConfigException(
        '${path ?? key}.${entry.key} must be a string',
      );
    }
    out[entry.key] = entry.value as String;
  }
  return out;
}

int _positiveInt(
  Map<String, Object?> json,
  String key, {
  required int defaultValue,
}) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is! int) {
    throw HeadlessCliConfigException('$key must be an integer');
  }
  if (value <= 0) {
    throw HeadlessCliConfigException('$key must be a positive integer');
  }
  return value;
}

bool _optionalBool(
  Map<String, Object?> json,
  String key, {
  required bool defaultValue,
}) {
  final value = json[key];
  if (value == null) return defaultValue;
  if (value is! bool) {
    throw HeadlessCliConfigException('$key must be a boolean');
  }
  return value;
}

String _resolvePath(String value, String configDir) {
  final path = p.isAbsolute(value) ? value : p.join(configDir, value);
  return p.normalize(p.absolute(path));
}

void _validateOutputDir({
  required String workdirRoot,
  required String outputDir,
}) {
  final runsRoot = p.normalize(p.join(workdirRoot, 'runs'));
  if (p.equals(outputDir, runsRoot) || p.isWithin(runsRoot, outputDir)) {
    throw const HeadlessCliConfigException(
      'outputDir must not be inside workdirRoot/runs',
    );
  }
}

void _validateSafeSegment(String value, String label) {
  final valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$').hasMatch(value);
  if (!valid ||
      value.contains('..') ||
      value.contains('/') ||
      value.contains('\\') ||
      p.isAbsolute(value)) {
    throw HeadlessCliConfigException('$label must be a safe path segment');
  }
}

bool _requiresApiKeyEnv(String type) {
  return const {
    'openai',
    'openrouter',
    'deepseek',
    'anthropic',
    'opencode_go',
    'ollama_cloud',
  }.contains(type);
}

String _defaultDisplayName(String type) {
  return switch (type) {
    'openai' => 'OpenAI',
    'openrouter' => 'OpenRouter',
    'deepseek' => 'DeepSeek',
    'anthropic' => 'Anthropic',
    'opencode_go' => 'OpenCode Go',
    'ollama_local' => 'Ollama Local',
    'ollama_cloud' => 'Ollama Cloud',
    'droid' => 'Factory Droid',
    _ => type,
  };
}
