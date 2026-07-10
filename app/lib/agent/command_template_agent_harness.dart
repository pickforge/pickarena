import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';

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
      arguments: ['exec', '--model', '{model}', '{instruction}'],
      version: 'preset',
    ),
    'claude-code': CommandTemplateAgentConfig(
      name: 'claude-code',
      executable: 'claude',
      arguments: ['-p', '--model', '{model}', '{instruction}'],
      version: 'preset',
    ),
    'opencode': CommandTemplateAgentConfig(
      name: 'opencode',
      executable: 'opencode',
      arguments: ['run', '--model', '{model}', '{instruction}'],
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
    this.maxPreviewChars = 16 * 1024,
    this.maxProcessOutputChars = 1024 * 1024,
  }) : _deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys),
       assert(maxPreviewChars > 0),
       assert(maxProcessOutputChars > 0) {
    _validateTemplate(config.arguments);
  }

  final String providerId;
  final CommandTemplateAgentConfig config;
  final GeneratedCodeSandbox? generatedCodeSandbox;
  final Set<String> _deniedEnvironmentKeys;
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
    final values = {
      'instruction': instruction,
      'model': modelId,
      'workspace': workspace.path,
      'timeout': timeout.inSeconds.toString(),
    };
    final result = await DroidAgentHarness.runExternalProcess(
      config.executable,
      [for (final argument in config.arguments) _substitute(argument, values)],
      workspace,
      timeout,
      {..._deniedEnvironmentKeys, ...deniedEnvironmentKeys},
      const [],
      maxProcessOutputChars,
      allowInternet,
      generatedCodeSandbox,
      extraReadOnlyPaths: _presetConfigPaths(config.name),
    );
    return AgentRunResult(
      status: result.status,
      stdoutPreview: _trim(result.stdoutPreview),
      stderrPreview: _trim(result.stderrPreview),
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
      for (final match in RegExp(r'\{([a-z]+)\}').allMatches(argument)) {
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

  static Iterable<String> _presetConfigPaths(String name) {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return const [];
    final paths = switch (name) {
      'codex' => ['$home/.codex'],
      'claude-code' => ['$home/.claude'],
      'opencode' => ['$home/.config/opencode'],
      _ => const <String>[],
    };
    return [
      for (final path in paths)
        if (Directory(path).existsSync()) path,
    ];
  }
}
