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

class AsyncRaceConditionTask extends BenchmarkTask {
  static const _root = 'lib/tasks/bug_fix/fixtures/async_race_condition';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/search_controller.dart',
      'test/search_controller_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'bug.async_race_condition';

  @override
  Category get category => Category.bugFix;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given `lib/search_controller.dart` containing `SearchController.onQueryChanged(String query)`. There is a race condition: rapid query changes can cause stale results to overwrite fresh ones. Failing tests in `test/search_controller_test.dart` (using `fake_async`) demonstrate the bug.

Fix the controller so only the latest query's results are emitted. Constraints:
- Preserve the public API (constructor, `results` stream, `onQueryChanged`, `dispose`).
- Keep the stream-based control flow.
- No busy-waiting or polling.

Return ONLY the corrected contents of `lib/search_controller.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/search_controller.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted SearchController fix on a 0.0-1.0 scale on these axes:
- Correctness of the fix (most important): only the latest query's results are emitted in all overlap scenarios.
- Minimal, surgical change vs. the broken original.
- Idiomatic cancellation/generation pattern; no busy-waiting; no polling.
- Readability and absence of dead code.
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
    DiffSizeEvaluator(originalFixturePath: 'lib/search_controller.dart'),
  ];
}
