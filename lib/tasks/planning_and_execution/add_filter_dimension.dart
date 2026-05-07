import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/core/plan_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class AddFilterDimensionTask extends BenchmarkTask {
  static const _root =
      'lib/tasks/planning_and_execution/fixtures/add_filter_dimension';
  static const _planAsset =
      'lib/tasks/planning_and_execution/plans/add_filter_dimension.v1.md';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/filter.dart',
      'test/category_filter_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};
  ReferencePlan? _plan;

  @override
  String get id => 'planning_and_execution.add_filter_dimension';

  @override
  Category get category => Category.planningAndExecution;

  @override
  bool get isFlutter => false;

  @override
  bool get hasReferencePlan => true;

  @override
  String get prompt => '''
You are given a small Dart package that defines `Filter` and `Item` types in `lib/filter.dart` and an acceptance test in `test/category_filter_test.dart`.

Create `lib/category_filter.dart` containing a class `CategoryFilter` that implements `Filter`. The constructor takes a single named argument `category` of type `String`. The `matches(Item)` method must:

- Return `true` for any item if the filter's `category` is empty.
- Otherwise return `true` iff `item.category == filter.category`.

The provided acceptance test must pass.

Return ONLY the contents of `lib/category_filter.dart` inside a single ```dart fenced block.
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
  String get generatedCodePath => 'lib/category_filter.dart';

  @override
  String? get judgeRubric => null;

  @override
  ReferencePlan? get referencePlan => _plan;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    CompileEvaluator(),
    AnalyzeEvaluator(),
    TestEvaluator(),
  ];
}
