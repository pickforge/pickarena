import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class GodWidgetTask extends BenchmarkTask {
  static const _root = 'lib/tasks/refactor/fixtures/god_widget';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/god_widget.dart',
      'test/god_widget_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'refactor.god_widget';

  @override
  Category get category => Category.refactor;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given `lib/god_widget.dart`, a stateful Flutter `GodWidget` that mixes UI, business logic, and state in one large class. Refactor it within the same file into smaller, focused widgets and pure helper functions/classes. Tests in `test/god_widget_test.dart` must continue to pass.

Constraints:
- Public API: only `GodWidget` (StatefulWidget) and `TodoEntry` are publicly observed externally.
- Behavior must be preserved exactly. Do not add or remove user-visible behavior.
- Output must be a single Dart file replacing `lib/god_widget.dart`.

Return ONLY the refactored contents of `lib/god_widget.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/god_widget.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted refactor on a 0.0-1.0 scale on these axes:
- Behavior preservation (most important): the public API of `GodWidget` and `TodoEntry` is unchanged and tests still pass.
- Separation of concerns: extracted smaller widgets (e.g., input row, filter/sort row, list, status footer) and pure helpers.
- No leakage: helper widgets and types are private (underscore-prefixed) where appropriate.
- Naming and readability; absence of dead code; idiomatic Flutter.
Return ONE composite score and a 1-2 sentence rationale.
''';

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
    DiffSizeEvaluator(originalFixturePath: 'lib/god_widget.dart'),
  ];
}
