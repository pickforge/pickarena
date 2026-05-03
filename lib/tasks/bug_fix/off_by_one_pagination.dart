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

class OffByOnePaginationTask extends BenchmarkTask {
  static const _root = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/pagination.dart',
      'test/pagination_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'bug.off_by_one_pagination';

  @override
  Category get category => Category.bugFix;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a Dart class `Paginator<T>` in `lib/pagination.dart` that has off-by-one bugs.
There are tests in `test/pagination_test.dart` that currently fail.

Return ONLY the corrected contents of `lib/pagination.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block. Do not change the public API.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/pagination.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted Paginator implementation on a 0.0-1.0 scale on these axes:
- Correctness of pageCount and page() boundaries (most important).
- Idiomatic Dart (use of generics, avoiding off-by-one re-introductions).
- Minimal, surgical change vs. the broken original.
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
        DiffSizeEvaluator(originalFixturePath: 'lib/pagination.dart'),
      ];
}
