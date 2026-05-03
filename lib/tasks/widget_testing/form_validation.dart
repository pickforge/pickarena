import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_author_evaluator.dart';

class FormValidationTestTask extends BenchmarkTask {
  static const _root = 'lib/tasks/widget_testing/fixtures/form_validation';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/signup_form.dart',
      'test/_reference/signup_form_reference_test.dart',
    ],
  );

  Map<String, String> _fixtures = const {};

  @override
  String get id => 'test.form_validation';

  @override
  Category get category => Category.widgetTesting;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a working `SignupForm` in `lib/signup_form.dart`. Write a widget-test suite at `test/signup_form_test.dart` covering:

- Submit button is disabled until both email and password are valid.
- Invalid email shows "Enter a valid email" error message.
- Empty email shows "Email is required" error message.
- Empty password shows "Password is required" error message.
- Password shorter than 8 characters shows "Password must be at least 8 characters".
- Tapping Submit with valid inputs calls `onSubmit` with the trimmed email and the password.

DO NOT modify `lib/signup_form.dart`. Use `Key('email')`, `Key('password')`, `Key('submit')` for finders.

Return ONLY the contents of `test/signup_form_test.dart` inside a single ```dart fenced block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
  }

  @override
  String get generatedCodePath => 'test/signup_form_test.dart';

  @override
  String? get judgeRubric => '''
Rate the submitted widget-test suite on a 0.0-1.0 scale on these axes:
- Coverage of each spec bullet (each error message, each disabled/enabled transition, the valid submit path).
- Correct use of `Form`, `TextFormField`, finders by Key, and `enterText` + `pump`.
- Tests are independent and self-contained.
- No flakiness patterns.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
        CompileEvaluator(),
        AnalyzeEvaluator(),
        TestAuthorEvaluator(
          testPath: 'test/signup_form_test.dart',
          mutants: const [
            TestMutant(
              name: 'invalid_email_allowed',
              sourcePath: 'lib/signup_form.dart',
              find: "if (!pattern.hasMatch(value.trim())) return 'Enter a valid email';",
              replace: "if (false) return 'Enter a valid email';",
            ),
            TestMutant(
              name: 'short_password_allowed',
              sourcePath: 'lib/signup_form.dart',
              find: "if (value.length < 8) return 'Password must be at least 8 characters';",
              replace: "if (false) return 'Password must be at least 8 characters';",
            ),
            TestMutant(
              name: 'submit_always_enabled',
              sourcePath: 'lib/signup_form.dart',
              find: 'onPressed: _valid ? _submit : null,',
              replace: 'onPressed: _submit,',
            ),
            TestMutant(
              name: 'email_not_trimmed_on_submit',
              sourcePath: 'lib/signup_form.dart',
              find: 'email: _emailCtrl.text.trim(),',
              replace: 'email: _emailCtrl.text,',
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
