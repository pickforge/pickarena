import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

const _workerCleanupGrace = Duration(seconds: 3);

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.writeln(jsonEncode(_helpJson()));
    return;
  }

  final timeout = _configuredTimeout(args);
  final resultPort = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();

  Isolate? worker;
  try {
    worker = await Isolate.spawnUri(
      Uri.parse('package:dart_arena/headless/headless_cli_worker.dart'),
      args,
      resultPort.sendPort,
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
      errorsAreFatal: true,
    );

    final resultFuture = resultPort.first.then(_decodeWorkerResult);
    final errorFuture = errorPort.first.then(_WorkerError.new);
    final exitFuture = exitPort.first.then((_) => const _WorkerExit());
    final futures = <Future<_WorkerSignal>>[
      resultFuture,
      errorFuture,
      exitFuture,
      if (timeout != null) _parentTimeoutFuture(timeout),
    ];

    var signal = await Future.any(futures);
    if (signal is _WorkerExit) {
      signal = await Future.any<_WorkerSignal>([
        resultFuture,
        errorFuture,
        Future<void>.delayed(
          const Duration(milliseconds: 50),
        ).then<_WorkerSignal>((_) => signal),
      ]);
    }

    worker.kill(priority: Isolate.immediate);
    _handleWorkerSignal(signal);
  } on Object catch (error) {
    _writeFailureJson(error.toString());
    exitCode = 1;
  } finally {
    worker?.kill(priority: Isolate.immediate);
    resultPort.close();
    errorPort.close();
    exitPort.close();
  }
}

Future<_WorkerSignal> _parentTimeoutFuture(Duration configuredTimeout) {
  return Future<void>.delayed(configuredTimeout + _workerCleanupGrace).then(
    (_) => _WorkerTimeout(
      configuredTimeout: configuredTimeout,
      cleanupGrace: _workerCleanupGrace,
    ),
  );
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

Duration? _configuredTimeout(List<String> args) {
  final configPath = _configPath(args);
  if (configPath == null) return null;
  try {
    final decoded = jsonDecode(File(configPath).readAsStringSync());
    if (decoded is! Map<String, Object?>) return null;
    final seconds = decoded['timeoutSeconds'];
    if (seconds is int && seconds > 0) {
      return Duration(seconds: seconds);
    }
  } on Object {
    return null;
  }
  return null;
}

String? _configPath(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--config' && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}

_WorkerSignal _decodeWorkerResult(Object? message) {
  if (message is Map<Object?, Object?>) {
    final workerExitCode = message['exitCode'];
    if (workerExitCode is int) {
      return _WorkerResult(
        workerExitCode: workerExitCode,
        stdoutLines: _stringLines(message['stdout']),
        stderrLines: _stringLines(message['stderr']),
      );
    }
  }
  return _WorkerError('invalid worker result: $message');
}

List<String> _stringLines(Object? value) {
  if (value is! List) return const [];
  return [for (final line in value) line.toString()];
}

void _handleWorkerSignal(_WorkerSignal signal) {
  if (signal is _WorkerResult) {
    for (final line in signal.stdoutLines) {
      stdout.writeln(line);
    }
    for (final line in signal.stderrLines) {
      stderr.writeln(line);
    }
    exitCode = signal.workerExitCode;
  } else if (signal is _WorkerError) {
    _writeFailureJson(_workerErrorMessage(signal.error));
    exitCode = 1;
  } else if (signal is _WorkerTimeout) {
    _writeFailureJson(
      'headless CLI hard timeout expired after '
      '${signal.configuredTimeout.inSeconds} seconds plus '
      '${signal.cleanupGrace.inSeconds} seconds cleanup grace',
    );
    exitCode = 1;
  } else {
    _writeFailureJson('headless CLI worker exited before returning a result');
    exitCode = 1;
  }
}

String _workerErrorMessage(Object? error) {
  if (error is List && error.isNotEmpty) return error.first.toString();
  return error.toString();
}

void _writeFailureJson(String error) {
  stderr.writeln(jsonEncode({'status': 'failed', 'error': error}));
}

sealed class _WorkerSignal {
  const _WorkerSignal();
}

class _WorkerResult extends _WorkerSignal {
  const _WorkerResult({
    required this.workerExitCode,
    required this.stdoutLines,
    required this.stderrLines,
  });

  final int workerExitCode;
  final List<String> stdoutLines;
  final List<String> stderrLines;
}

class _WorkerError extends _WorkerSignal {
  const _WorkerError(this.error);

  final Object? error;
}

class _WorkerExit extends _WorkerSignal {
  const _WorkerExit();
}

class _WorkerTimeout extends _WorkerSignal {
  const _WorkerTimeout({
    required this.configuredTimeout,
    required this.cleanupGrace,
  });

  final Duration configuredTimeout;
  final Duration cleanupGrace;
}
