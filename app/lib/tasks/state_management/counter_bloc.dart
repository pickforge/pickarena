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

class CounterBlocTask extends BenchmarkTask {
  static const _root = 'lib/tasks/state_management/fixtures/counter_bloc';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/counter_bloc.dart',
      'test/counter_bloc_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'state.counter_bloc';

  @override
  Category get category => Category.stateManagement;

  @override
  bool get isFlutter => false;

  @override
  String get prompt => '''
You are given a `CounterBloc` skeleton in `lib/counter_bloc.dart`. Tests in `test/counter_bloc_test.dart` define the required behavior:
- `Increment` increases the state by 1.
- `Decrement` decreases the state by 1 but never below 0; if state is already 0, no new state is emitted.
- `Reset` sets the state back to 0.

Return ONLY the corrected contents of `lib/counter_bloc.dart` inside a single ```dart fenced block.
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
  String get generatedCodePath => 'lib/counter_bloc.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted CounterBloc on a 0.0-1.0 scale on these axes:
- Correct event handler registration for Increment, Decrement, Reset (most important).
- Proper enforcement of the non-negative invariant on Decrement, with no emission when state is already 0.
- Idiomatic Dart and bloc usage (use of `on<Event>`, no superfluous logic).
- Minimal, readable code; no dead branches.
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
    DiffSizeEvaluator(originalFixturePath: 'lib/counter_bloc.dart'),
  ];
}
