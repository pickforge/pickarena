import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/analyze_evaluator.dart';
import 'package:dart_arena/evaluators/compile_evaluator.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/evaluators/hidden_test_evaluator.dart';
import 'package:dart_arena/evaluators/test_author_evaluator.dart';
import 'package:dart_arena/evaluators/test_evaluator.dart';
import 'package:dart_arena/evaluators/widget_tree_evaluator.dart';
import 'package:dart_arena/runner/evaluator_resource_limits.dart';
import 'package:test/test.dart';

void main() {
  test('task output limit replaces default public test limit', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestEvaluator(),
      const TaskResourceLimits(maxOutputBytes: 4096),
    );

    expect(evaluator, isA<TestEvaluator>());
    expect((evaluator as TestEvaluator).maxOutputBytes, 4096);
  });

  test('task output limit caps custom public test limit', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestEvaluator(
        maxOutputBytes: 2048,
        dartExecutable: '/fake/dart',
        flutterExecutable: '/fake/flutter',
      ),
      const TaskResourceLimits(maxOutputBytes: 1024),
    );

    final testEvaluator = evaluator as TestEvaluator;
    expect(testEvaluator.maxOutputBytes, 1024);
    expect(testEvaluator.dartExecutable, '/fake/dart');
    expect(testEvaluator.flutterExecutable, '/fake/flutter');
  });

  test('stricter custom public test limit is preserved', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestEvaluator(maxOutputBytes: 512),
      const TaskResourceLimits(maxOutputBytes: 1024),
    );

    expect((evaluator as TestEvaluator).maxOutputBytes, 512);
  });

  test('task output limit applies to hidden test evaluator', () {
    final evaluator = applyResourceLimitsToEvaluator(
      HiddenTestEvaluator(_verifier),
      const TaskResourceLimits(maxOutputBytes: 256),
    );

    expect(evaluator, isA<HiddenTestEvaluator>());
    expect((evaluator as HiddenTestEvaluator).maxOutputBytes, 256);
  });

  test('task output limit applies to analyze evaluator', () {
    final evaluator = applyResourceLimitsToEvaluator(
      const AnalyzeEvaluator(),
      const TaskResourceLimits(maxOutputBytes: 768),
    );

    expect(evaluator, isA<AnalyzeEvaluator>());
    expect((evaluator as AnalyzeEvaluator).maxOutputBytes, 768);
  });

  test('task output limit applies to compile evaluator', () {
    final evaluator = applyResourceLimitsToEvaluator(
      const CompileEvaluator(),
      const TaskResourceLimits(maxOutputBytes: 768),
    );

    expect(evaluator, isA<CompileEvaluator>());
    expect((evaluator as CompileEvaluator).maxOutputBytes, 768);
  });

  test('task output limit applies to widget tree evaluator', () {
    final evaluator = applyResourceLimitsToEvaluator(
      WidgetTreeEvaluator(),
      const TaskResourceLimits(maxOutputBytes: 768),
    );

    expect(evaluator, isA<WidgetTreeEvaluator>());
    expect((evaluator as WidgetTreeEvaluator).maxOutputBytes, 768);
  });

  test('task output limit applies to test author evaluator', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestAuthorEvaluator(
        testPath: 'test/example_test.dart',
        mutants: const [],
      ),
      const TaskResourceLimits(maxOutputBytes: 768),
    );

    expect(evaluator, isA<TestAuthorEvaluator>());
    expect((evaluator as TestAuthorEvaluator).maxOutputBytes, 768);
  });

  test('task process limit applies to bounded evaluators', () {
    const limits = TaskResourceLimits(maxProcesses: 7);

    final test = applyResourceLimitsToEvaluator(TestEvaluator(), limits);
    expect((test as TestEvaluator).maxProcesses, 7);

    final hidden = applyResourceLimitsToEvaluator(
      HiddenTestEvaluator(_verifier),
      limits,
    );
    expect((hidden as HiddenTestEvaluator).maxProcesses, 7);

    final analyze = applyResourceLimitsToEvaluator(
      const AnalyzeEvaluator(),
      limits,
    );
    expect((analyze as AnalyzeEvaluator).maxProcesses, 7);

    final compile = applyResourceLimitsToEvaluator(
      const CompileEvaluator(),
      limits,
    );
    expect((compile as CompileEvaluator).maxProcesses, 7);

    final widgetTree = applyResourceLimitsToEvaluator(
      WidgetTreeEvaluator(),
      limits,
    );
    expect((widgetTree as WidgetTreeEvaluator).maxProcesses, 7);

    final testAuthor = applyResourceLimitsToEvaluator(
      TestAuthorEvaluator(
        testPath: 'test/example_test.dart',
        mutants: const [],
      ),
      limits,
    );
    expect((testAuthor as TestAuthorEvaluator).maxProcesses, 7);
  });

  test('stricter custom process limit is preserved', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestEvaluator(maxProcesses: 3),
      const TaskResourceLimits(maxProcesses: 7),
    );

    expect((evaluator as TestEvaluator).maxProcesses, 3);
  });

  test('task memory limit applies to bounded evaluators', () {
    const limits = TaskResourceLimits(memoryMb: 512);

    final test = applyResourceLimitsToEvaluator(TestEvaluator(), limits);
    expect((test as TestEvaluator).maxMemoryMb, 512);

    final hidden = applyResourceLimitsToEvaluator(
      HiddenTestEvaluator(_verifier),
      limits,
    );
    expect((hidden as HiddenTestEvaluator).maxMemoryMb, 512);

    final analyze = applyResourceLimitsToEvaluator(
      const AnalyzeEvaluator(),
      limits,
    );
    expect((analyze as AnalyzeEvaluator).maxMemoryMb, 512);

    final compile = applyResourceLimitsToEvaluator(
      const CompileEvaluator(),
      limits,
    );
    expect((compile as CompileEvaluator).maxMemoryMb, 512);

    final widgetTree = applyResourceLimitsToEvaluator(
      WidgetTreeEvaluator(),
      limits,
    );
    expect((widgetTree as WidgetTreeEvaluator).maxMemoryMb, 512);

    final testAuthor = applyResourceLimitsToEvaluator(
      TestAuthorEvaluator(
        testPath: 'test/example_test.dart',
        mutants: const [],
      ),
      limits,
    );
    expect((testAuthor as TestAuthorEvaluator).maxMemoryMb, 512);
  });

  test('stricter custom memory limit is preserved', () {
    final evaluator = applyResourceLimitsToEvaluator(
      TestEvaluator(maxMemoryMb: 256),
      const TaskResourceLimits(memoryMb: 512),
    );

    expect((evaluator as TestEvaluator).maxMemoryMb, 256);
  });

  test('task evaluator wrapping uses effective resource defaults', () {
    final evaluators = applyTaskResourceLimitsToEvaluators([
      TestEvaluator(),
    ], _PartialLimitTask());

    final evaluator = evaluators.single as TestEvaluator;
    expect(evaluator.maxOutputBytes, 2048);
    expect(evaluator.maxProcesses, 64);
    expect(evaluator.maxMemoryMb, 8192);
  });
}

const _verifier = VerifierFixture(
  files: {'test/_hidden/example_test.dart': 'void main() {}'},
  testPath: 'test/_hidden/example_test.dart',
);

class _PartialLimitTask extends BenchmarkTask {
  @override
  String get id => 'partial-limit';

  @override
  Category get category => Category.bugFix;

  @override
  TaskResourceLimits get resourceLimits =>
      const TaskResourceLimits(maxOutputBytes: 2048);

  @override
  String get prompt => 'prompt';

  @override
  Map<String, String> get fixtures => const {};

  @override
  String? get judgeRubric => null;

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}
