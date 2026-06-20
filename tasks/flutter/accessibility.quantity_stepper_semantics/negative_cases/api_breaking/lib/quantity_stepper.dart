import 'package:flutter/material.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onValueChanged,
  });

  static const Key minusButtonKey = Key('quantity_stepper_decrement');
  static const Key valueTextKey = Key('quantity_stepper_value');
  static const Key plusButtonKey = Key('quantity_stepper_increment');

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onValueChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: minusButtonKey,
          tooltip: 'Decrease quantity',
          icon: const Icon(Icons.remove),
          onPressed: canDecrement ? () => onValueChanged(value - 1) : null,
        ),
        Semantics(
          key: valueTextKey,
          label: 'Quantity',
          value: '$value',
          excludeSemantics: true,
          child: Text('$value'),
        ),
        IconButton(
          key: plusButtonKey,
          tooltip: 'Increase quantity',
          icon: const Icon(Icons.add),
          onPressed: canIncrement ? () => onValueChanged(value + 1) : null,
        ),
      ],
    );
  }
}
