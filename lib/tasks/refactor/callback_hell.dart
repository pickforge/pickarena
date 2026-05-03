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

class CallbackHellTask extends BenchmarkTask {
  static const _root = 'lib/tasks/refactor/fixtures/callback_hell';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/data_pipeline.dart',
      'test/data_pipeline_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'refactor.callback_hell';

  @override
  Category get category => Category.refactor;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given `lib/data_pipeline.dart` containing a `DataPipeline.run()` method whose body is a deeply nested `.then` chain. Refactor `run()` to use `async`/`await` while:

- Preserving the public API (signatures of `DataPipeline`, its constructor, and the `PipelineRecord` class).
- Preserving observable behavior: ordering of fetcher calls, the empty-orders short-circuit (no call to `fetchOrderTotal`), and error propagation.

Return ONLY the refactored contents of `lib/data_pipeline.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/data_pipeline.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted refactor on a 0.0-1.0 scale on these axes:
- Use of `async`/`await` throughout `run()`, no remaining `.then` chains.
- Preservation of behavior: ordering, empty-orders short-circuit, error propagation.
- Idiomatic Dart, minimal/readable code.
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
        DiffSizeEvaluator(originalFixturePath: 'lib/data_pipeline.dart'),
      ];
}
