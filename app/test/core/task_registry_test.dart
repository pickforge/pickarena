import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('register and lookup', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(registry.byId('stub.one'), isA<_StubTask>());
    expect(registry.byCategory(Category.bugFix), hasLength(1));
    expect(registry.byTrack(BenchmarkTrack.codegen), hasLength(1));
    expect(registry.byDifficulty(TaskDifficulty.unspecified), hasLength(1));
  });

  test('duplicate id throws', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(() => registry.register(_StubTask()), throwsStateError);
  });

  test(
    'default registry includes an agentic task with visible workspace',
    () async {
      final registry = buildDefaultTaskRegistry();
      final task = registry.byId('agentic.bug.async_race_condition');

      expect(task, isNotNull);
      expect(task!.track, BenchmarkTrack.agentic);
      await task.ensureLoaded();

      expect(task.workspace.files, isNotEmpty);
      expect(task.hiddenVerifiers, isNotEmpty);
      expect(
        task.workspace.files.keys,
        everyElement(
          predicate<String>((path) => !_isExcludedWorkspacePath(path)),
        ),
      );
    },
  );

  test('default metadata keeps legacy tasks filterable', () {
    final task = _StubTask();

    expect(task.tags, isEmpty);
    expect(task.difficulty, TaskDifficulty.unspecified);
    expect(task.timeout, isNull);
    expect(task.platformRequirements, isEmpty);
    expect(task.supportsPlatform(TaskPlatform.linux), isTrue);
  });

  test('registry queries tags, difficulty, track, and platform', () {
    final registry = buildDefaultTaskRegistry();
    final tasks = registry
        .query(
          track: BenchmarkTrack.agentic,
          difficulty: TaskDifficulty.hard,
          tags: const {TaskTag.navigation},
          supportedPlatform: TaskPlatform.linux,
        )
        .map((task) => task.id)
        .toList();

    expect(tasks, contains('navigation.go_router_auth_redirect'));
    expect(tasks, isNot(contains('state.bloc_debounce_cancellation')));
  });
}

bool _isExcludedWorkspacePath(String relativePath) {
  final parts = p
      .split(p.normalize(relativePath))
      .map((part) => part.toLowerCase())
      .toList(growable: false);
  if (parts.any(
    (part) =>
        part == '.git' ||
        part == '_hidden' ||
        part == 'reference' ||
        part == '_reference' ||
        part == 'author_notes' ||
        part == '_author' ||
        part == 'task_qa',
  )) {
    return true;
  }
  final basename = parts.isEmpty ? '' : parts.last;
  return basename == 'author_notes.md' ||
      basename == 'qa_report.md' ||
      basename == 'task_qa_report.md';
}
