import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';
import 'package:dart_arena/tasks/state_management/shopping_cart_bloc.dart';
import 'package:dart_arena/tasks/ui_from_spec/expandable_list_tile.dart';
import 'package:dart_arena/tasks/ui_from_spec/profile_card.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(CounterBlocTask());
  registry.register(ShoppingCartBlocTask());
  registry.register(ProfileCardTask());
  registry.register(ExpandableListTileTask());
  return registry;
}
