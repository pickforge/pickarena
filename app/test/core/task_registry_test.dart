import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/tasks/task_catalog.dart';
import 'package:test/test.dart';

class _StubTask extends BenchmarkTask {
  _StubTask({
    this.stubId = 'stub.one',
    this.stubCategory = Category.bugFix,
    this.stubTrack = BenchmarkTrack.codegen,
    this.stubTags = const {},
    this.stubDifficulty = TaskDifficulty.unspecified,
    this.stubPlatformRequirements = const {},
  });

  final String stubId;
  final Category stubCategory;
  final BenchmarkTrack stubTrack;
  final Set<TaskTag> stubTags;
  final TaskDifficulty stubDifficulty;
  final Set<TaskPlatform> stubPlatformRequirements;

  @override
  String get id => stubId;

  @override
  Category get category => stubCategory;

  @override
  BenchmarkTrack get track => stubTrack;

  @override
  Set<TaskTag> get tags => stubTags;

  @override
  TaskDifficulty get difficulty => stubDifficulty;

  @override
  Set<TaskPlatform> get platformRequirements => stubPlatformRequirements;

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
    expect(registry.byTrack(BenchmarkTrack.codegen), hasLength(1));
    expect(registry.byDifficulty(TaskDifficulty.unspecified), hasLength(1));
  });

  test('duplicate id throws', () {
    final registry = TaskRegistry();
    registry.register(_StubTask());
    expect(() => registry.register(_StubTask()), throwsStateError);
  });

  test('default registry does not embed corpus tasks', () {
    final registry = buildDefaultTaskRegistry();

    expect(registry.all(), isEmpty);
  });

  test('default metadata keeps ad hoc tasks filterable', () {
    final task = _StubTask();

    expect(task.tags, isEmpty);
    expect(task.difficulty, TaskDifficulty.unspecified);
    expect(task.timeout, isNull);
    expect(task.platformRequirements, isEmpty);
    expect(task.supportsPlatform(TaskPlatform.linux), isTrue);
  });

  test('registry queries tags, difficulty, track, and platform', () {
    final registry = TaskRegistry()
      ..register(
        _StubTask(
          stubId: 'agentic.navigation',
          stubTrack: BenchmarkTrack.agentic,
          stubTags: {TaskTag.navigation},
          stubDifficulty: TaskDifficulty.hard,
          stubPlatformRequirements: {TaskPlatform.linux},
        ),
      )
      ..register(
        _StubTask(
          stubId: 'codegen.state',
          stubCategory: Category.stateManagement,
          stubTags: {TaskTag.stateBloc},
          stubDifficulty: TaskDifficulty.medium,
        ),
      );
    final tasks = registry
        .query(
          track: BenchmarkTrack.agentic,
          difficulty: TaskDifficulty.hard,
          tags: const {TaskTag.navigation},
          supportedPlatform: TaskPlatform.linux,
        )
        .map((task) => task.id)
        .toList();

    expect(tasks, ['agentic.navigation']);
  });
}
