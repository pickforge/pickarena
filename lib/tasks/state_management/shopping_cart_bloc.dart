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

class ShoppingCartBlocTask extends BenchmarkTask {
  static const _root = 'lib/tasks/state_management/fixtures/shopping_cart_bloc';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/cart_bloc.dart',
      'test/cart_bloc_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'state.shopping_cart_bloc';

  @override
  Category get category => Category.stateManagement;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a `CartBloc` skeleton in `lib/cart_bloc.dart` along with `CartLine`, `CartState`, and the `CartEvent` family. Tests in `test/cart_bloc_test.dart` define the required behavior:
- `AddItem` with a new id appends a new line; with an existing id, increments that line's quantity (no duplicate lines).
- `RemoveItem` removes the matching line; no-op if absent (no state emission).
- `UpdateQuantity` sets the line's quantity; quantity <= 0 removes the line.
- State exposes `lines`, `itemCount`, `subtotalCents` consistently.

Return ONLY the corrected contents of `lib/cart_bloc.dart` inside a single ```dart fenced block.
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
  String get generatedCodePath => 'lib/cart_bloc.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted CartBloc on a 0.0-1.0 scale on these axes:
- Correctness across all event handlers (most important).
- Edge case handling: duplicate adds merge; quantity 0 removes; absent ids on RemoveItem/UpdateQuantity do not emit.
- Immutability of state (no in-place mutation of `state.lines`).
- Idiomatic Dart, no superfluous logic.
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
        DiffSizeEvaluator(originalFixturePath: 'lib/cart_bloc.dart'),
      ];
}
