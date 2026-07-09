import 'dart:io';

import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/tasks/file_backed/file_backed_task.dart';
import 'package:test/test.dart';

import '../../support/file_backed_bundle_fixture.dart';

class _FakeJudge with Disposable implements ModelProvider {
  @override
  String get id => 'fake_judge';
  @override
  String get displayName => 'Fake Judge';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => [const ModelInfo(id: 'fj')];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async =>
      throw UnimplementedError('judge should not be called in these tests');
}

void main() {
  late Directory root;
  late FileBackedTask task;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('file_backed_rubric_');
    final bundle = await writeAnswerFileBackedBundle(
      root,
      id: 'planning.add_evaluator_type',
      judgeRubricPath: 'rubrics/add_evaluator_type.md',
      judgeRubricText: '''
REFERENCE PLAN (canonical solution):
Create CoverageEvaluator implementing Evaluator.
Return ONE composite score and a 1-2 sentence rationale.
''',
    );
    task = await FileBackedTask.load(bundle);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('judgeRubricPath loads rubric text from the bundle filesystem', () {
    final rubric = task.judgeRubric;

    expect(rubric, isNotNull);
    expect(rubric, contains('REFERENCE PLAN (canonical solution)'));
    expect(rubric, contains('CoverageEvaluator'));
    expect(rubric, contains('Evaluator'));
    expect(
      rubric,
      contains('Return ONE composite score and a 1-2 sentence rationale'),
    );
  });

  test('evaluatorsFor without judge omits llm_judge', () async {
    await task.ensureLoaded();

    final ids = task
        .evaluatorsFor(const EvaluatorConfig())
        .map((e) => e.id)
        .toList();

    expect(ids, [
      'compile',
      'analyze',
      'test',
      task.hiddenVerifiers.single.id,
      'diff_size',
    ]);
  });

  test('evaluatorsFor with judge includes llm_judge evaluator', () async {
    await task.ensureLoaded();
    final config = EvaluatorConfig(
      judgeProvider: _FakeJudge(),
      judgeModel: 'fj',
    );

    final evs = task.evaluatorsFor(config);

    expect(evs.map((e) => e.id), contains('llm_judge'));
    expect(evs.whereType<LlmJudgeEvaluator>(), hasLength(1));
  });
}
