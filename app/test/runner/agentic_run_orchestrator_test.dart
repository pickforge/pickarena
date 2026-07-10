import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/runner/agentic_run_orchestrator.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../support/headless_fakes.dart';

class _FakeHarness implements AgentHarness {
  Directory? workspace;
  _FakeHarness(this.onRun);

  final Future<void> Function(Directory workspace) onRun;

  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
    bool requireGeneratedCodeSandbox = false,
  }) async {
    this.workspace = workspace;
    await onRun(workspace);
    return const AgentRunResult(
      status: AgentRunStatus.success,
      stdoutPreview: 'fixed',
      stderrPreview: '',
      exitCode: 0,
      latency: Duration(milliseconds: 10),
      trajectoryLogPath: '/tmp/trajectory.log',
    );
  }
}

class _MetadataHarness implements AgentHarness {
  const _MetadataHarness(this.metadata);

  final Map<String, Object?> metadata;

  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
    bool requireGeneratedCodeSandbox = false,
  }) async {
    await File(
      p.join(workspace.path, 'lib', 'answer.dart'),
    ).writeAsString('int answer() => 42;\n');
    return AgentRunResult(
      status: AgentRunStatus.success,
      stdoutPreview: 'fixed',
      stderrPreview: '',
      exitCode: 0,
      latency: const Duration(milliseconds: 10),
      metadata: metadata,
    );
  }
}

class _FailingHarness implements AgentHarness {
  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
    bool requireGeneratedCodeSandbox = false,
  }) async {
    return const AgentRunResult(
      status: AgentRunStatus.failure,
      stdoutPreview: '',
      stderrPreview: 'permission denied',
      exitCode: 1,
      latency: Duration(milliseconds: 10),
    );
  }
}

class _NoPreviewTimeoutHarness implements AgentHarness {
  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
    bool requireGeneratedCodeSandbox = false,
  }) async {
    await File(
      p.join(workspace.path, 'lib', 'answer.dart'),
    ).writeAsString('int answer() => 42;\n');
    return const AgentRunResult(
      status: AgentRunStatus.timeout,
      stdoutPreview: '',
      stderrPreview: '',
      exitCode: null,
      latency: Duration(milliseconds: 123),
    );
  }
}

class _CapturingDeniedKeysHarness implements AgentHarness {
  Set<String> deniedKeys = const {};
  var allowInternet = true;

  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
    bool allowInternet = true,
    bool requireGeneratedCodeSandbox = false,
  }) async {
    deniedKeys = Set.unmodifiable(deniedEnvironmentKeys);
    this.allowInternet = allowInternet;
    final file = File(p.join(workspace.path, 'lib', 'answer.dart'));
    await file.parent.create(recursive: true);
    await file.writeAsString('int answer() => 42;\n');
    return const AgentRunResult(
      status: AgentRunStatus.success,
      stdoutPreview: 'fixed',
      stderrPreview: '',
      exitCode: 0,
      latency: Duration(milliseconds: 10),
    );
  }
}

class _AnswerEvaluator implements Evaluator {
  @override
  String get id => 'answer';
  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final source = await File(
      p.join(ctx.workDir.path, 'lib', 'answer.dart'),
    ).readAsString();
    final passed = source.contains('42');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
    );
  }
}

class _GradingWorkspaceEvaluator implements Evaluator {
  Directory? workDir;

  @override
  String get id => 'grading_workspace';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    workDir = ctx.workDir;
    final source = await File(
      p.join(ctx.workDir.path, 'lib', 'answer.dart'),
    ).readAsString();
    final passed =
        source.contains('42') &&
        p.basename(ctx.workDir.path).endsWith('_grading');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1 : 0,
    );
  }
}

class _AgenticAnswerTask extends BenchmarkTask {
  @override
  String get id => 'agent.answer';
  @override
  Category get category => Category.bugFix;
  @override
  BenchmarkTrack get track => BenchmarkTrack.agentic;
  @override
  String get prompt => 'Make answer return 42.';
  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: tmp
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''',
    'lib/answer.dart': 'int answer() => 41;\n',
  };
  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      files: {
        'test/_hidden/answer_hidden_test.dart': '''
import 'package:test/test.dart';
import 'package:tmp/answer.dart';

void main() {
  test('answer is fixed', () => expect(answer(), 42));
}
''',
      },
      testPath: 'test/_hidden/answer_hidden_test.dart',
    ),
  ];
  @override
  String get generatedCodePath => 'lib/answer.dart';
  @override
  String? get judgeRubric => null;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    _AnswerEvaluator(),
    ...hiddenVerifiers.map(HiddenTestEvaluator.new),
  ];
}

class _AgenticBlockingTask extends _AgenticAnswerTask {
  _AgenticBlockingTask(this.evaluators);

  final List<Evaluator> evaluators;

  @override
  String get id => 'agent.blocking';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => evaluators;
}

class _FailingPrepareWorkdirManager extends NoOpPrepareWorkdirManager {
  _FailingPrepareWorkdirManager({required super.root});

  var calls = 0;

  @override
  Future<PrepareResult> prepare(
    Directory workDir, {
    bool isFlutter = false,
    bool allowInternet = true,
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
    GeneratedCodeSandbox? generatedCodeSandbox,
    int? maxCpuCores,
  }) async {
    calls++;
    if (calls == 1) return const PrepareOk();
    return const PrepareFailed('grading prepare failed');
  }
}

class _ArtifactPrepareWorkdirManager extends NoOpPrepareWorkdirManager {
  _ArtifactPrepareWorkdirManager({required super.root});

  @override
  Future<PrepareResult> prepare(
    Directory workDir, {
    bool isFlutter = false,
    bool allowInternet = true,
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
    GeneratedCodeSandbox? generatedCodeSandbox,
    int? maxCpuCores,
  }) async {
    await File(p.join(workDir.path, 'prepared.txt')).writeAsString('prepared');
    await File(
      p.join(workDir.path, '.dart_arena', 'flutter-cache-files', 'lockfile'),
    ).create(recursive: true);
    await File(p.join(workDir.path, '.flutter')).writeAsString('');
    await File(
      p.join(workDir.path, '.config', 'tool_state'),
    ).create(recursive: true);
    return const PrepareOk();
  }
}

class _SpyEvaluator implements Evaluator {
  _SpyEvaluator(this.id);

  @override
  final String id;
  var calls = 0;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    calls++;
    return EvaluationResult(evaluatorId: id, passed: true, score: 1.0);
  }
}

void main() {
  test(
    'runs harness in visible workspace, captures patch, then injects hidden verifier',
    () async {
      final root = await Directory.systemTemp.createTemp('agentic_orch_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      var hiddenAbsentDuringHarness = false;
      late Directory workspaceSeenByHarness;
      final orchestrator = AgenticRunOrchestrator(
        workdirManager: WorkdirManager(root: root),
        now: () => DateTime(2026, 5, 29),
      );
      final result = await orchestrator.run(
        runId: 'run-1',
        task: _AgenticAnswerTask(),
        harness: _FakeHarness((workspace) async {
          workspaceSeenByHarness = workspace;
          hiddenAbsentDuringHarness = !File(
            p.join(
              workspace.path,
              'test',
              '_hidden',
              'answer_hidden_test.dart',
            ),
          ).existsSync();
          await File(
            p.join(workspace.path, 'lib', 'answer.dart'),
          ).writeAsString('int answer() => 42;\n');
        }),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(hiddenAbsentDuringHarness, isTrue);
      expect(result.benchmarkTrack, 'agentic');
      expect(result.harnessId, 'fake_agent');
      expect(result.patchText, contains('-int answer() => 41;'));
      expect(result.patchText, contains('+int answer() => 42;'));
      expect(result.trajectoryLogPath, '/tmp/trajectory.log');
      expect(result.primaryPass, isTrue);
      expect(
        result.evaluations
            .singleWhere((e) => e.evaluatorId == 'hidden_test')
            .passed,
        isTrue,
      );
      expect(
        File(
          p.join(
            workspaceSeenByHarness.path,
            'test',
            '_hidden',
            'answer_hidden_test.dart',
          ),
        ).existsSync(),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'captures only harness changes after resetting the prepared baseline',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'agentic_orch_prepared_baseline_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final orchestrator = AgenticRunOrchestrator(
        workdirManager: _ArtifactPrepareWorkdirManager(root: root),
        now: () => DateTime(2026, 6, 5),
      );
      final result = await orchestrator.run(
        runId: 'run-prepared-baseline',
        task: _AgenticAnswerTask(),
        harness: _FakeHarness((workspace) async {
          await File(
            p.join(workspace.path, 'lib', 'answer.dart'),
          ).writeAsString('int answer() => 42;\n');
        }),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(result.patchText, contains('-int answer() => 41;'));
      expect(result.patchText, contains('+int answer() => 42;'));
      expect(result.patchText, isNot(contains('prepared.txt')));
      expect(result.patchText, isNot(contains('.dart_arena')));
      expect(result.patchText, isNot(contains('.flutter')));
      expect(result.patchText, isNot(contains('tool_state')));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('grades the replayed patch in the sibling grading workspace', () async {
    final root = await Directory.systemTemp.createTemp(
      'agentic_orch_clean_replay_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final evaluator = _GradingWorkspaceEvaluator();
    final task = _AgenticBlockingTask([evaluator]);
    final harness = _FakeHarness((workspace) async {
      await File(
        p.join(workspace.path, 'lib', 'answer.dart'),
      ).writeAsString('int answer() => 42;\n');
    });

    final result =
        await AgenticRunOrchestrator(
          workdirManager: NoOpPrepareWorkdirManager(root: root),
        ).run(
          runId: 'run-clean-replay',
          task: task,
          harness: harness,
          providerId: 'fake_agent',
          modelId: 'm',
          trialIndex: 0,
          evaluatorConfig: const EvaluatorConfig(),
        );

    expect(
      result.evaluations
          .singleWhere((e) => e.evaluatorId == evaluator.id)
          .passed,
      isTrue,
    );
    expect(evaluator.workDir, isNotNull);
    expect(p.basename(evaluator.workDir!.path), 'trial_0_grading');
    expect(
      p.dirname(evaluator.workDir!.path),
      p.dirname(harness.workspace!.path),
    );
    expect(
      p.isWithin(harness.workspace!.path, evaluator.workDir!.path),
      isFalse,
    );
    expect(result.provenance['gradingMode'], 'clean_replay');
    expect(result.provenance['patchApplied'], isTrue);
    expect(
      result.provenance['patchSha256'],
      matches(RegExp(r'^[0-9a-f]{64}$')),
    );
  });

  test('records hidden fixture leaks from the agent workspace', () async {
    final root = await Directory.systemTemp.createTemp(
      'agentic_orch_fixture_leak_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final task = _AgenticBlockingTask(const []);
    final result =
        await AgenticRunOrchestrator(
          workdirManager: NoOpPrepareWorkdirManager(root: root),
        ).run(
          runId: 'run-fixture-leak',
          task: task,
          harness: _FakeHarness((workspace) async {
            final hidden = File(
              p.join(
                workspace.path,
                'test',
                '_hidden',
                'answer_hidden_test.dart',
              ),
            );
            await hidden.parent.create(recursive: true);
            await hidden.writeAsString('leaked');
          }),
          providerId: 'fake_agent',
          modelId: 'm',
          trialIndex: 0,
          evaluatorConfig: const EvaluatorConfig(),
        );

    final isolation =
        result.provenance['hiddenFixtureIsolation'] as Map<String, Object?>;
    expect(isolation['asserted'], isTrue);
    expect(isolation['leakedPaths'], ['test/_hidden/answer_hidden_test.dart']);
  });

  test(
    'passes denied environment keys to the agent harness',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_denied_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final harness = _CapturingDeniedKeysHarness();
      final orchestrator = AgenticRunOrchestrator(
        workdirManager: NoOpPrepareWorkdirManager(
          root: root,
          deniedEnvironmentKeys: const ['SECRET_KEY'],
        ),
        now: () => DateTime(2026, 5, 29),
      );

      await orchestrator.run(
        runId: 'run-denied',
        task: _AgenticAnswerTask(),
        harness: harness,
        providerId: 'fake_agent',
        modelId: 'fake-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(harness.deniedKeys, contains('SECRET_KEY'));
      expect(harness.allowInternet, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'sanitizes raw harness metadata before storing evaluator details',
    () async {
      final root = await Directory.systemTemp.createTemp('agentic_metadata_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final privateWorkspace = p.join(root.path, 'private', 'workspace');
      final orchestrator = AgenticRunOrchestrator(
        workdirManager: WorkdirManager(root: root),
        now: () => DateTime(2026, 5, 29),
      );
      final result = await orchestrator.run(
        runId: 'run-metadata',
        task: _AgenticAnswerTask(),
        harness: _MetadataHarness({
          'workspace': privateWorkspace,
          'executable': '/home/dev/.local/bin/droid',
          'command': 'droid exec secret prompt',
          'api_key': 'secret-token-value',
          'argc': 8,
          'stepCount': 6,
          'peakContextTokens': 12000,
          'output_limit_exceeded': true,
          'max_output_chars': 128,
          'runtimeBoundary': {'enforced': true, 'backend': 'bubblewrap'},
          'metadata': {'workspacePath': privateWorkspace, 'stepCount': 7},
          'exception': 'StateError',
        }),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      final details = result.evaluations
          .singleWhere(
            (evaluation) => evaluation.evaluatorId == 'agent_harness',
          )
          .details;
      final encoded = jsonEncode(details);

      expect(details, containsPair('argc', 8));
      expect(details, containsPair('stepCount', 6));
      expect(details, containsPair('peakContextTokens', 12000));
      expect(details, containsPair('output_limit_exceeded', true));
      expect(details, containsPair('max_output_chars', 128));
      expect(details['runtimeBoundary'], {
        'enforced': true,
        'backend': 'bubblewrap',
      });
      expect(details, containsPair('exception', 'StateError'));
      expect(details, containsPair('metadata_redacted_count', 4));
      expect(details['metadata'], {
        'stepCount': 7,
        'metadata_redacted_count': 1,
      });
      expect(encoded, isNot(contains(privateWorkspace)));
      expect(encoded, isNot(contains('/home/dev/.local/bin/droid')));
      expect(encoded, isNot(contains('droid exec secret prompt')));
      expect(encoded, isNot(contains('secret-token-value')));
      expect(details.containsKey('workspace'), isFalse);
      expect(details.containsKey('executable'), isFalse);
      expect(details.containsKey('command'), isFalse);
      expect(details.containsKey('api_key'), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'no-preview harness timeout stores fallback response evidence',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_agentic_timeout_response_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final orchestrator = AgenticRunOrchestrator(
        workdirManager: WorkdirManager(root: root),
        now: () => DateTime(2026, 6, 4),
      );

      final result = await orchestrator.run(
        runId: 'run-timeout-response',
        task: _AgenticAnswerTask(),
        harness: _NoPreviewTimeoutHarness(),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(result.failureTag, 'harness_timeout');
      expect(result.response.rawText, contains('no stdout/stderr preview'));
      expect(result.response.rawText, contains('status: timeout'));
      expect(result.response.rawText, contains('latencyMs: 123'));
      expect(result.patchText, contains('+int answer() => 42;'));
    },
  );

  test('missing harness creates a clear agentic result failure', () {
    final orchestrator = AgenticRunOrchestrator(
      workdirManager: WorkdirManager(root: Directory.systemTemp),
      now: () => DateTime(2026, 5, 29),
    );

    final result = orchestrator.missingHarnessResult(
      runId: 'r',
      task: _AgenticAnswerTask(),
      providerId: 'raw',
      modelId: 'm',
      trialIndex: 0,
    );

    expect(result.benchmarkTrack, 'agentic');
    expect(result.harnessId, isNull);
    expect(result.primaryPass, isFalse);
    expect(result.failureTag, 'harness_error');
    expect(result.evaluations.single.evaluatorId, 'agent_harness');
    expect(result.evaluations.single.rationale, 'no agent harness configured');
  });

  test(
    'failed harness blocks objective task evaluators after prepare failure',
    () async {
      final root = await Directory.systemTemp.createTemp('agentic_blocking_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final compile = _SpyEvaluator('compile');
      final testEvaluator = _SpyEvaluator('test');
      final orchestrator = AgenticRunOrchestrator(
        workdirManager: _FailingPrepareWorkdirManager(root: root),
        now: () => DateTime(2026, 6, 2),
      );

      final result = await orchestrator.run(
        runId: 'run-blocking',
        task: _AgenticBlockingTask([compile, testEvaluator]),
        harness: _FailingHarness(),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(result.failureTag, 'harness_error');
      expect(compile.calls, 0);
      expect(testEvaluator.calls, 0);
      final blockedCompile = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'compile',
      );
      expect(blockedCompile.rationale, 'blocked by agent_harness');
      expect(blockedCompile.details['blocked'], isTrue);
      expect(blockedCompile.details['blocked_by'], 'agent_harness');
      final blockedTest = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(blockedTest.details['blocked_by'], 'agent_harness');
    },
  );

  test(
    'grading prepare failure records environment root and blocked evaluators',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'agentic_prepare_blocking_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final compile = _SpyEvaluator('compile');
      final custom = _SpyEvaluator('custom_check');
      final orchestrator = AgenticRunOrchestrator(
        workdirManager: _FailingPrepareWorkdirManager(root: root),
        now: () => DateTime(2026, 6, 2),
      );

      final result = await orchestrator.run(
        runId: 'run-prepare-blocking',
        task: _AgenticBlockingTask([compile, custom]),
        harness: _FakeHarness((workspace) async {}),
        providerId: 'fake_agent',
        modelId: 'm',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(result.failureTag, 'environment_error');
      expect(compile.calls, 0);
      expect(custom.calls, 0);
      final environment = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'environment',
      );
      expect(environment.rationale, 'prepare failed');
      expect(environment.details['phase'], 'grading_prepare');

      for (final evaluatorId in ['compile', 'custom_check']) {
        final blocked = result.evaluations.singleWhere(
          (evaluation) => evaluation.evaluatorId == evaluatorId,
        );
        expect(blocked.rationale, 'blocked by environment');
        expect(blocked.details[blockedDetailKey], isTrue);
        expect(blocked.details[blockedByDetailKey], 'environment');
      }
    },
  );
}
