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
    final res = await Process.run(exe, args);
    return DroidProcessResult(
      stdout: res.stdout.toString(),
      stderr: res.stderr.toString(),
      exitCode: res.exitCode,
    );
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
  Future<List<ModelInfo>> listModels() async => const [
    ModelInfo(id: 'gpt-5.5'),
    ModelInfo(id: 'gpt-5.4'),
    ModelInfo(id: 'gpt-5.3-codex'),
    ModelInfo(id: 'claude-sonnet-4-6'),
    ModelInfo(id: 'claude-opus-4-7'),
    ModelInfo(id: 'gemini-3-flash'),
  ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    final res = await _runner(_exe, [
      'exec',
      '--auto',
      'high',
      '--output-format',
      'text',
      '--model',
      model,
      prompt,
    ]);
    sw.stop();
    if (res.exitCode != 0) {
      throw Exception('droid exec failed: ${res.stderr}');
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
