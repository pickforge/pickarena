import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/headless/headless_benchmark_runner.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

import '../support/headless_fakes.dart';

const _weights = <String, double>{
  'smoke_generated_code': 1.0,
  'smoke_generated_file': 1.0,
};

class _HeadlessSmokeTask extends BenchmarkTask {
  @override
  String get id => 'phase7.headless_smoke';

  @override
  int get version => 1;

  @override
  Category get category => Category.widgetTesting;

  @override
  Set<TaskTag> get tags => const {TaskTag.testing};

  @override
  TaskDifficulty get difficulty => TaskDifficulty.easy;

  @override
  Duration? get timeout => const Duration(seconds: 2);

  @override
  String get prompt => 'Generate a Dart function named headlessAnswer.';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml':
        'name: phase7_headless_smoke\nenvironment:\n'
        '  sdk: ">=3.5.0 <4.0.0"\n',
  };

  @override
  String get generatedCodePath => 'lib/headless_answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [
    _GeneratedCodePresentEvaluator(),
    _GeneratedFilePresentEvaluator(),
  ];
}

class _AgenticHeadlessSmokeTask extends _HeadlessSmokeTask {
  @override
  String get id => 'agentic.phase7.headless_smoke';

  @override
  BenchmarkTrack get track => BenchmarkTrack.agentic;
}

class _GeneratedCodePresentEvaluator implements Evaluator {
  const _GeneratedCodePresentEvaluator();

  @override
  String get id => 'smoke_generated_code';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final code = ctx.response.extractedCode ?? '';
    final passed = code.contains('headlessAnswer') && code.contains('phase7');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'generated code present' : 'generated code missing',
      details: const {'checked': 'response.extractedCode'},
    );
  }
}

class _GeneratedFilePresentEvaluator implements Evaluator {
  const _GeneratedFilePresentEvaluator();

  @override
  String get id => 'smoke_generated_file';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final file = File(p.join(ctx.workDir.path, ctx.task.generatedCodePath));
    final text = await file.exists() ? await file.readAsString() : '';
    final passed = text.contains('headlessAnswer') && text.contains('phase7');
    return EvaluationResult(
      evaluatorId: id,
      passed: passed,
      score: passed ? 1.0 : 0.0,
      rationale: passed ? 'generated file present' : 'generated file missing',
      details: {'generatedCodePath': ctx.task.generatedCodePath},
    );
  }
}

class _SlowFakeProvider with Disposable implements ModelProvider {
  final String providerId = 'slow_headless';
  final String providerDisplayName = 'Slow Headless';
  final String modelId = 'slow-headless-model';
  final Duration delay = const Duration(milliseconds: 180);
  final started = Completer<void>();
  final completed = Completer<void>();
  var disposed = false;

  @override
  String get id => providerId;

  @override
  String get displayName => providerDisplayName;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => [ModelInfo(id: modelId)];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    if (model != modelId) {
      throw ArgumentError.value(model, 'model', 'unknown fake model');
    }
    if (!started.isCompleted) started.complete();
    await Future<void>.delayed(delay);
    if (!completed.isCompleted) completed.complete();
    return ModelResponse(
      rawText: '```dart\nString headlessAnswer() => \'phase7\';\n```',
      extractedCode: null,
      promptTokens: 13,
      completionTokens: 8,
      latency: delay,
    );
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _NoPreviewTimeoutAgentHarness implements AgentHarness {
  const _NoPreviewTimeoutAgentHarness({
    required this.harnessId,
    required this.modelId,
  });

  final String harnessId;
  final String modelId;

  @override
  String get id => harnessId;

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
  }) async {
    expect(modelId, this.modelId);
    final file = File(p.join(workspace.path, 'lib', 'headless_answer.dart'));
    await file.parent.create(recursive: true);
    await file.writeAsString("String headlessAnswer() => 'phase7';\n");
    return const AgentRunResult(
      status: AgentRunStatus.timeout,
      stdoutPreview: '',
      stderrPreview: '',
      exitCode: null,
      latency: Duration(milliseconds: 25),
    );
  }
}

class _NoPreviewFailureAgentHarness implements AgentHarness {
  const _NoPreviewFailureAgentHarness({
    required this.harnessId,
    required this.modelId,
  });

  final String harnessId;
  final String modelId;

  @override
  String get id => harnessId;

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
  }) async {
    expect(modelId, this.modelId);
    return const AgentRunResult(
      status: AgentRunStatus.failure,
      stdoutPreview: '',
      stderrPreview: '',
      exitCode: 1,
      latency: Duration(milliseconds: 25),
    );
  }
}

void main() {
  test(
    'runs deterministic headless smoke and exports a Phase 6 bundle',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_ok_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final provider = DeterministicFakeProvider();

      final result = await const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-smoke-run',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
        ),
      );

      expect(provider.disposed, isTrue);
      expect(result.runId, 'headless-smoke-run');
      expect(result.finalSummary.run.completedAt, isNotNull);
      expect(result.taskRunCount, 1);
      expect(result.evaluationCount, 2);
      expect(result.bundleWarningCount, 0);
      expect(result.finalSummary.taskRuns, hasLength(1));
      expect(
        result.finalSummary.evaluationsByTaskRunId.values.single,
        hasLength(2),
      );
      expect(result.finalSummary.run.provenanceJson, isNotNull);

      final storedProvenance =
          jsonDecode(result.finalSummary.run.provenanceJson!)
              as Map<String, Object?>;
      final config = storedProvenance['config'] as Map<String, Object?>;
      final modelsByProvider =
          config['modelsByProvider'] as Map<String, Object?>;
      expect(modelsByProvider[provider.id], [provider.modelId]);
      final providerJson =
          (storedProvenance['providers'] as List<Object?>).single
              as Map<String, Object?>;
      expect(providerJson['id'], provider.id);
      expect(providerJson['mode'], 'rawApi');
      final taskJson =
          (storedProvenance['tasks'] as List<Object?>).single
              as Map<String, Object?>;
      expect(taskJson['id'], 'phase7.headless_smoke');
      expect(taskJson['track'], 'codegen');
      final comboJson =
          (storedProvenance['combos'] as List<Object?>).single
              as Map<String, Object?>;
      expect(comboJson['providerId'], provider.id);
      expect(comboJson['modelId'], provider.modelId);
      expect(comboJson['trialIndex'], 0);

      final expectedBundlePath = p.join(
        outputParent.path,
        runBundleDirectoryName('headless-smoke-run'),
      );
      expect(result.exportedBundleDirectory.path, expectedBundlePath);
      expect(Directory(expectedBundlePath).existsSync(), isTrue);

      final manifestFile = File(p.join(expectedBundlePath, 'manifest.json'));
      final runResultsFile = File(
        p.join(expectedBundlePath, 'run_results.v1.json'),
      );
      final csvFile = File(p.join(expectedBundlePath, 'results.csv'));
      final reportFile = File(p.join(expectedBundlePath, 'report.md'));
      final checksumsFile = File(p.join(expectedBundlePath, 'checksums.json'));
      expect(manifestFile.existsSync(), isTrue);
      expect(runResultsFile.existsSync(), isTrue);
      expect(csvFile.existsSync(), isTrue);
      expect(reportFile.existsSync(), isTrue);
      expect(checksumsFile.existsSync(), isTrue);

      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
      expect(manifest['provenance'], isNotNull);
      final warningCodes = (manifest['warnings'] as List<Object?>).map(
        (warning) => (warning as Map<String, Object?>)['code'],
      );
      expect(warningCodes, isNot(contains('missing_run_provenance')));
      expect((manifest['counts'] as Map<String, Object?>)['taskRunCount'], 1);
      expect(
        (manifest['counts'] as Map<String, Object?>)['evaluationCount'],
        2,
      );

      final artifacts = (manifest['artifacts'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final responseArtifact = artifacts.singleWhere(
        (artifact) => artifact['kind'] == 'response',
      );
      final responsePath = responseArtifact['path']! as String;
      expect(
        File(p.join(expectedBundlePath, responsePath)).existsSync(),
        isTrue,
      );

      final checksums =
          jsonDecode(checksumsFile.readAsStringSync()) as Map<String, Object?>;
      final checksumPaths = (checksums['files'] as List<Object?>).map(
        (file) => (file as Map<String, Object?>)['path'],
      );
      expect(checksumPaths, contains('manifest.json'));
      expect(checksumPaths, contains('run_results.v1.json'));
      expect(checksumPaths, contains('results.csv'));
      expect(checksumPaths, contains('report.md'));
      expect(checksumPaths, contains(responsePath));

      final csv = csvFile.readAsStringSync();
      final markdown = reportFile.readAsStringSync();
      final manifestText = manifestFile.readAsStringSync();
      expect(csv, isNot(contains(workdirRoot.path)));
      expect(markdown, isNot(contains(workdirRoot.path)));
      expect(manifestText, isNot(contains(workdirRoot.path)));
    },
  );

  test(
    'runs agentic headless smoke through a matching agent harness',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_agentic_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final provider = DeterministicFakeProvider();
      final harness = DeterministicFakeAgentHarness(
        harnessId: provider.id,
        modelId: provider.modelId,
      );

      final result = await const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-agentic-run',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
          tasks: [_AgenticHeadlessSmokeTask()],
          agentHarnesses: [harness],
        ),
      );

      expect(provider.disposed, isTrue);
      expect(harness.runCount, 1);
      expect(result.taskRunCount, 1);
      expect(result.evaluationCount, 3);
      final taskRun = result.finalSummary.taskRuns.single;
      expect(taskRun.benchmarkTrack, 'agentic');
      expect(taskRun.harnessId, provider.id);
      expect(taskRun.primaryPass, isTrue);
      expect(taskRun.patchText, contains('headlessAnswer'));
      expect(taskRun.patchText, contains('phase7'));
      final evaluations =
          result.finalSummary.evaluationsByTaskRunId[taskRun.id]!;
      expect(evaluations.map((e) => e.evaluatorId), contains('agent_harness'));
      expect(evaluations.every((e) => e.passed), isTrue);
      expect(result.bundleWarningCount, 0);
      expect(result.exportedBundleDirectory.existsSync(), isTrue);
    },
  );

  test(
    'agentic timeout without previews still exports response artifact',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_agentic_timeout_artifact_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final provider = DeterministicFakeProvider();
      final harness = _NoPreviewTimeoutAgentHarness(
        harnessId: provider.id,
        modelId: provider.modelId,
      );

      final result = await const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-agentic-timeout-artifact',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
          tasks: [_AgenticHeadlessSmokeTask()],
          agentHarnesses: [harness],
        ),
      );

      expect(result.taskRunCount, 1);
      expect(result.bundleWarningCount, 0);
      final taskRun = result.finalSummary.taskRuns.single;
      expect(taskRun.failureTag, 'harness_timeout');
      expect(taskRun.responseText, contains('no stdout/stderr preview'));
      expect(taskRun.patchText, contains('headlessAnswer'));

      final manifestPath = p.join(
        result.exportedBundleDirectory.path,
        'manifest.json',
      );
      final manifest =
          jsonDecode(File(manifestPath).readAsStringSync())
              as Map<String, Object?>;
      final warningCodes = (manifest['warnings'] as List<Object?>).map(
        (warning) => (warning as Map<String, Object?>)['code'],
      );
      expect(warningCodes, isNot(contains('missing_response_text')));
      expect(warningCodes, isNot(contains('missing_patch_text')));

      final artifacts = (manifest['artifacts'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final responseArtifact = artifacts.singleWhere(
        (artifact) => artifact['kind'] == 'response',
      );
      final patchArtifact = artifacts.singleWhere(
        (artifact) => artifact['kind'] == 'patch',
      );
      final responseText = File(
        p.join(
          result.exportedBundleDirectory.path,
          responseArtifact['path']! as String,
        ),
      ).readAsStringSync();
      expect(responseText, contains('status: timeout'));
      expect(patchArtifact['path'], contains('artifacts/patches/'));
    },
  );

  test(
    'agentic failure without previews exports response artifact and patch warning',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_agentic_failure_artifact_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final provider = DeterministicFakeProvider();
      final harness = _NoPreviewFailureAgentHarness(
        harnessId: provider.id,
        modelId: provider.modelId,
      );

      final result = await const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-agentic-failure-artifact',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
          tasks: [_AgenticHeadlessSmokeTask()],
          agentHarnesses: [harness],
        ),
      );

      expect(result.taskRunCount, 1);
      expect(result.bundleWarningCount, 1);
      final taskRun = result.finalSummary.taskRuns.single;
      expect(taskRun.failureTag, 'harness_error');
      expect(taskRun.responseText, contains('no stdout/stderr preview'));
      expect(taskRun.responseText, contains('status: failure'));
      expect(taskRun.responseText, contains('exitCode: 1'));
      expect(taskRun.patchText, isEmpty);

      final manifestPath = p.join(
        result.exportedBundleDirectory.path,
        'manifest.json',
      );
      final manifest =
          jsonDecode(File(manifestPath).readAsStringSync())
              as Map<String, Object?>;
      final warningCodes = (manifest['warnings'] as List<Object?>).map(
        (warning) => (warning as Map<String, Object?>)['code'],
      );
      expect(warningCodes, isNot(contains('missing_response_text')));
      expect(warningCodes, contains('missing_patch_text'));

      final artifacts = (manifest['artifacts'] as List<Object?>)
          .cast<Map<String, Object?>>();
      final responseArtifact = artifacts.singleWhere(
        (artifact) => artifact['kind'] == 'response',
      );
      expect(
        artifacts.where((artifact) => artifact['kind'] == 'patch'),
        isEmpty,
      );
      final responseText = File(
        p.join(
          result.exportedBundleDirectory.path,
          responseArtifact['path']! as String,
        ),
      ).readAsStringSync();
      expect(responseText, contains('status: failure'));

      final runResultsPath = p.join(
        result.exportedBundleDirectory.path,
        'run_results.v1.json',
      );
      final runResults =
          jsonDecode(File(runResultsPath).readAsStringSync())
              as Map<String, Object?>;
      final runResultsTaskRun =
          (runResults['taskRuns'] as List<Object?>).single
              as Map<String, Object?>;
      final harnessEvaluation =
          (runResultsTaskRun['evaluations']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .singleWhere(
                (evaluation) => evaluation['evaluatorId'] == 'agent_harness',
              );
      expect(harnessEvaluation['agentHarness'], {
        'status': 'failure',
        'exitCode': 1,
        'stdoutPreviewPresent': false,
        'stderrPreviewPresent': false,
        'trajectoryLogPresent': false,
      });
      expect(jsonEncode(runResults), isNot(contains('stdout_preview')));
      expect(jsonEncode(runResults), isNot(contains('stderr_preview')));
    },
  );

  test('failed combo surfaces an error and does not export a bundle', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_headless_fail_',
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    final runDao = RunDao(db);
    final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
      ..createSync(recursive: true);
    final outputParent = Directory(p.join(tmp.path, 'bundles'))
      ..createSync(recursive: true);
    final provider = FailingFakeProvider();
    final bundlePath = p.join(
      outputParent.path,
      runBundleDirectoryName('headless-failed-run'),
    );

    await expectLater(
      const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-failed-run',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
        ),
      ),
      throwsA(
        isA<StateError>()
            .having(
              (error) => error.message,
              'message',
              contains('Headless run failed'),
            )
            .having(
              (error) => error.message,
              'message',
              contains(provider.errorMessage),
            ),
      ),
    );

    expect(provider.disposed, isTrue);
    expect(Directory(bundlePath).existsSync(), isFalse);
    expect((await runDao.runById('headless-failed-run'))!.completedAt, isNull);
  });

  test(
    'timeout cancels slow provider without completing run or bundle',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_timeout_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      const runId = 'headless-timeout-run';
      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final provider = _SlowFakeProvider();
      final bundlePath = p.join(
        outputParent.path,
        runBundleDirectoryName(runId),
      );

      final runFuture = const HeadlessBenchmarkRunner().run(
        _config(
          runId: runId,
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
          timeout: const Duration(milliseconds: 40),
        ),
      );

      await provider.started.future.timeout(const Duration(seconds: 2));
      await expectLater(runFuture, throwsA(isA<TimeoutException>()));
      expect(provider.disposed, isTrue);

      await provider.completed.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final storedRun = await runDao.runById(runId);
      expect(storedRun, isNotNull);
      expect(storedRun!.completedAt, isNull);
      expect(Directory(bundlePath).existsSync(), isFalse);
    },
  );

  test(
    'timeout cancels prepare subprocess without completing run or bundle',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_headless_prepare_timeout_',
      );
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        if (await tmp.exists()) {
          await tmp.delete(recursive: true);
        }
      });

      const runId = 'headless-prepare-timeout-run';
      final runDao = RunDao(db);
      final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
        ..createSync(recursive: true);
      final outputParent = Directory(p.join(tmp.path, 'bundles'))
        ..createSync(recursive: true);
      final marker = File(p.join(tmp.path, 'prepare-marker.txt'));
      final fakeDart = await _writeHangingExecutable(tmp, marker);
      final provider = DeterministicFakeProvider();
      final bundlePath = p.join(
        outputParent.path,
        runBundleDirectoryName(runId),
      );

      final stopwatch = Stopwatch()..start();
      await expectLater(
        const HeadlessBenchmarkRunner().run(
          _config(
            runId: runId,
            runDao: runDao,
            workdirManager: WorkdirManager(
              root: workdirRoot,
              dartExecutable: fakeDart.path,
            ),
            outputParent: outputParent,
            allowedTrajectoryRoots: [workdirRoot],
            provider: provider,
            modelId: provider.modelId,
            timeout: const Duration(milliseconds: 160),
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(provider.disposed, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
      final storedRun = await runDao.runById(runId);
      expect(storedRun, isNotNull);
      expect(storedRun!.completedAt, isNull);
      expect(Directory(bundlePath).existsSync(), isFalse);
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('fake provider is deterministic without settings or API keys', () async {
    final provider = DeterministicFakeProvider();

    final models = await provider.listModels();
    final first = await provider.generate(
      prompt: 'ignored prompt',
      model: provider.modelId,
    );
    final second = await provider.generate(
      prompt: 'different ignored prompt',
      model: provider.modelId,
    );

    expect(models.single.id, provider.modelId);
    expect(first, second);
    expect(first.rawText, contains('headlessAnswer'));
    expect(first.promptTokens, 11);
    expect(first.completionTokens, 7);
  });

  test('existing output bundle directory is not overwritten', () async {
    final tmp = await Directory.systemTemp.createTemp(
      'dart_arena_headless_collision_',
    );
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    final runDao = RunDao(db);
    final workdirRoot = Directory(p.join(tmp.path, 'workdirs'))
      ..createSync(recursive: true);
    final outputParent = Directory(p.join(tmp.path, 'bundles'))
      ..createSync(recursive: true);
    final provider = DeterministicFakeProvider();
    final bundlePath = p.join(
      outputParent.path,
      runBundleDirectoryName('headless-collision-run'),
    );
    final sentinel = File(p.join(bundlePath, 'sentinel.txt'));
    await sentinel.parent.create(recursive: true);
    await sentinel.writeAsString('keep me');

    await expectLater(
      const HeadlessBenchmarkRunner().run(
        _config(
          runId: 'headless-collision-run',
          runDao: runDao,
          workdirManager: NoOpPrepareWorkdirManager(root: workdirRoot),
          outputParent: outputParent,
          allowedTrajectoryRoots: [workdirRoot],
          provider: provider,
          modelId: provider.modelId,
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(provider.disposed, isTrue);
    expect(sentinel.readAsStringSync(), 'keep me');
  });

  test('exposes the standalone dart run CLI entrypoint', () {
    expect(File('bin/dart_arena_headless.dart').existsSync(), isTrue);
  });
}

HeadlessBenchmarkConfig _config({
  required String runId,
  required RunDao runDao,
  required WorkdirManager workdirManager,
  required Directory outputParent,
  required List<Directory> allowedTrajectoryRoots,
  required ModelProvider provider,
  required String modelId,
  List<BenchmarkTask>? tasks,
  List<AgentHarness> agentHarnesses = const [],
  Duration timeout = const Duration(seconds: 5),
}) {
  return HeadlessBenchmarkConfig(
    runId: runId,
    name: 'Phase 7 headless smoke',
    tasks: tasks ?? [_HeadlessSmokeTask()],
    providers: [provider],
    modelsByProvider: {
      provider.id: [modelId],
    },
    agentHarnesses: agentHarnesses,
    evaluatorConfig: const EvaluatorConfig(),
    evaluatorWeights: _weights,
    workdirManager: workdirManager,
    runDao: runDao,
    bundleOutputParent: outputParent,
    now: () => DateTime.utc(2026, 5, 30, 12),
    idGenerator: () => runId,
    provenanceEnvironmentProvider:
        const FixedRunProvenanceEnvironmentProvider(),
    exportEnvironmentProvider: () async => const {
      'hostPlatform': 'test-os',
      'dartVersion': 'test-dart',
      'flutterVersion': 'test-flutter',
      'gitCommit': 'test-git',
      'gitDirty': false,
    },
    exportAppVersionProvider: () async => '1.0.0+headless-test',
    allowedTrajectoryRoots: allowedTrajectoryRoots,
    maxConcurrency: 1,
    trialsPerTask: 1,
    timeout: timeout,
  );
}

Future<File> _writeHangingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_dart.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20
echo done >> '${marker.path}'
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
