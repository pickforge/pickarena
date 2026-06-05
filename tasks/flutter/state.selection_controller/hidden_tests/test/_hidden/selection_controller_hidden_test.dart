import 'package:flutter_test/flutter_test.dart';
import 'package:state_selection_controller/selection_controller.dart';

void main() {
  test('toggle supports multiple selected ids and deselection', () {
    final controller = SelectionController();

    controller.toggle('beta');
    controller.toggle('alpha');

    expect(controller.isSelected('alpha'), isTrue);
    expect(controller.isSelected('beta'), isTrue);
    expect(controller.selectedIds, ['alpha', 'beta']);

    controller.toggle('alpha');

    expect(controller.isSelected('alpha'), isFalse);
    expect(controller.isSelected('beta'), isTrue);
    expect(controller.selectedIds, ['beta']);
  });

  test('blank ids are ignored', () {
    final controller = SelectionController();

    controller.toggle('');
    controller.toggle('   ');
    controller.toggle('delta');

    expect(controller.selectedIds, ['delta']);
  });

  test('selected ids are stable and sorted without leaking mutable state', () {
    final controller = SelectionController();

    controller.toggle('zeta');
    controller.toggle('alpha');
    final snapshot = controller.selectedIds;
    try {
      snapshot.add('mutated');
      expect(snapshot, contains('mutated'));
    } on UnsupportedError {
      expect(snapshot, ['alpha', 'zeta']);
    }

    expect(controller.selectedIds, ['alpha', 'zeta']);
  });
}
