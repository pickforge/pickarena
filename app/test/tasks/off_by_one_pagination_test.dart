import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:test/test.dart';

import '../support/official_tasks.dart';

void main() {
  test(
    'official file-backed task metadata loads from top-level tasks',
    () async {
      final task = await loadOfficialFlutterTask('forms.email_validation');
      await task.ensureLoaded();

      expect(task.id, 'forms.email_validation');
      expect(task.category, Category.bugFix);
      expect(task.track, BenchmarkTrack.agentic);
      expect(task.generatedCodePath, 'lib/email_signup_controller.dart');
      expect(task.judgeRubric, isNull);
      expect(task.fixtures.keys, contains('lib/email_signup_controller.dart'));
      expect(
        task.fixtures.keys,
        contains('test/email_signup_controller_test.dart'),
      );
      expect(
        task.fixtures.keys,
        isNot(contains(task.hiddenVerifiers.single.testPath)),
      );
    },
  );

  test(
    'official file-backed evaluators include hidden test and diff size',
    () async {
      final task = await loadOfficialFlutterTask('forms.email_validation');
      await task.ensureLoaded();

      final evs = task.evaluatorsFor(const EvaluatorConfig());

      expect(evs.map((e) => e.id).toList(), [
        'compile',
        'analyze',
        'test',
        task.hiddenVerifiers.single.id,
        'diff_size',
      ]);
    },
  );
}
