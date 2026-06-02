import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/agentic_run_orchestrator.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_state.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/headless_fakes.dart';

class _FakeHarness implements AgentHarness {
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
  }) async {
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

class _CapturingDeniedKeysHarness implements AgentHarness {
  Set<String> deniedKeys = const {};

  @override
  String get id => 'fake_agent';

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
  }) async {
    deniedKeys = Set.unmodifiable(deniedEnvironmentKeys);
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

class _FakeProvider with Disposable implements ModelProvider {
  var generateCalls = 0;

  @override
  String get id => 'fake_agent';
  @override
  String get displayName => 'Fake Agent';
  @override
  ProviderMode get mode => ProviderMode.agent;
  @override
  Future<List<ModelInfo>> listModels() async => [const ModelInfo(id: 'm')];
  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    generateCalls++;
    return const ModelResponse(
      rawText: '```dart\nint answer() => 42;\n```',
      extractedCode: null,
      promptTokens: 1,
      completionTokens: 1,
      latency: Duration(milliseconds: 1),
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

class _CodegenTask extends _AgenticAnswerTask {
  @override
  String get id => 'codegen.answer';
  @override
  BenchmarkTrack get track => BenchmarkTrack.codegen;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [_AnswerEvaluator()];
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
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
  }) async {
    calls++;
    if (calls == 1) return const PrepareOk();
    return const PrepareFailed('grading prepare failed');
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
        workdirManager: WorkdirManager(
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
    },
    timeout: const Timeout(Duration(minutes: 2)),
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
    'RunBloc routes codegen tasks through provider and agentic tasks through harness',
    () async {
      final root = await Directory.systemTemp.createTemp('agentic_bloc_');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await root.exists()) await root.delete(recursive: true);
      });

      var harnessCalls = 0;
      final provider = _FakeProvider();
      final bloc = RunBloc(
        workdirManager: WorkdirManager(root: root),
        runDao: RunDao(db),
        now: () => DateTime.now(),
        idGenerator: () => 'run-mixed',
        agentHarnesses: [
          _FakeHarness((workspace) async {
            harnessCalls++;
            await File(
              p.join(workspace.path, 'lib', 'answer.dart'),
            ).writeAsString('int answer() => 42;\n');
          }),
        ],
      );
      addTearDown(bloc.close);

      final completedFuture = bloc.stream
          .firstWhere((state) => state is RunCompleted)
          .then((state) => state as RunCompleted)
          .timeout(const Duration(minutes: 1));

      bloc.add(
        StartRun(
          tasks: [_CodegenTask(), _AgenticAnswerTask()],
          providers: [provider],
          modelsByProvider: const {
            'fake_agent': ['m'],
          },
          evaluatorConfig: const EvaluatorConfig(),
          maxConcurrency: 1,
        ),
      );

      final completed = await completedFuture;
      expect(provider.generateCalls, 1);
      expect(harnessCalls, 1);
      expect(completed.results.map((r) => r.benchmarkTrack).toSet(), {
        'codegen',
        'agentic',
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
