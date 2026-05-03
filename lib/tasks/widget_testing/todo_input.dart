import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_author_evaluator.dart';

class TodoInputTestTask extends BenchmarkTask {
  static const _root = 'lib/tasks/widget_testing/fixtures/todo_input';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/todo_input.dart',
      'test/_reference/todo_input_reference_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'test.todo_input';

  @override
  Category get category => Category.widgetTesting;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a working `TodoInput` widget in `lib/todo_input.dart`. Write a widget-test suite at `test/todo_input_test.dart` covering this behavior:

- Submit button is disabled when the input is empty (or only whitespace).
- Typing non-empty text enables the Submit button.
- Tapping Submit calls `onSubmit` with the trimmed value and clears the text field.
- `maxLength` is respected (the underlying TextField uses it).
- Pressing Enter (`onSubmitted`) submits the same way as tapping Submit.

Use `flutter_test` and `MaterialApp(home: Scaffold(body: ...))` to host the widget. DO NOT modify `lib/todo_input.dart`.

Return ONLY the contents of `test/todo_input_test.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'test/todo_input_test.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted widget-test suite on a 0.0-1.0 scale on these axes:
- Coverage of each spec bullet (empty/whitespace disable, non-empty enable, submit fires + clears, maxLength, Enter submit).
- Correct use of `pumpWidget`, `enterText`, `tap`, and finders; no flaky patterns (e.g., relying on undefined ordering).
- Tests are self-contained, well-named, and isolated.
- No unjustified `pumpAndSettle` loops or sleeps.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestAuthorEvaluator(
          testPath: 'test/todo_input_test.dart',
          mutants: const [
            TestMutant(
              name: 'submit_always_enabled',
              sourcePath: 'lib/todo_input.dart',
              find: 'onPressed: canSubmit ? _submit : null',
              replace: 'onPressed: _submit',
            ),
            TestMutant(
              name: 'does_not_clear_after_submit',
              sourcePath: 'lib/todo_input.dart',
              find: '_controller.clear();',
              replace: '// _controller.clear();',
            ),
            TestMutant(
              name: 'does_not_trim_submission',
              sourcePath: 'lib/todo_input.dart',
              find: 'final text = _controller.text.trim();',
              replace: 'final text = _controller.text;',
            ),
            TestMutant(
              name: 'enter_key_does_not_submit',
              sourcePath: 'lib/todo_input.dart',
              find: 'onSubmitted: (_) => _submit(),',
              replace: 'onSubmitted: null,',
            ),
          ],
        ),
        if (config.hasJudge)
          LlmJudgeEvaluator(
            judge: config.judgeProvider!,
            judgeModel: config.judgeModel!,
          ),
      ];
}
