import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/core/plan_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class AddEvaluatorTypeTask extends BenchmarkTask {
  static const _root =
      'lib/tasks/planning_and_execution/fixtures/add_evaluator_type';
  static const _planAsset =
      'lib/tasks/planning_and_execution/plans/add_evaluator_type.v1.md';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/evaluator.dart',
      'test/coverage_evaluator_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};
  ReferencePlan? _plan;

  @override
  String get id => 'planning_and_execution.add_evaluator_type';

  @override
  Category get category => Category.planningAndExecution;

  @override
  bool get isFlutter => false;

  @override
  bool get hasReferencePlan => true;

  @override
  String get prompt => '''
You are given a small Dart package that defines an `Evaluator` interface in `lib/evaluator.dart` and an acceptance test in `test/coverage_evaluator_test.dart`.

Create `lib/coverage_evaluator.dart` containing a class `CoverageEvaluator` that implements `Evaluator`. The class must:

- Have `id` returning the string `'coverage'`.
- Implement `evaluate(EvaluationContext ctx)` returning an `EvaluationResult` with `id: 'coverage'` and a `score` in `[0, 1]`.

The provided acceptance test must pass.

Return ONLY the contents of `lib/coverage_evaluator.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isEmpty) {
      _fixtures = await _loader.load();
    }
    _plan ??= await PlanLoader.load(assetPath: _planAsset, version: 1);
  }

  @override
  String get generatedCodePath => 'lib/coverage_evaluator.dart';

  @override
  String? get judgeRubric {
    final plan = _plan;
    if (plan == null) return null;
    return '''
Rate the submission on a 0.0-1.0 scale on plan-adherence and quality:
- Did the implementation follow the canonical approach in the REFERENCE PLAN below? (most important)
- Are the public API, file structure, and step ordering consistent with the plan?
- Is the code idiomatic Dart, minimal, and free of dead code?
- Give high credit to equivalent concise implementations that satisfy the same API and plan intent; do not require exact wording, comments, or formatting.

Note: the model may or may not have seen this plan as input. Score on whether the code matches the canonical approach, not on whether the plan was visible.

REFERENCE PLAN (canonical solution):
${plan.markdown}

Return ONE composite score and a 1-2 sentence rationale.
''';
  }

  @override
  ReferencePlan? get referencePlan => _plan;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    CompileEvaluator(),
    AnalyzeEvaluator(),
    TestEvaluator(),
    if (config.hasJudge)
      LlmJudgeEvaluator(
        judge: config.judgeProvider!,
        judgeModel: config.judgeModel!,
      ),
  ];
}
