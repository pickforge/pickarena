import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';

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
    );

class DroidExecProvider implements ModelProvider {
  DroidExecProvider({DroidProcessRunner? runner, String? droidPath})
    : _runner = runner ?? _defaultRunner,
      _exe = droidPath ?? _findDroid();

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
  ) async {
    final res = await Process.run(
      exe,
      args,
      runInShell: false,
      includeParentEnvironment: true,
    );
    return DroidProcessResult(
      stdout: res.stdout.toString(),
      stderr: res.stderr.toString(),
      exitCode: res.exitCode,
    );
  }

  static String _formatArgsForShell(List<String> args) {
    return args
        .map((a) {
          if (a.isEmpty) return r"''";
          if (RegExp(r'^[A-Za-z0-9_\-./:=,@%+]+$').hasMatch(a)) return a;
          final escaped = a.replaceAll(r"'", r"'\''");
          return "'$escaped'";
        })
        .join(' ');
  }

  static Map<String, dynamic>? _readFactorySettings() {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) return null;
      final file = File('$home/.factory/settings.json');
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  final DroidProcessRunner _runner;
  final String _exe;

  @override
  String get id => 'droid';
  @override
  String get displayName => 'Factory Droid';
  @override
  ProviderMode get mode => ProviderMode.agent;

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
    final settings = _readFactorySettings();
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
      '--enabled-tools',
      '',
      '--output-format',
      'text',
      '--model',
      model,
      directPrompt,
    ];
    final res = await _runner(_exe, args);
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
        '  executable : $_exe\n'
        '  cwd        : ${Directory.current.path}\n'
        '  TMPDIR     : ${Platform.environment['TMPDIR'] ?? '<unset>'}\n'
        '  HOME       : ${Platform.environment['HOME'] ?? '<unset>'}\n'
        '  PATH       : ${Platform.environment['PATH'] ?? '<unset>'}\n'
        '  argc       : ${args.length}\n'
        '  promptLen  : ${directPrompt.length}\n'
        '  duration   : ${sw.elapsedMilliseconds}ms\n'
        '  shell cmd  : $_exe ${_formatArgsForShell(args)}\n'
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
