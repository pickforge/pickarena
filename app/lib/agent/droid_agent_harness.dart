import 'dart:async';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/providers/factory_custom_model_environment.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';
import 'package:path/path.dart' as p;

typedef DroidAgentProcessRunner =
    Future<AgentRunResult> Function(
      String executable,
      List<String> arguments,
      Directory workspace,
      Duration timeout,
    );

class DroidAgentHarness implements AgentHarness, AgentHarnessProvenance {
  DroidAgentHarness({
    DroidAgentProcessRunner? runner,
    String? droidPath,
    Iterable<String> deniedEnvironmentKeys = const [],
    GeneratedCodeSandbox? generatedCodeSandbox,
    int maxPreviewChars = 16 * 1024,
    int maxProcessOutputChars = 1024 * 1024,
  }) : _runner = runner,
       _exe = droidPath ?? _findDroid(),
       _deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys),
       _generatedCodeSandbox = generatedCodeSandbox,
       _maxPreviewChars = maxPreviewChars,
       _maxProcessOutputChars = maxProcessOutputChars,
       assert(maxPreviewChars > 0),
       assert(maxProcessOutputChars > 0);

  final DroidAgentProcessRunner? _runner;
  final String _exe;
  final Set<String> _deniedEnvironmentKeys;
  final GeneratedCodeSandbox? _generatedCodeSandbox;
  final int _maxPreviewChars;
  final int _maxProcessOutputChars;
  static const int _maxDirectWorkingDirectoryPathChars = 160;

  @override
  String get id => 'droid';

  @override
  Map<String, Object?> get provenance => const {
    'kind': 'droid',
    'track': 'scaffold-dependent',
    'agent': 'droid',
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
    final args = [
      'exec',
      '--auto',
      'high',
      '--output-format',
      'text',
      '--model',
      modelId,
      _agentInstruction(instruction),
    ];
    final deniedKeys = {..._deniedEnvironmentKeys, ...deniedEnvironmentKeys};
    final result = _runner == null
        ? await runExternalProcess(
            _exe,
            args,
            workspace,
            timeout,
            deniedKeys,
            factoryCustomModelEnvironmentReferences(modelId),
            _maxProcessOutputChars,
            allowInternet,
            _generatedCodeSandbox,
            extraReadOnlyPaths: _factoryConfigReadOnlyPaths(),
          )
        : await _runner(_exe, args, workspace, timeout);
    return _boundedResult(result);
  }

  AgentRunResult _boundedResult(AgentRunResult result) {
    return AgentRunResult(
      status: result.status,
      stdoutPreview: _trimPreview(result.stdoutPreview, _maxPreviewChars),
      stderrPreview: _trimPreview(result.stderrPreview, _maxPreviewChars),
      exitCode: result.exitCode,
      latency: result.latency,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      trajectoryLogPath: result.trajectoryLogPath,
      metadata: result.metadata,
    );
  }

  static String _agentInstruction(String instruction) {
    return '''
You are running inside an isolated benchmark workspace.
Use only the files available in this workspace and do not rely on external hidden tests, reference solutions, or assumptions.
Inspect, edit, and run commands as needed, then stop once the requested change is complete.

Task:
$instruction
''';
  }

  static String _findDroid() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    final candidates = [
      '$home/.local/bin/droid',
      '$home/.npm-global/bin/droid',
      '/usr/local/bin/droid',
      'droid',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return 'droid';
  }

  static const _factoryConfigFileNames = [
    'settings.json',
    'auth.v2.file',
    'auth.v2.key',
  ];

  static List<String> _factoryConfigReadOnlyPaths() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return const [];
    return [
      for (final name in _factoryConfigFileNames)
        if (File(p.join(home, '.factory', name)).existsSync())
          p.join(home, '.factory', name),
    ];
  }

  static Future<AgentRunResult> runExternalProcess(
    String exe,
    List<String> args,
    Directory workspace,
    Duration timeout,
    Iterable<String> deniedEnvironmentKeys,
    Iterable<String> allowedSensitiveEnvironmentKeys,
    int maxProcessOutputChars,
    bool allowInternet,
    GeneratedCodeSandbox? generatedCodeSandbox, {
    Iterable<String> extraReadOnlyPaths = const [],
    List<String> Function(Directory workingDirectory)?
    argumentsForWorkingDirectory,
  }) async {
    final sw = Stopwatch()..start();
    final cwdProxy = await _createWorkingDirectoryProxy(workspace);
    final workingDirectory = cwdProxy?.directory ?? workspace;
    final effectiveArguments =
        argumentsForWorkingDirectory?.call(workingDirectory) ?? args;
    final environment = benchmarkSubprocessEnvironment(
      additionalDeniedKeys: deniedEnvironmentKeys,
      allowedSensitiveKeys: allowedSensitiveEnvironmentKeys,
    );
    if (!Platform.isWindows) {
      environment['PWD'] = workingDirectory.path;
    }
    late final Process process;
    try {
      final processStart = generatedCodeSandbox == null
          ? SandboxedProcessStart(
              executable: exe,
              arguments: effectiveArguments,
              workingDirectory: workingDirectory.path,
              environment: environment,
            )
          : await generatedCodeSandbox.wrapProcess(
              executable: exe,
              arguments: effectiveArguments,
              workingDirectory: workingDirectory.path,
              environment: environment,
              allowInternet: allowInternet,
              resourceLimits: null,
              extraReadOnlyPaths: extraReadOnlyPaths,
            );
      process = await Process.start(
        processStart.executable,
        processStart.arguments,
        workingDirectory: processStart.workingDirectory,
        runInShell: false,
        environment: processStart.environment,
        includeParentEnvironment: false,
      );
    } on Object {
      await cwdProxy?.dispose();
      rethrow;
    }
    try {
      final stdoutBuffer = _BoundedTailTextCollector(maxProcessOutputChars);
      final stderrBuffer = _BoundedTailTextCollector(maxProcessOutputChars);
      final outputLimitExceeded = Completer<void>();
      void markOutputLimitExceeded() {
        if (!outputLimitExceeded.isCompleted) {
          outputLimitExceeded.complete();
        }
      }

      final stdoutDone = process.stdout
          .transform(systemEncoding.decoder)
          .listen((chunk) {
            stdoutBuffer.write(chunk);
            if (stdoutBuffer.exceeded) markOutputLimitExceeded();
          })
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(systemEncoding.decoder)
          .listen((chunk) {
            stderrBuffer.write(chunk);
            if (stderrBuffer.exceeded) markOutputLimitExceeded();
          })
          .asFuture<void>();

      var timedOut = false;
      var outputLimitHit = false;
      int exitCode;
      final timeoutExceeded = Completer<void>();
      final timeoutTimer = Timer(timeout, () {
        if (!timeoutExceeded.isCompleted) timeoutExceeded.complete();
      });
      try {
        final signal = await Future.any<Object>([
          process.exitCode,
          timeoutExceeded.future.then(
            (_) => const _AgentProcessTimeoutExceeded(),
          ),
          outputLimitExceeded.future.then(
            (_) => const _AgentProcessOutputLimitExceeded(),
          ),
        ]);
        if (signal is int) {
          exitCode = signal;
        } else {
          timedOut = signal is _AgentProcessTimeoutExceeded;
          outputLimitHit = signal is _AgentProcessOutputLimitExceeded;
          await terminateProcessTree(process.pid, ProcessSignal.sigterm);
          exitCode = await process.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () async {
              await terminateProcessTree(process.pid, ProcessSignal.sigkill);
              return -1;
            },
          );
        }
      } finally {
        timeoutTimer.cancel();
      }
      await Future.wait([stdoutDone, stderrDone]);
      await cwdProxy?.syncBack();
      sw.stop();
      final stdoutPreview = _trimPreview(stdoutBuffer.text, 16 * 1024);
      final rawStderrPreview = _trimPreview(stderrBuffer.text, 16 * 1024);
      final stderrPreview = outputLimitHit && rawStderrPreview.isEmpty
          ? 'agent harness output exceeded $maxProcessOutputChars characters'
          : rawStderrPreview;

      return AgentRunResult(
        status: timedOut
            ? AgentRunStatus.timeout
            : exitCode == 0 && !outputLimitHit
            ? AgentRunStatus.success
            : AgentRunStatus.failure,
        stdoutPreview: stdoutPreview,
        stderrPreview: stderrPreview,
        exitCode: timedOut && exitCode == -1 ? null : exitCode,
        latency: sw.elapsed,
        metadata: {
          'executable': exe,
          'argc': effectiveArguments.length,
          'workspace': workspace.path,
          if (cwdProxy != null) 'cwd_proxy_used': true,
          if (generatedCodeSandbox != null)
            'runtimeBoundary': {
              'enforced': true,
              'backend': generatedCodeSandbox.backend,
            },
          if (outputLimitHit) 'output_limit_exceeded': true,
          if (outputLimitHit) 'max_output_chars': maxProcessOutputChars,
        },
      );
    } finally {
      await cwdProxy?.dispose();
    }
  }

  static Future<_WorkingDirectoryProxy?> _createWorkingDirectoryProxy(
    Directory workspace,
  ) async {
    if (Platform.isWindows ||
        workspace.path.length <= _maxDirectWorkingDirectoryPathChars) {
      return null;
    }
    final root = await Directory.systemTemp.createTemp(
      'dart_arena_droid_workspace_',
    );
    try {
      final directory = Directory(p.join(root.path, 'workspace'));
      await directory.create();
      await _copyDirectoryContents(workspace, directory);
      return _WorkingDirectoryProxy(
        root: root,
        directory: directory,
        original: workspace,
      );
    } on Object {
      if (await root.exists()) await root.delete(recursive: true);
      return null;
    }
  }

  static Future<void> _replaceDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    await target.create(recursive: true);
    await for (final entity in target.list(followLinks: false)) {
      await entity.delete(recursive: true);
    }
    await _copyDirectoryContents(source, target);
  }

  static Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    await target.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final destination = p.join(target.path, p.basename(entity.path));
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await _copyDirectoryContents(
          Directory(entity.path),
          Directory(destination),
        );
      } else if (type == FileSystemEntityType.file) {
        await File(entity.path).copy(destination);
      } else if (type == FileSystemEntityType.link) {
        await Link(destination).create(await Link(entity.path).target());
      }
    }
  }

  static String _trimPreview(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return value.substring(value.length - maxChars);
  }

  static Future<void> terminateProcessTree(
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

class _WorkingDirectoryProxy {
  const _WorkingDirectoryProxy({
    required this.root,
    required this.directory,
    required this.original,
  });

  final Directory root;
  final Directory directory;
  final Directory original;

  Future<void> syncBack() {
    return DroidAgentHarness._replaceDirectoryContents(directory, original);
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}

class _AgentProcessTimeoutExceeded {
  const _AgentProcessTimeoutExceeded();
}

class _AgentProcessOutputLimitExceeded {
  const _AgentProcessOutputLimitExceeded();
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
