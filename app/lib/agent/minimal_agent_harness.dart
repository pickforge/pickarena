import 'dart:async';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/agent/droid_agent_harness.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/subprocess_environment.dart';

class MinimalAgentHarness implements AgentHarness {
  MinimalAgentHarness({
    required this.provider,
    required this.harnessId,
    this.generatedCodeSandbox,
    this.requireGeneratedCodeSandbox = false,
    Iterable<String> deniedEnvironmentKeys = const [],
    this.maxSteps = 20,
    this.maxOutputChars = 16 * 1024,
    this.maxHistoryChars = 64 * 1024,
  }) : _deniedEnvironmentKeys = Set.unmodifiable(deniedEnvironmentKeys),
       assert(maxSteps > 0),
       assert(maxOutputChars > 0),
       assert(maxHistoryChars > 0);

  final StreamingModelProvider provider;
  final String harnessId;
  final GeneratedCodeSandbox? generatedCodeSandbox;
  final bool requireGeneratedCodeSandbox;
  final Set<String> _deniedEnvironmentKeys;
  final int maxSteps;
  final int maxOutputChars;
  final int maxHistoryChars;

  @override
  String get id => harnessId;

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final history = <_StepObservation>[];
    final stdout = _BoundedTailText(maxOutputChars);
    final stderr = _BoundedTailText(maxOutputChars);
    final deniedKeys = {..._deniedEnvironmentKeys, ...deniedEnvironmentKeys};
    var steps = 0;
    var promptTokens = 0;
    var completionTokens = 0;
    var reportedPromptTokens = false;
    var reportedCompletionTokens = false;
    var historyTruncated = false;
    var outputTruncated = false;

    AgentRunResult result(
      AgentRunStatus status,
      String terminalReason, {
      int? exitCode,
    }) {
      stopwatch.stop();
      return AgentRunResult(
        status: status,
        stdoutPreview: stdout.text,
        stderrPreview: stderr.text,
        exitCode: exitCode,
        latency: stopwatch.elapsed,
        promptTokens: reportedPromptTokens ? promptTokens : null,
        completionTokens: reportedCompletionTokens ? completionTokens : null,
        metadata: {
          'terminal_reason': terminalReason,
          'step_count': steps,
          if (historyTruncated) 'history_truncated': true,
          'runtimeBoundary': {
            'enforced': generatedCodeSandbox != null,
            if (generatedCodeSandbox != null)
              'backend': generatedCodeSandbox!.backend,
          },
          if (outputTruncated) 'output_truncated': true,
        },
      );
    }

    if (requireGeneratedCodeSandbox && generatedCodeSandbox == null) {
      stderr.write('generated-code sandbox is required but not configured');
      return result(AgentRunStatus.failure, 'sandbox_required', exitCode: 1);
    }

    while (true) {
      final remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        return result(AgentRunStatus.timeout, 'timeout');
      }

      _ModelCompletion completion;
      try {
        completion = await _complete(
          prompt: _prompt(instruction, history),
          modelId: modelId,
          timeout: remaining,
        );
      } on TimeoutException {
        return result(AgentRunStatus.timeout, 'timeout');
      } on Object catch (error) {
        stderr.write('model error: $error');
        return result(AgentRunStatus.failure, 'error', exitCode: 1);
      }
      if (completion.promptTokens != null) {
        promptTokens += completion.promptTokens!;
        reportedPromptTokens = true;
      }
      if (completion.completionTokens != null) {
        completionTokens += completion.completionTokens!;
        reportedCompletionTokens = true;
      }

      final reply = completion.text.trim();
      if (reply == 'FINISH') {
        return result(AgentRunStatus.success, 'finished', exitCode: 0);
      }
      final command = _parseBashCommand(reply);
      if (command == null) {
        stderr.write('model reply must be FINISH or one fenced bash block');
        return result(AgentRunStatus.failure, 'malformed_reply', exitCode: 1);
      }

      final remainingAfterCompletion = timeout - stopwatch.elapsed;
      if (remainingAfterCompletion <= Duration.zero) {
        return result(AgentRunStatus.timeout, 'timeout');
      }
      _CommandResult commandResult;
      try {
        commandResult = await _runCommand(
          command: command,
          workspace: workspace,
          timeout: remainingAfterCompletion,
          deniedEnvironmentKeys: deniedKeys,
          allowInternet: allowInternet,
        );
      } on TimeoutException {
        return result(AgentRunStatus.timeout, 'timeout');
      } on Object catch (error) {
        stderr.write('bash error: $error');
        return result(AgentRunStatus.failure, 'error', exitCode: 1);
      }
      steps++;
      stdout.write(commandResult.stdout);
      stderr.write(commandResult.stderr);
      outputTruncated = outputTruncated || commandResult.outputTruncated;
      history.add(
        _StepObservation(
          command: command,
          observation: _observation(commandResult),
        ),
      );
      historyTruncated = _boundHistory(history) || historyTruncated;
      if (steps >= maxSteps) {
        return result(AgentRunStatus.failure, 'max_steps', exitCode: 1);
      }
    }
  }

  Future<_ModelCompletion> _complete({
    required String prompt,
    required String modelId,
    required Duration timeout,
  }) async {
    final text = StringBuffer();
    int? promptTokens;
    int? completionTokens;
    final events = await provider
        .generateStream(prompt: prompt, model: modelId, timeout: timeout)
        .toList()
        .timeout(timeout);
    for (final event in events) {
      if (event is ModelStreamContentDelta) {
        text.write(event.text);
      } else if (event is ModelStreamUsage) {
        promptTokens = event.promptTokens ?? promptTokens;
        completionTokens = event.completionTokens ?? completionTokens;
      }
    }
    return _ModelCompletion(
      text: text.toString(),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<_CommandResult> _runCommand({
    required String command,
    required Directory workspace,
    required Duration timeout,
    required Iterable<String> deniedEnvironmentKeys,
    required bool allowInternet,
  }) async {
    final environment = benchmarkSubprocessEnvironment(
      additionalDeniedKeys: deniedEnvironmentKeys,
      homeDirectory: workspace.path,
    );
    environment['PWD'] = workspace.path;
    final processStart = generatedCodeSandbox == null
        ? SandboxedProcessStart(
            executable: 'bash',
            arguments: ['--noprofile', '--norc', '-c', command],
            workingDirectory: workspace.path,
            environment: environment,
          )
        : await generatedCodeSandbox!.wrapProcess(
            executable: 'bash',
            arguments: ['--noprofile', '--norc', '-c', command],
            workingDirectory: workspace.path,
            environment: environment,
            allowInternet: allowInternet,
          );
    final process = await Process.start(
      processStart.executable,
      processStart.arguments,
      workingDirectory: processStart.workingDirectory,
      runInShell: false,
      environment: processStart.environment,
      includeParentEnvironment: false,
    );
    final stdout = _BoundedTailText(maxOutputChars);
    final stderr = _BoundedTailText(maxOutputChars);
    final stdoutDone = process.stdout
        .transform(systemEncoding.decoder)
        .listen(stdout.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(systemEncoding.decoder)
        .listen(stderr.write)
        .asFuture<void>();
    int exitCode;
    var timedOut = false;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      await DroidAgentHarness.terminateProcessTree(
        process.pid,
        ProcessSignal.sigterm,
      );
      exitCode = await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () async {
          await DroidAgentHarness.terminateProcessTree(
            process.pid,
            ProcessSignal.sigkill,
          );
          return -1;
        },
      );
    }
    await Future.wait([stdoutDone, stderrDone]);
    if (timedOut) throw TimeoutException('bash command timed out');
    return _CommandResult(
      exitCode: exitCode,
      stdout: stdout.text,
      stderr: stderr.text,
      outputTruncated: stdout.exceeded || stderr.exceeded,
    );
  }

  bool _boundHistory(List<_StepObservation> history) {
    var truncated = false;
    while (_historyLength(history) > maxHistoryChars && history.isNotEmpty) {
      final oldest = history.first;
      final excess = _historyLength(history) - maxHistoryChars;
      if (oldest.observation.length > excess) {
        oldest.observation = oldest.observation.substring(excess);
      } else {
        history.removeAt(0);
      }
      truncated = true;
    }
    return truncated;
  }

  static int _historyLength(List<_StepObservation> history) => history.fold(
    0,
    (length, step) =>
        length + step.command.length + step.observation.length + 32,
  );

  static String _prompt(String instruction, List<_StepObservation> history) {
    final buffer = StringBuffer(
      '''You are in an isolated benchmark workspace. Complete the task using only bash commands in the workspace.

Task:
$instruction

You have one tool: bash. Reply with exactly one of these formats and no other text:
FINISH
or
```bash
<bash command>
```
''',
    );
    for (final step in history) {
      buffer
        ..write('\nPrevious bash command:\n```bash\n')
        ..write(step.command)
        ..write('\n```\nObservation:\n')
        ..write(step.observation)
        ..write('\n');
    }
    return buffer.toString();
  }

  static String? _parseBashCommand(String reply) {
    final fence = RegExp(r'```bash[ \t]*\r?\n');
    if (fence.allMatches(reply).length != 1) return null;
    final match = RegExp(
      r'^```bash[ \t]*\r?\n([\s\S]*?)\r?\n```$',
    ).firstMatch(reply);
    final command = match?.group(1)?.trim();
    return command == null || command.isEmpty ? null : command;
  }

  static String _observation(_CommandResult result) =>
      'exit code: ${result.exitCode}\nstdout:\n${result.stdout}${result.outputTruncated ? '\n...[truncated]...' : ''}\nstderr:\n${result.stderr}';
}

class _StepObservation {
  _StepObservation({required this.command, required this.observation});

  final String command;
  String observation;
}

class _ModelCompletion {
  const _ModelCompletion({
    required this.text,
    required this.promptTokens,
    required this.completionTokens,
  });

  final String text;
  final int? promptTokens;
  final int? completionTokens;
}

class _CommandResult {
  const _CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.outputTruncated,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final bool outputTruncated;
}

class _BoundedTailText {
  _BoundedTailText(this.maxChars);

  final int maxChars;
  final _buffer = StringBuffer();
  var exceeded = false;

  void write(String chunk) {
    _buffer.write(chunk);
    if (_buffer.length > maxChars) {
      exceeded = true;
      final text = _buffer.toString();
      _buffer
        ..clear()
        ..write(text.substring(text.length - maxChars));
    }
  }

  String get text => _buffer.toString();
}
