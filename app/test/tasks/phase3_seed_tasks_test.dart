import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/tasks/flutter_corpus/phase3_seed_tasks.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase 3 seed tasks are registered with executable metadata', () {
    final registry = buildDefaultTaskRegistry();

    for (final id in Phase3SeedTaskIds.all) {
      final task = registry.byId(id);
      expect(task, isNotNull, reason: id);
      expect(task!.version, 1, reason: id);
      expect(task.tags, isNotEmpty, reason: id);
      expect(task.difficulty, isNot(TaskDifficulty.unspecified), reason: id);
      expect(task.timeout, isNotNull, reason: id);
      expect(task.hiddenVerifiers, isNotEmpty, reason: id);
      expect(task.referenceSolution, isA<ReferenceFileSolution>(), reason: id);
      expect(
        task.fixtures.keys,
        isNot(contains(task.hiddenVerifiers.single.testPath)),
        reason: id,
      );
    }
  });

  test('phase 3 corpus contains the reviewed task set only once', () {
    final registry = buildDefaultTaskRegistry();
    final phase3Ids = registry
        .all()
        .where(
          (task) =>
              task.tags.isNotEmpty &&
              task.difficulty != TaskDifficulty.unspecified,
        )
        .map((task) => task.id)
        .toList();

    expect(phase3Ids, unorderedEquals(Phase3SeedTaskIds.all));
  });

  test('codegen model migration exercises build runner outputs', () {
    final task = CodegenModelMigrationTask();
    final reference = task.referenceSolution as ReferenceFileSolution;
    final hiddenTest = task.hiddenVerifiers.single.files.values.single;

    expect(task.track, BenchmarkTrack.agentic);
    expect(task.prompt, contains('dart run build_runner build'));
    expect(task.fixtures['pubspec.yaml'], contains('build_runner'));
    expect(task.fixtures['pubspec.yaml'], contains('json_serializable'));
    expect(
      task.fixtures['lib/user_model.dart'],
      contains('@JsonSerializable()'),
    );
    expect(hiddenTest, contains("'build_runner'"));
    expect(reference.files.keys, contains('lib/user_model.g.dart'));
  });
}
