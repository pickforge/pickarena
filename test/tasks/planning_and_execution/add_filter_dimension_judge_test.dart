import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/tasks/planning_and_execution/add_filter_dimension.dart';
import 'package:flutter_test/flutter_test.dart';

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
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late AddFilterDimensionTask task;

  setUp(() {
    task = AddFilterDimensionTask();
  });

  test('judgeRubric is null before ensureLoaded', () {
    expect(task.judgeRubric, isNull);
  });

  test('judgeRubric is non-null after ensureLoaded and contains expected content',
      () async {
    await task.ensureLoaded();

    final rubric = task.judgeRubric;
    expect(rubric, isNotNull);
    expect(rubric, contains('REFERENCE PLAN (canonical solution)'));
    expect(rubric, contains('CategoryFilter'));
    expect(rubric, contains('matches'));
    expect(rubric,
        contains('Return ONE composite score and a 1-2 sentence rationale'));
  });

  test('evaluatorsFor without judge returns compile, analyze, test', () {
    final evs = task.evaluatorsFor(const EvaluatorConfig());
    final ids = evs.map((e) => e.id).toList();
    expect(ids, ['compile', 'analyze', 'test']);
  });

  test('evaluatorsFor with judge includes llm_judge and is LlmJudgeEvaluator',
      () {
    final config = EvaluatorConfig(
      judgeProvider: _FakeJudge(),
      judgeModel: 'fj',
    );
    final evs = task.evaluatorsFor(config);
    final ids = evs.map((e) => e.id).toList();
    expect(ids, ['compile', 'analyze', 'test', 'llm_judge']);
    expect(evs.last, isA<LlmJudgeEvaluator>());
  });
}
