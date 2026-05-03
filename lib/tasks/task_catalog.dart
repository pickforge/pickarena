import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  return registry;
}
