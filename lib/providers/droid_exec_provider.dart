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

typedef DroidProcessRunner = Future<DroidProcessResult> Function(
  String executable,
  List<String> arguments,
);

class DroidExecProvider implements ModelProvider {
  DroidExecProvider({DroidProcessRunner? runner})
      : _runner = runner ?? _defaultRunner;

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

  @override
  String get id => 'droid';
  @override
  String get displayName => 'Factory Droid';
  @override
  ProviderMode get mode => ProviderMode.agent;

  @override
  Future<List<String>> listModels() async => const [
        'gpt-5.5',
        'gpt-5.4',
        'gpt-5.3-codex',
        'claude-sonnet-4-6',
        'claude-opus-4-7',
        'gemini-3-flash',
      ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final sw = Stopwatch()..start();
    final res = await _runner(
      'droid',
      [
        'exec',
        '--auto',
        'low',
        '--output-format',
        'text',
        '--model',
        model,
        prompt,
      ],
    );
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
