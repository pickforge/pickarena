import 'dart:async';
import 'dart:io';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/factory_custom_model_environment.dart';
import 'package:dart_arena/providers/model_provider.dart';
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
    final process = await Process.start(
      exe,
      args,
      runInShell: false,
      environment: benchmarkSubprocessEnvironment(
        additionalDeniedKeys: deniedEnvironmentKeys,
        allowedSensitiveKeys: allowedSensitiveEnvironmentKeys,
      ),
      includeParentEnvironment: false,
    );
    final stdoutBuffer = _BoundedTailTextCollector(maxProcessOutputChars);
    final stderrBuffer = _BoundedTailTextCollector(maxProcessOutputChars);
    final outputLimitExceeded = Completer<void>();
    void markOutputLimitExceeded() {
      if (!outputLimitExceeded.isCompleted) {
        outputLimitExceeded.complete();
      }
    }

    final stdoutDone = process.stdout.transform(systemEncoding.decoder).listen((
      chunk,
    ) {
      stdoutBuffer.write(chunk);
      if (stdoutBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();
    final stderrDone = process.stderr.transform(systemEncoding.decoder).listen((
      chunk,
    ) {
      stderrBuffer.write(chunk);
      if (stderrBuffer.exceeded) markOutputLimitExceeded();
    }).asFuture<void>();

    var timedOut = false;
    var outputLimitHit = false;
    int exitCode;
    Timer? timeoutTimer;
    final timeoutExceeded = Completer<void>();
    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        if (!timeoutExceeded.isCompleted) timeoutExceeded.complete();
      });
    }
    try {
      final signal = await Future.any<Object>([
        process.exitCode,
        if (timeout != null)
          timeoutExceeded.future.then(
            (_) => const _DroidProcessTimeoutExceeded(),
          ),
        outputLimitExceeded.future.then(
          (_) => const _DroidProcessOutputLimitExceeded(),
        ),
      ]);
      if (signal is int) {
        exitCode = signal;
      } else {
        timedOut = signal is _DroidProcessTimeoutExceeded;
        outputLimitHit = signal is _DroidProcessOutputLimitExceeded;
        await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
        exitCode = await process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () async {
            await _terminateProcessTree(process.pid, ProcessSignal.sigkill);
            return -1;
          },
        );
      }
    } finally {
      timeoutTimer?.cancel();
    }
    await Future.wait([stdoutDone, stderrDone]);
    if (timedOut) {
      throw TimeoutException('droid exec timed out', timeout);
    }
    final stderr = stderrBuffer.text;
    final stderrWithLimit = outputLimitHit
        ? [
            'droid exec output exceeded $maxProcessOutputChars characters',
            if (stderr.isNotEmpty) stderr,
          ].join('\n')
        : stderr;
    return DroidProcessResult(
      stdout: stdoutBuffer.text,
      stderr: stderrWithLimit,
      exitCode: outputLimitHit && exitCode == 0 ? -1 : exitCode,
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

  static Future<void> _terminateProcessTree(
    int pid,
    ProcessSignal signal,
  ) async {
    if (Platform.isWindows) {
      final args = ['/PID', '$pid', '/T'];
      if (signal == ProcessSignal.sigkill) args.add('/F');
      await _tryRunProcess('taskkill', args);
      return;
    }

    final descendants = await _descendantPids(pid);
    for (final childPid in descendants.reversed) {
      _killPid(childPid, signal);
    }
    _killPid(pid, signal);
  }

  static Future<List<int>> _descendantPids(int pid) async {
    final descendants = <int>[];
    for (final childPid in await _childPids(pid)) {
      descendants.add(childPid);
      descendants.addAll(await _descendantPids(childPid));
    }
    return descendants;
  }

  static Future<List<int>> _childPids(int pid) async {
    final pgrep = await _tryRunProcess('pgrep', ['-P', '$pid']);
    if (pgrep?.exitCode == 0) {
      return _parsePids(pgrep!.stdout.toString());
    }

    final ps = await _tryRunProcess('ps', ['-o', 'pid=', '--ppid', '$pid']);
    if (ps?.exitCode == 0) {
      return _parsePids(ps!.stdout.toString());
    }
    return const [];
  }

  static Future<ProcessResult?> _tryRunProcess(
    String executable,
    List<String> arguments,
  ) async {
    try {
      return await Process.run(
        executable,
        arguments,
        runInShell: false,
        environment: benchmarkSubprocessEnvironment(),
        includeParentEnvironment: false,
      );
    } on Object {
      return null;
    }
  }

  static List<int> _parsePids(String output) => output
      .split(RegExp(r'\s+'))
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .toList(growable: false);

  static void _killPid(int pid, ProcessSignal signal) {
    if (!_tryKillPid(pid, signal)) {
      _tryKillPid(pid, null);
    }
  }

  static bool _tryKillPid(int pid, ProcessSignal? signal) {
    try {
      return signal == null
          ? Process.killPid(pid)
          : Process.killPid(pid, signal);
    } on Object {
      return false;
    }
  }
}

class _DroidProcessTimeoutExceeded {
  const _DroidProcessTimeoutExceeded();
}

class _DroidProcessOutputLimitExceeded {
  const _DroidProcessOutputLimitExceeded();
}

class _BoundedTailTextCollector {
  _BoundedTailTextCollector(this.maxChars);

  final int maxChars;
  final _buffer = StringBuffer();
  var exceeded = false;

  void write(String chunk) {
    if (chunk.isEmpty) return;
    _buffer.write(chunk);
    if (_buffer.length > maxChars) {
      exceeded = true;
      final value = _buffer.toString();
      _buffer
        ..clear()
        ..write(value.substring(value.length - maxChars));
    }
  }

  String get text => _buffer.toString();
}
