import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/runner/codegen_task_executor.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/headless_fakes.dart';

void main() {
  test(
    'compile failure blocks runtime evaluators without running them',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_blocking_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final analyze = _SpyEvaluator('analyze', result: _pass('analyze'));
      final publicTest = _SpyEvaluator('test', result: _pass('test'));
      final hiddenTest = _SpyEvaluator(
        'sample_hidden',
        result: _pass('sample_hidden'),
      );
      final task = _BlockingTask(
        evaluators: [
          const _CompileFailureEvaluator(),
          analyze,
          publicTest,
          hiddenTest,
        ],
      );
      final executor = CodegenTaskExecutor(
        workdirManager: NoOpPrepareWorkdirManager(root: root),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 2),
      );

      final result = await executor.run(
        runId: 'blocking-run',
        task: task,
        provider: DeterministicFakeProvider(
          rawText: '```dart\nString answer() => "generated";\n```',
        ),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(analyze.calls, 1);
      expect(publicTest.calls, 0);
      expect(hiddenTest.calls, 0);

      final publicTestResult = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(publicTestResult.passed, isFalse);
      expect(publicTestResult.rationale, 'blocked by compile');
      expect(publicTestResult.details['blocked'], isTrue);
      expect(publicTestResult.details['blocked_by'], 'compile');

      final hiddenResult = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'sample_hidden',
      );
      expect(hiddenResult.details['blocked_by'], 'compile');
      expect(result.failureTag, 'compile_failed');
      expect(result.primaryPass, isFalse);
    },
  );

  test(
    'prepare failure records environment root and blocked evaluators',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_prepare_blocking_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final compile = _SpyEvaluator('compile', result: _pass('compile'));
      final custom = _SpyEvaluator(
        'custom_check',
        result: _pass('custom_check'),
      );
      final task = _BlockingTask(evaluators: [compile, custom]);
      final executor = CodegenTaskExecutor(
        workdirManager: _PrepareFailingWorkdirManager(root: root),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 2),
      );

      final result = await executor.run(
        runId: 'prepare-blocking-run',
        task: task,
        provider: DeterministicFakeProvider(
          rawText: '```dart\nString answer() => "generated";\n```',
        ),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      expect(compile.calls, 0);
      expect(custom.calls, 0);
      expect(result.failureTag, 'environment_error');
      expect(result.primaryPass, isFalse);

      final environment = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'environment',
      );
      expect(environment.rationale, 'prepare failed');
      expect(environment.details['code'], 'environment_error');

      for (final evaluatorId in ['compile', 'custom_check']) {
        final blocked = result.evaluations.singleWhere(
          (evaluation) => evaluation.evaluatorId == evaluatorId,
        );
        expect(blocked.rationale, 'blocked by environment');
        expect(blocked.details[blockedDetailKey], isTrue);
        expect(blocked.details[blockedByDetailKey], 'environment');
        expect(blocked.details[blockedByRationaleDetailKey], 'prepare failed');
      }
    },
  );

  test('passes task network policy to prepare', () async {
    final root = await Directory.systemTemp.createTemp(
      'codegen_executor_prepare_policy_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final workdirManager = _PolicyRecordingWorkdirManager(root: root);
    final executor = CodegenTaskExecutor(
      workdirManager: workdirManager,
      weights: const {},
      now: () => DateTime.utc(2026, 6, 3),
    );

    await executor.run(
      runId: 'prepare-policy-run',
      task: _BlockingTask(evaluators: const [], networkAllowed: false),
      provider: DeterministicFakeProvider(rawText: 'String answer() => "";'),
      modelId: 'fake-headless-model',
      trialIndex: 0,
      evaluatorConfig: const EvaluatorConfig(),
    );

    expect(workdirManager.allowInternetValues, [false]);
  });

  test(
    'applies task max output bytes to public test evaluator',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_output_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final executor = CodegenTaskExecutor(
        workdirManager: WorkdirManager(
          root: Directory(p.join(root.path, 'wd')),
        ),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 3),
      );

      final result = await executor.run(
        runId: 'output-limit-run',
        task: _OutputLimitTask(),
        provider: DeterministicFakeProvider(rawText: 'int answer() => 42;'),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      final evaluation = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(evaluation.evaluatorId, 'test');
      expect(evaluation.rationale, 'test process output limit exceeded');
      expect(evaluation.details['output_limit_exceeded'], isTrue);
      expect(evaluation.details['max_output_chars'], 1024);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'applies task process limit to public test evaluator',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_process_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final executor = CodegenTaskExecutor(
        workdirManager: WorkdirManager(
          root: Directory(p.join(root.path, 'wd')),
        ),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 4),
      );

      final result = await executor.run(
        runId: 'process-limit-run',
        task: _ProcessLimitTask(),
        provider: DeterministicFakeProvider(rawText: 'int answer() => 42;'),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      final evaluation = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(evaluation.rationale, 'test process limit exceeded');
      expect(evaluation.details['process_limit_exceeded'], isTrue);
      expect(evaluation.details['max_processes'], 2);
      expect(evaluation.details['observed_processes'], greaterThan(2));
    },
    skip: Platform.isWindows ? 'POSIX child process test' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'applies task memory limit to public test evaluator',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'codegen_executor_memory_limit_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });

      final executor = CodegenTaskExecutor(
        workdirManager: WorkdirManager(
          root: Directory(p.join(root.path, 'wd')),
        ),
        weights: const {},
        now: () => DateTime.utc(2026, 6, 4),
      );

      final result = await executor.run(
        runId: 'memory-limit-run',
        task: _MemoryLimitTask(),
        provider: DeterministicFakeProvider(rawText: 'int answer() => 42;'),
        modelId: 'fake-headless-model',
        trialIndex: 0,
        evaluatorConfig: const EvaluatorConfig(),
      );

      final evaluation = result.evaluations.singleWhere(
        (evaluation) => evaluation.evaluatorId == 'test',
      );
      expect(evaluation.rationale, 'test process memory limit exceeded');
      expect(evaluation.details['memory_limit_exceeded'], isTrue);
      expect(evaluation.details['max_memory_mb'], 1);
      expect(evaluation.details['observed_memory_mb'], greaterThan(1));
    },
    skip: Platform.isWindows ? 'POSIX RSS polling test' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _BlockingTask extends BenchmarkTask {
  _BlockingTask({required this.evaluators, this.networkAllowed = false});

  final List<Evaluator> evaluators;
  final bool networkAllowed;

  @override
  String get id => 'phase1.blocking';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'Generate answer.dart';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: phase1_blocking
environment:
  sdk: ">=3.5.0 <4.0.0"
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  bool get allowInternet => networkAllowed;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => evaluators;
}

class _CompileFailureEvaluator implements Evaluator {
  const _CompileFailureEvaluator();

  @override
  String get id => 'compile';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    return const EvaluationResult(
      evaluatorId: 'compile',
      passed: false,
      score: 0.0,
      rationale: 'synthetic compile failure',
    );
  }
}

class _OutputLimitTask extends BenchmarkTask {
  @override
  String get id => 'phase1.output_limit';

  @override
  Category get category => Category.bugFix;

  @override
  bool get allowInternet => true;

  @override
  TaskResourceLimits get resourceLimits =>
      const TaskResourceLimits(maxOutputBytes: 1024);

  @override
  String get prompt => 'Generate answer.dart';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: phase1_output_limit
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''',
    'test/output_test.dart': '''
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('prints forever', () async {
    for (var i = 0; i < 128; i++) {
      stdout.writeln('x' * 512);
    }
    await Completer<void>().future;
  });
}
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    TestEvaluator(timeout: const Duration(seconds: 60)),
  ];
}

class _ProcessLimitTask extends BenchmarkTask {
  @override
  String get id => 'phase1.process_limit';

  @override
  Category get category => Category.bugFix;

  @override
  bool get allowInternet => true;

  @override
  TaskResourceLimits get resourceLimits =>
      const TaskResourceLimits(maxProcesses: 2);

  @override
  String get prompt => 'Generate answer.dart';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: phase1_process_limit
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''',
    'test/process_test.dart': '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('spawns a child process', () async {
    final process = await Process.start('sh', ['-c', 'sleep 20']);
    addTearDown(() => process.kill());
    await process.exitCode;
  });
}
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    TestEvaluator(timeout: const Duration(seconds: 60)),
  ];
}

class _MemoryLimitTask extends BenchmarkTask {
  @override
  String get id => 'phase1.memory_limit';

  @override
  Category get category => Category.bugFix;

  @override
  bool get allowInternet => true;

  @override
  TaskResourceLimits get resourceLimits =>
      const TaskResourceLimits(memoryMb: 1);

  @override
  String get prompt => 'Generate answer.dart';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': '''
name: phase1_memory_limit
environment:
  sdk: ">=3.5.0 <4.0.0"
dev_dependencies:
  test: ^1.25.0
''',
    'test/memory_test.dart': '''
import 'dart:async';

import 'package:test/test.dart';

void main() {
  test('stays alive long enough to sample RSS', () async {
    await Future<void>.delayed(const Duration(seconds: 20));
  });
}
''',
  };

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    TestEvaluator(timeout: const Duration(seconds: 60)),
  ];
}

class _SpyEvaluator implements Evaluator {
  _SpyEvaluator(this.id, {required this.result});

  @override
  final String id;
  final EvaluationResult result;
  var calls = 0;

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    calls++;
    return result;
  }
}

class _PrepareFailingWorkdirManager extends NoOpPrepareWorkdirManager {
  _PrepareFailingWorkdirManager({required super.root});

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
    return const PrepareFailed('dependency resolution failed');
  }
}

class _PolicyRecordingWorkdirManager extends NoOpPrepareWorkdirManager {
  _PolicyRecordingWorkdirManager({required super.root});

  final allowInternetValues = <bool>[];

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
    allowInternetValues.add(allowInternet);
    return const PrepareOk();
  }
}

EvaluationResult _pass(String evaluatorId) {
  return EvaluationResult(evaluatorId: evaluatorId, passed: true, score: 1.0);
}
