import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(CounterBlocTask());
  return registry;
}
