import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:path/path.dart' as p;

class CommandTemplateAgentConfig {
  const CommandTemplateAgentConfig({
    required this.name,
    required this.executable,
    required this.arguments,
    required this.version,
  });

  final String name;
  final String executable;
  final List<String> arguments;
  final String version;

  static const presets = <String, CommandTemplateAgentConfig>{
    'codex': CommandTemplateAgentConfig(
      name: 'codex',
      executable: 'codex',
      arguments: [
        'exec',
        '--sandbox',
        'workspace-write',
        '--model',
        '{model}',
        '{instruction}',
      ],
      version: 'preset',
    ),
    'claude-code': CommandTemplateAgentConfig(
      name: 'claude-code',
      executable: 'claude',
      arguments: [
        '-p',
        '--permission-mode',
        'bypassPermissions',
        '--model',
        '{model}',
        '{instruction}',
      ],
      version: 'preset',
    ),
    'opencode': CommandTemplateAgentConfig(
      name: 'opencode',
      executable: 'opencode',
      arguments: ['run', '--auto', '--model', '{model}', '{instruction}'],
      version: 'preset',
    ),
  };

  static CommandTemplateAgentConfig preset(
    String name, {
    required String version,
  }) {
    final preset = presets[name];
    if (preset == null) {
      throw ArgumentError.value(
        name,
        'name',
        'unknown command-template preset',
      );
    }
    return CommandTemplateAgentConfig(
      name: preset.name,
      executable: preset.executable,
      arguments: preset.arguments,
      version: version,
    );
  }
}

class CommandTemplateAgentHarness
    implements AgentHarness, AgentHarnessProvenance {
  CommandTemplateAgentHarness({
    required this.providerId,
    required this.config,
    this.generatedCodeSandbox,
    Iterable<String> deniedEnvironmentKeys = const [],
    Iterable<String> allowedSensitiveEnvironmentKeys = const [],
    this.maxPreviewChars = 16 * 1024,
    this.maxProcessOutputChars = 1024 * 1024,
  }) : _deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys),
       _allowedSensitiveEnvironmentKeys = Set.unmodifiable(
         allowedSensitiveEnvironmentKeys,
       ),
       assert(maxPreviewChars > 0),
       assert(maxProcessOutputChars > 0) {
    _validateTemplate(config.arguments);
  }

  final String providerId;
  final CommandTemplateAgentConfig config;
  final GeneratedCodeSandbox? generatedCodeSandbox;
  final Set<String> _deniedEnvironmentKeys;
  final Set<String> _allowedSensitiveEnvironmentKeys;
  final int maxPreviewChars;
  final int maxProcessOutputChars;

  @override
  String get id => providerId;

  @override
  Map<String, Object?> get provenance => {
    'kind': 'command-template',
    'track': 'scaffold-dependent',
    'agent': config.name,
    'agentVersion': config.version,
  };

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
  }) async {
    final allowedEnvironmentKeys = {
      ..._allowedSensitiveEnvironmentKeys,
      ..._presetEnvironmentKeys(config.name),
    };
    final result = await DroidAgentHarness.runExternalProcess(
      config.executable,
      const [],
      workspace,
      timeout,
      {
        ..._deniedEnvironmentKeys,
        ...deniedEnvironmentKeys,
      }.difference(allowedEnvironmentKeys),
      allowedEnvironmentKeys,
      maxProcessOutputChars,
      allowInternet,
      generatedCodeSandbox,
      extraReadOnlyPaths: _presetConfigPaths(config.name),
      argumentsForWorkingDirectory: (workingDirectory) {
        final values = {
          'instruction': instruction,
          'model': modelId,
          'workspace': workingDirectory.path,
          'timeout': timeout.inSeconds.toString(),
        };
        return [
          for (final argument in config.arguments)
            _substitute(argument, values),
        ];
      },
    );
    final sensitiveValues = {
      for (final key in _allowedSensitiveEnvironmentKeys)
        if ((Platform.environment[key] ?? '').isNotEmpty)
          key: Platform.environment[key]!,
    };
    return AgentRunResult(
      status: result.status,
      stdoutPreview: _trim(_redact(result.stdoutPreview, sensitiveValues)),
      stderrPreview: _trim(_redact(result.stderrPreview, sensitiveValues)),
      exitCode: result.exitCode,
      latency: result.latency,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      trajectoryLogPath: result.trajectoryLogPath,
      metadata: {...result.metadata, 'agentHarness': provenance},
    );
  }

  String _trim(String value) => value.length <= maxPreviewChars
      ? value
      : value.substring(value.length - maxPreviewChars);

  static String _redact(String value, Map<String, String> sensitiveValues) {
    var redacted = value;
    for (final entry in sensitiveValues.entries) {
      redacted = redacted.replaceAll(entry.value, '[REDACTED:${entry.key}]');
    }
    return redacted;
  }

  static String _substitute(String value, Map<String, String> values) {
    return value.replaceAllMapped(RegExp(r'\{([a-z]+)\}'), (match) {
      final replacement = values[match.group(1)];
      if (replacement == null) {
        throw ArgumentError(
          'unsupported command-template placeholder: ${match[0]}',
        );
      }
      return replacement;
    });
  }

  static void _validateTemplate(List<String> arguments) {
    var hasInstruction = false;
    for (final argument in arguments) {
      for (final match in RegExp(r'\{([^{}]+)\}').allMatches(argument)) {
        hasInstruction = hasInstruction || match.group(1) == 'instruction';
        if (!const {
          'instruction',
          'model',
          'workspace',
          'timeout',
        }.contains(match.group(1))) {
          throw ArgumentError(
            'unsupported command-template placeholder: ${match[0]}',
          );
        }
      }
    }
    if (!hasInstruction) {
      throw ArgumentError('command template must include {instruction}');
    }
  }

  static Iterable<String> _presetEnvironmentKeys(String name) => switch (name) {
    'codex' => const ['CODEX_HOME'],
    'claude-code' => const ['CLAUDE_CONFIG_DIR'],
    _ => const [],
  };

  static Iterable<String> _presetConfigPaths(String name) {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    String? environmentPath(String key, String fallback) {
      final configured = Platform.environment[key]?.trim();
      if (configured != null && configured.isNotEmpty) return configured;
      return home.isEmpty ? null : p.join(home, fallback);
    }

    final paths = switch (name) {
      'codex' => [environmentPath('CODEX_HOME', '.codex')],
      'claude-code' => [
        environmentPath('CLAUDE_CONFIG_DIR', '.claude'),
        if (home.isNotEmpty) p.join(home, '.claude.json'),
      ],
      'opencode' => [
        if (environmentPath('XDG_CONFIG_HOME', '.config') case final root?)
          p.join(root, 'opencode'),
        if (environmentPath('XDG_DATA_HOME', '.local/share') case final root?)
          p.join(root, 'opencode'),
      ],
      _ => const <String?>[],
    };
    return [
      for (final path in paths.whereType<String>())
        if (path.isNotEmpty &&
            FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound)
          path,
    ];
  }
}
