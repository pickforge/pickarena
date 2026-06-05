import 'package:flutter_test/flutter_test.dart';
import 'package:state_selection_controller/selection_controller.dart';

void main() {
  test('selects an item when toggled', () {
    final controller = SelectionController();

    controller.toggle('inbox');

    expect(controller.isSelected('inbox'), isTrue);
    expect(controller.selectedIds, ['inbox']);
  });

  test('clear removes a selected item', () {
    final controller = SelectionController();

    controller.toggle('inbox');
    controller.clear();

    expect(controller.isSelected('inbox'), isFalse);
    expect(controller.selectedIds, isEmpty);
  });
}
