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

class ExpandableListTileTask extends BenchmarkTask {
  static const _root = 'lib/tasks/ui_from_spec/fixtures/expandable_list_tile';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/expandable_list_tile.dart',
      'test/expandable_list_tile_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'ui.expandable_list_tile';

  @override
  Category get category => Category.uiFromSpec;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a stateful `ExpandableListTile` widget skeleton. Build a widget matching this spec:

- Always shows `title` plus a trailing chevron icon (Icons.keyboard_arrow_down).
- Tapping the title row toggles expansion.
- Chevron rotates 180 degrees on expand, using a `RotationTransition` driven by an `AnimationController` (~200ms).
- When expanded, `details` is displayed below the title row.
- Calls `onExpansionChanged` with the new value whenever expanded state flips.
- `initiallyExpanded` controls the initial value; default false.

Tests in `test/expandable_list_tile_test.dart` enforce this. Do not change the public API.

Return ONLY the corrected contents of `lib/expandable_list_tile.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'lib/expandable_list_tile.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted ExpandableListTile on a 0.0-1.0 scale on these axes:
- Correct stateful behavior: initial state, toggle on tap, callback firing with right value.
- Use of RotationTransition + AnimationController, with proper dispose in dispose().
- Idiomatic widget composition; no unnecessary widgets.
- Minimal, readable code.
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
        DiffSizeEvaluator(originalFixturePath: 'lib/expandable_list_tile.dart'),
      ];
}
