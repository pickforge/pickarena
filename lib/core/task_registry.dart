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
}
