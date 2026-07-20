import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/runner/bounded_subprocess.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

const patchBaselineRef = 'arena_baseline';

class PatchCaptureResult {
  const PatchCaptureResult({
    required this.patch,
    required this.status,
    required this.patchSha256,
  });

  final String patch;
  final String status;
  final String patchSha256;

  bool get hasMeaningfulDiff => patch.trim().isNotEmpty;
}

class PatchCapture {
  const PatchCapture({
    this.gitExecutable = 'git',
    this.deniedEnvironmentKeys = const [],
    this.baseEnvironment,
    this.timeout = const Duration(seconds: 15),
    this.maxOutputChars = 1024 * 1024,
  }) : assert(maxOutputChars > 0);

  final String gitExecutable;
  final Iterable<String> deniedEnvironmentKeys;
  final Map<String, String>? baseEnvironment;
  final Duration timeout;
  final int maxOutputChars;

  Future<PatchCaptureResult> capture(
    Directory workspace, {
    String baselineRef = patchBaselineRef,
  }) async {
    const addIntentArgs = ['add', '-N', '.'];
    final intentToAdd = await _runGit(workspace, addIntentArgs);
    _checkGitResult(intentToAdd, addIntentArgs);
    const statusArgs = ['status', '--porcelain'];
    final diffArgs = ['diff', baselineRef, '--binary'];
    final status = await _runGit(workspace, statusArgs);
    final diff = await _runGit(workspace, diffArgs);
    _checkGitResult(status, statusArgs);
    _checkGitResult(diff, diffArgs);
    final patch = diff.stdout.toString();
    return PatchCaptureResult(
      patch: patch,
      status: status.stdout.toString(),
      patchSha256: sha256.convert(utf8.encode(patch)).toString(),
    );
  }

  Future<BoundedSubprocessResult> _runGit(
    Directory workspace,
    List<String> args,
  ) async {
    final processEnvironment = _gitEnvironment();
    return runBoundedSubprocess(
      executable: gitExecutable,
      arguments: args,
      workingDirectory: workspace.path,
      environment: processEnvironment,
      maxOutputBytes: maxEncodedOutputBytes(maxOutputChars),
      maxOutputCharacters: maxOutputChars,
      timeout: timeout,
      helperEnvironment: processEnvironment,
    );
  }

  void _checkGitResult(BoundedSubprocessResult result, List<String> args) {
    if (result.termination == BoundedSubprocessTermination.timedOut) {
      throw TimeoutException('patch capture git command timed out', timeout);
    }
    if (result.outputLimitExceeded ||
        result.stdoutLimitExceeded ||
        result.stderrLimitExceeded) {
      throw ProcessException(
        gitExecutable,
        args,
        'patch capture git output exceeded $maxOutputChars characters\n'
        '${result.stdout}\n${result.stderr}',
        -1,
      );
    }
    if (result.exitCode != 0) {
      throw ProcessException(
        gitExecutable,
        args,
        result.stderr,
        result.exitCode,
      );
    }
  }

  Map<String, String> _gitEnvironment() {
    return benchmarkSubprocessEnvironment(
      baseEnvironment: baseEnvironment,
      additionalDeniedKeys: {
        ...deniedEnvironmentKeys,
        'HOME',
        'XDG_CONFIG_HOME',
        'XDG_CONFIG_DIRS',
      },
    )..addAll(const {'GIT_CONFIG_NOSYSTEM': '1', 'GIT_TERMINAL_PROMPT': '0'});
  }
}
