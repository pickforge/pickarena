import 'dart:async';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';

typedef DroidAgentProcessRunner =
    Future<AgentRunResult> Function(
      String executable,
      List<String> arguments,
      Directory workspace,
      Duration timeout,
    );

class DroidAgentHarness implements AgentHarness {
  DroidAgentHarness({
    DroidAgentProcessRunner? runner,
    String? droidPath,
    int maxPreviewChars = 16 * 1024,
  }) : _runner = runner ?? _defaultRunner,
       _exe = droidPath ?? _findDroid(),
       _maxPreviewChars = maxPreviewChars;

  final DroidAgentProcessRunner _runner;
  final String _exe;
  final int _maxPreviewChars;

  @override
  String get id => 'droid';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
  }) async {
    final args = [
      'exec',
      '--output-format',
      'text',
      '--model',
      modelId,
      _agentInstruction(instruction),
    ];
    return _boundedResult(await _runner(_exe, args, workspace, timeout));
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

  static Future<AgentRunResult> _defaultRunner(
    String exe,
    List<String> args,
    Directory workspace,
    Duration timeout,
  ) async {
    final sw = Stopwatch()..start();
    final process = await Process.start(
      exe,
      args,
      workingDirectory: workspace.path,
      runInShell: false,
      includeParentEnvironment: true,
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(systemEncoding.decoder)
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(systemEncoding.decoder)
        .listen(stderrBuffer.write)
        .asFuture<void>();

    var timedOut = false;
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      await _terminateProcessTree(process.pid, ProcessSignal.sigterm);
      exitCode = await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () async {
          await _terminateProcessTree(process.pid, ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    await Future.wait([stdoutDone, stderrDone]);
    sw.stop();

    return AgentRunResult(
      status: timedOut
          ? AgentRunStatus.timeout
          : exitCode == 0
          ? AgentRunStatus.success
          : AgentRunStatus.failure,
      stdoutPreview: _trimPreview(stdoutBuffer.toString(), 16 * 1024),
      stderrPreview: _trimPreview(stderrBuffer.toString(), 16 * 1024),
      exitCode: timedOut && exitCode == -1 ? null : exitCode,
      latency: sw.elapsed,
      metadata: {
        'executable': exe,
        'argc': args.length,
        'workspace': workspace.path,
      },
    );
  }

  static String _trimPreview(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return value.substring(value.length - maxChars);
  }

  static Future<void> _terminateProcessTree(
    int pid,
    ProcessSignal signal,
  ) async {
    if (Platform.isWindows) {
      final args = ['/PID', '$pid', '/T'];
      if (signal == ProcessSignal.sigkill) args.add('/F');
      await Process.run('taskkill', args);
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
      return await Process.run(executable, arguments);
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
