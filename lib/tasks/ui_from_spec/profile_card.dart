import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/fixture_loader.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/diff_size_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/llm_judge_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';

class ProfileCardTask extends BenchmarkTask {
  static const _root = 'lib/tasks/ui_from_spec/fixtures/profile_card';
  static final _loader = FixtureLoader(
    assetRoot: _root,
    files: const [
      'pubspec.yaml',
      'lib/profile_card.dart',
      'test/profile_card_test.dart',
    ],
  );
  static final _hiddenLoader = FixtureLoader(
    assetRoot: _root,
    files: const ['test/_hidden/profile_card_hidden_test.dart'],
  );
  static final _referenceLoader = FixtureLoader(
    assetRoot: _root,
    files: const ['reference/lib/profile_card.dart'],
  );

  Map<String, String> _fixtures = const {};
  Map<String, String> _hiddenVerifierFiles = const {};
  Map<String, String> _referenceFiles = const {};

  @override
  String get id => 'ui.profile_card';

  @override
  int get version => 2;

  @override
  Category get category => Category.uiFromSpec;

  @override
  bool get isFlutter => true;

  @override
  String get prompt => '''
You are given a `ProfileCard` widget skeleton in `lib/profile_card.dart`. Build a stateless Material widget matching this spec:

- Layout: a `Card` with horizontal `Row`. Leading `CircleAvatar` (uses `avatarUrl` when provided, else shows the first letter of `name`). Center column with `name`, `handle`, and optional `bio`. Trailing `ElevatedButton` showing 'Follow' when `isFollowing == false`, 'Following' otherwise; pressing fires `onFollowPressed`.
- Accessibility: wrap the card in `Semantics(label: "<name> <handle>", ...)`.
- Do NOT change the public API (constructor parameters and types).

Visible tests in `test/profile_card_test.dart` cover basic smoke behavior. Additional grading checks verify the full contract.

Return ONLY the corrected contents of `lib/profile_card.dart` inside a single ```dart fenced block.
Do not include explanatory text outside the block.
''';

  @override
  Map<String, String> get fixtures => _fixtures;

  @override
  Future<void> ensureLoaded() async {
    if (_fixtures.isNotEmpty) return;
    _fixtures = await _loader.load();
    _hiddenVerifierFiles = await _hiddenLoader.load();
    _referenceFiles = await _referenceLoader.load();
  }

  @override
  String get generatedCodePath => 'lib/profile_card.dart';

  @override
  List<VerifierFixture> get hiddenVerifiers => _hiddenVerifierFiles.isEmpty
      ? const []
      : [
          VerifierFixture(
            files: _hiddenVerifierFiles,
            testPath: 'test/_hidden/profile_card_hidden_test.dart',
          ),
        ];

  @override
  ReferenceSolution? get referenceSolution {
    final reference = _referenceFiles['reference/lib/profile_card.dart'];
    if (reference == null) return null;
    return ReferenceFileSolution({'lib/profile_card.dart': reference});
  }

  @override
  String? get judgeRubric => '''
Rate the submitted ProfileCard on a 0.0-1.0 scale on these axes:
- Spec coverage point-by-point (avatar, name, handle, optional bio, follow button text/state, callback).
- Idiomatic Flutter composition and use of Material widgets.
- Accessibility (Semantics label, sensible widget tree for screen readers).
- Minimal, readable code with no extraneous decoration.
Return ONE composite score and a 1-2 sentence rationale.
''';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [
    CompileEvaluator(),
    AnalyzeEvaluator(),
    TestEvaluator(),
    ...hiddenVerifiers.map(HiddenTestEvaluator.new),
    if (config.hasJudge)
      LlmJudgeEvaluator(
        judge: config.judgeProvider!,
        judgeModel: config.judgeModel!,
      ),
    DiffSizeEvaluator(originalFixturePath: 'lib/profile_card.dart'),
  ];
}
