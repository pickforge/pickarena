import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubTask extends BenchmarkTask {
  @override
  String get id => 'stub.one';

  @override
  Category get category => Category.bugFix;

  @override
  String get prompt => 'do nothing';

  @override
  Map<String, String> get fixtures => const {};

  @override
  String get generatedCodePath => 'lib/answer.dart';

  @override
  String? get judgeRubric => null;

  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => const [];
}

void main() {
  test('register and lookup', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(registry.byId('stub.one'), isA<_StubTask>());
    expect(registry.byCategory(Category.bugFix), hasLength(1));
  });

  test('duplicate id throws', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(() => registry.register(_StubTask()), throwsStateError);
  });
}
