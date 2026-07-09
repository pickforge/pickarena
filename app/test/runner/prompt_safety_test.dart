import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_workspace.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/runner/prompt_safety.dart';
import 'package:test/test.dart';

const _hiddenAssertion =
    "expect(controller.submittedEmail, 'user.name+tag@example.com');";
const _referenceSnippet = 'int answer() => 42;';
const _shortPrivateBlock = '''
int answer() {
  return 42;
}
''';
const _genericTwoLineBlock = '''
if (mounted) {
}
''';

void main() {
  group('prompt safety leak scanner', () {
    test('flags hidden paths with path prefixes', () {
      final task = _GenericHiddenFileNameTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak('test/_hidden/main.dart', task),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          './test/_hidden/main.dart',
          task,
        ),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'pkg/test/_hidden/main.dart',
          task,
        ),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'file:///tmp/pkg/test/_hidden/main.dart',
          task,
        ),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak('mytest_hidden/main.dart', task),
        isFalse,
      );
    });

    test('flags hidden directory markers', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak('hidden_tests/', task),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak('hidden_tests', task),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          '_hidden/main.dart',
          _GenericHiddenFileNameTask(),
        ),
        isTrue,
      );
    });

    test('flags hidden verifier identifiers and extensionless stems', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'rerun answer_behavior_hidden',
          task,
        ),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'see `answer_hidden_test`',
          task,
        ),
        isTrue,
      );
    });

    test('flags negative-case and reference paths', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'negative_cases/noop/lib/answer.dart',
          task,
        ),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak('solution/lib/answer.dart', task),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'custom_cases/noop_variant/lib/answer.dart',
          _CustomNegativeRootTask(),
        ),
        isTrue,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'custom_cases/noop_variant/',
          _CustomNegativeRootTask(),
        ),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak(
          'golden_reference/lib/answer.dart',
          _CustomReferenceRootTask(),
        ),
        isTrue,
      );
    });

    test('flags bare reference roots', () {
      expect(
        containsReferencePromptSafetyLeak(
          'look under solution/',
          _SolutionRootReferenceTask(),
        ),
        isTrue,
      );
    });

    test('ignores prose reference root words without slash', () {
      expect(
        containsReferencePromptSafetyLeak(
          'the solution should be simple',
          _SolutionRootReferenceTask(),
        ),
        isFalse,
      );
    });

    test('flags distinctive hidden and reference snippets', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(_hiddenAssertion, task),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak(_referenceSnippet, task),
        isTrue,
      );
    });

    test('flags short multi-line private blocks', () {
      final task = _ShortLinePrivateBlockTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(_shortPrivateBlock, task),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak(_shortPrivateBlock, task),
        isTrue,
      );
    });

    test('flags leaks in workspace instructions', () {
      final task = _WorkspaceInstructionLeakTask();
      final visibleContext = buildPromptSafetyVisibleContext(task: task);

      expect(
        scanPromptSafetyLeaks(
          visiblePromptContext: visibleContext,
          task: task,
        ).hiddenVerifierLeak,
        isTrue,
      );
    });

    test('flags leaks in reference plans', () {
      final task = _ReferencePlanLeakTask();
      final visibleContext = buildPromptSafetyVisibleContext(task: task);

      expect(
        scanPromptSafetyLeaks(
          visiblePromptContext: visibleContext,
          task: task,
        ).referenceLeak,
        isTrue,
      );
    });

    test('flags raw authored hidden verifier IDs', () {
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'edge_cases',
          _RawAuthoredHiddenIdTask(),
        ),
        isTrue,
      );
    });

    test('flags case-variant distinctive snippets', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(
          "Expect(controller.submittedEmail, 'user.name+tag@example.com');",
          task,
        ),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak('INT ANSWER() => 42;', task),
        isTrue,
      );
    });

    test('flags spacing-variant distinctive snippets', () {
      final task = _PromptSafetyTask();

      expect(
        containsHiddenVerifierPromptSafetyLeak(
          "expect( controller.submittedEmail , 'user.name+tag@example.com' );",
          task,
        ),
        isTrue,
      );
      expect(
        containsReferencePromptSafetyLeak('int answer ( ) => 42 ;', task),
        isTrue,
      );
    });

    test('ignores generic filenames, public snippets, and short IDs', () {
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          'Open main.dart and change the widget.',
          _GenericHiddenFileNameTask(),
        ),
        isFalse,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          _hiddenAssertion,
          _PublicHiddenSnippetTask(),
        ),
        isFalse,
      );
      expect(
        containsReferencePromptSafetyLeak(
          _referenceSnippet,
          _PublicReferenceSnippetTask(),
        ),
        isFalse,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak('shortid', _ShortIdTask()),
        isFalse,
      );
      expect(
        containsHiddenVerifierPromptSafetyLeak(
          _genericTwoLineBlock,
          _PublicGenericTwoLineBlockTask(),
        ),
        isFalse,
      );
      expect(
        containsReferencePromptSafetyLeak(
          _genericTwoLineBlock,
          _PublicGenericTwoLineBlockTask(),
        ),
        isFalse,
      );
    });
  });
}

class _PromptSafetyTask extends BenchmarkTask {
  @override
  String get id => 'prompt_safety';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'Fix answer().';

  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': 'name: prompt_safety\n',
    'lib/answer.dart': 'int answer() => 41;\n',
    'test/answer_test.dart': 'void main() {}\n',
  };

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'answer_behavior_hidden',
      testPath: 'test/_hidden/answer_hidden_test.dart',
      files: {
        'test/_hidden/answer_hidden_test.dart': '''
void main() {
  test('submitted email is preserved', () {
    expect(controller.submittedEmail, 'user.name+tag@example.com');
  });
}
''',
      },
    ),
  ];

  @override
  ReferenceSolution? get referenceSolution =>
      const ReferenceFileSolution({'lib/answer.dart': 'int answer() => 42;\n'});

  @override
  List<TaskNegativeCase> get negativeCases => const [
    TaskNegativeCase(
      id: 'noop',
      description: 'Leaves behavior unchanged.',
      kind: TaskNegativeCaseKind.noop,
      solution: ReferenceFileSolution({
        'lib/answer.dart': 'int answer() => 41;\n',
      }),
    ),
  ];

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

class _GenericHiddenFileNameTask extends _PromptSafetyTask {
  @override
  Map<String, String> get fixtures => {
    ...super.fixtures,
    'lib/main.dart': 'void main() {}\n',
  };

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'main_file_hidden',
      testPath: 'test/_hidden/main.dart',
      files: {'test/_hidden/main.dart': 'void hiddenMain() {}\n'},
    ),
  ];
}

class _ShortLinePrivateBlockTask extends _PromptSafetyTask {
  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'short_block_hidden',
      testPath: 'test/_hidden/short_block_test.dart',
      files: {'test/_hidden/short_block_test.dart': _shortPrivateBlock},
    ),
  ];

  @override
  ReferenceSolution? get referenceSolution =>
      const ReferenceFileSolution({'lib/answer.dart': _shortPrivateBlock});
}

class _WorkspaceInstructionLeakTask extends _PromptSafetyTask {
  @override
  TaskWorkspace get workspace => TaskWorkspace.fromFixtures(
    fixtures,
    instruction:
        'Fix answer(). The workspace hint mentions answer_hidden_test.dart.',
  );
}

class _CustomNegativeRootTask extends _PromptSafetyTask {
  @override
  List<TaskNegativeCase> get negativeCases => const [
    TaskNegativeCase(
      id: 'noop',
      description: 'Leaves behavior unchanged.',
      kind: TaskNegativeCaseKind.noop,
      rootPath: 'custom_cases/noop_variant',
      solution: ReferenceFileSolution({
        'lib/answer.dart': 'int answer() => 41;\n',
      }),
    ),
  ];
}

class _CustomReferenceRootTask extends _PromptSafetyTask {
  @override
  ReferenceSolution? get referenceSolution => const ReferenceFileSolution({
    'lib/answer.dart': 'int answer() => 42;\n',
  }, rootPath: 'golden_reference');
}

class _SolutionRootReferenceTask extends _PromptSafetyTask {
  @override
  ReferenceSolution? get referenceSolution => const ReferenceFileSolution({
    'lib/answer.dart': 'int answer() => 42;\n',
  }, rootPath: 'solution');
}

class _ReferencePlanLeakTask extends _PromptSafetyTask {
  @override
  ReferencePlan? get referencePlan => const ReferencePlan(
    version: 1,
    markdown: 'The reference plan mentions solution/lib/answer.dart.',
  );
}

class _RawAuthoredHiddenIdTask extends _PromptSafetyTask {
  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'edge_cases_hidden',
      authoredId: 'edge_cases',
      testPath: 'test/_hidden/edge_cases_test.dart',
      files: {'test/_hidden/edge_cases_test.dart': 'void hidden() {}\n'},
    ),
  ];
}

class _PublicHiddenSnippetTask extends _PromptSafetyTask {
  @override
  Map<String, String> get fixtures => {
    ...super.fixtures,
    'test/public_hidden_shape_test.dart':
        '''
void main() {
  $_hiddenAssertion
}
''',
  };
}

class _PublicReferenceSnippetTask extends _PromptSafetyTask {
  @override
  Map<String, String> get fixtures => {
    ...super.fixtures,
    'test/public_reference_shape_test.dart':
        '''
void main() {
  $_referenceSnippet
}
''',
  };
}

class _PublicGenericTwoLineBlockTask extends _PromptSafetyTask {
  @override
  Map<String, String> get fixtures => {
    ...super.fixtures,
    'test/public_generic_block_test.dart': _genericTwoLineBlock,
  };

  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'public_block_hidden',
      testPath: 'test/_hidden/public_block_test.dart',
      files: {'test/_hidden/public_block_test.dart': _genericTwoLineBlock},
    ),
  ];

  @override
  ReferenceSolution? get referenceSolution =>
      const ReferenceFileSolution({'lib/answer.dart': _genericTwoLineBlock});
}

class _ShortIdTask extends _PromptSafetyTask {
  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      id: 'shortid',
      testPath: 'test/_hidden/short_identifier_test.dart',
      files: {'test/_hidden/short_identifier_test.dart': 'void hidden() {}\n'},
    ),
  ];
}
