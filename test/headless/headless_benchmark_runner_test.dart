import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/export/artifact_bundle.dart';
import 'package:dart_arena/headless/headless_benchmark_runner.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('does not add a standalone dart run CLI in Phase 7', () {
    final cliEntrypoints = [
      File('bin/dart_arena_headless.dart'),
      File('bin/headless_benchmark_runner.dart'),
    ];
    for (final cliEntrypoint in cliEntrypoints) {
      expect(
        cliEntrypoint.existsSync(),
        isFalse,
        reason:
            'Phase 7 validates the reusable headless service through '
            'flutter test until Flutter plugin imports are split out.',
      );
    }
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
}) {
  return HeadlessBenchmarkConfig(
    runId: runId,
    name: 'Phase 7 headless smoke',
    tasks: [_HeadlessSmokeTask()],
    providers: [provider],
    modelsByProvider: {
      provider.id: [modelId],
    },
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
    timeout: const Duration(seconds: 5),
  );
}
