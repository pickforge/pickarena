import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OffByOnePaginationTask metadata', () async {
    final task = OffByOnePaginationTask();
    await task.ensureLoaded();
    expect(task.id, 'bug.off_by_one_pagination');
    expect(task.category, Category.bugFix);
    expect(task.generatedCodePath, 'lib/pagination.dart');
    expect(task.judgeRubric, isNotNull);
    expect(task.fixtures.keys, contains('lib/pagination.dart'));
  });

  test('evaluatorsFor without judge returns 4 evaluators', () {
    final task = OffByOnePaginationTask();
    final evs = task.evaluatorsFor(const EvaluatorConfig());
    expect(evs, hasLength(4));
    expect(evs.map((e) => e.id).toList(), [
      'compile',
      'analyze',
      'test',
      'diff_size',
    ]);
  });
}
