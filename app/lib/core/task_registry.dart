import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';

class TaskRegistry {
  final Map<String, BenchmarkTask> _byId = {};

  void register(BenchmarkTask task) {
    if (_byId.containsKey(task.id)) {
      throw StateError('Duplicate task id: ${task.id}');
    }
    _byId[task.id] = task;
  }

  BenchmarkTask? byId(String id) => _byId[id];

  Iterable<BenchmarkTask> all() => _byId.values;

  Iterable<BenchmarkTask> byCategory(Category c) =>
      _byId.values.where((t) => t.category == c);

  Iterable<BenchmarkTask> byTrack(BenchmarkTrack track) =>
      _byId.values.where((t) => t.track == track);

  Iterable<BenchmarkTask> byDifficulty(TaskDifficulty difficulty) =>
      _byId.values.where((t) => t.difficulty == difficulty);

  Iterable<BenchmarkTask> byTag(TaskTag tag) =>
      _byId.values.where((t) => t.tags.contains(tag));

  Iterable<BenchmarkTask> supportedOn(TaskPlatform platform) =>
      _byId.values.where((t) => t.supportsPlatform(platform));

  Iterable<BenchmarkTask> query({
    Category? category,
    BenchmarkTrack? track,
    TaskDifficulty? difficulty,
    Set<TaskTag> tags = const {},
    TaskPlatform? supportedPlatform,
  }) {
    return _byId.values.where((task) {
      if (category != null && task.category != category) return false;
      if (track != null && task.track != track) return false;
      if (difficulty != null && task.difficulty != difficulty) return false;
      if (tags.isNotEmpty && !tags.every(task.tags.contains)) return false;
      if (supportedPlatform != null &&
          !task.supportsPlatform(supportedPlatform)) {
        return false;
      }
      return true;
    });
  }
}

extension BenchmarkTaskPlatformSupport on BenchmarkTask {
  bool supportsPlatform(TaskPlatform platform) =>
      platformRequirements.isEmpty || platformRequirements.contains(platform);
}
