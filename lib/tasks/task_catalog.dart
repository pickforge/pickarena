import 'package:dart_arena/core/task_registry.dart';
import 'package:dart_arena/tasks/bug_fix/async_race_condition.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:dart_arena/tasks/planning_and_execution/add_evaluator_type.dart';
import 'package:dart_arena/tasks/planning_and_execution/add_filter_dimension.dart';
import 'package:dart_arena/tasks/refactor/callback_hell.dart';
import 'package:dart_arena/tasks/refactor/god_widget.dart';
import 'package:dart_arena/tasks/state_management/counter_bloc.dart';
import 'package:dart_arena/tasks/state_management/shopping_cart_bloc.dart';
import 'package:dart_arena/tasks/ui_from_spec/expandable_list_tile.dart';
import 'package:dart_arena/tasks/ui_from_spec/profile_card.dart';
import 'package:dart_arena/tasks/widget_testing/form_validation.dart';
import 'package:dart_arena/tasks/widget_testing/todo_input.dart';

TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(CounterBlocTask());
  registry.register(ShoppingCartBlocTask());
  registry.register(ProfileCardTask());
  registry.register(ExpandableListTileTask());
  registry.register(GodWidgetTask());
  registry.register(CallbackHellTask());
  registry.register(TodoInputTestTask());
  registry.register(FormValidationTestTask());
  registry.register(AsyncRaceConditionTask());
  registry.register(AgenticAsyncRaceConditionTask());
  registry.register(AddEvaluatorTypeTask());
  registry.register(AddFilterDimensionTask());
  return registry;
}
