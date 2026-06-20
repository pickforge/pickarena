import 'package:flutter/material.dart';

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  static const Key decrementButtonKey = Key('quantity_stepper_decrement');
  static const Key valueTextKey = Key('quantity_stepper_value');
  static const Key incrementButtonKey = Key('quantity_stepper_increment');

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          key: decrementButtonKey,
          icon: const Icon(Icons.remove),
          tooltip: 'Decrease quantity',
          onPressed: canDecrement ? () => onChanged(value - 1) : null,
        ),
        Semantics(
          label: 'Quantity',
          value: '$value',
          excludeSemantics: true,
          child: Text('$value', key: valueTextKey),
        ),
        IconButton(
          key: incrementButtonKey,
          icon: const Icon(Icons.add),
          tooltip: 'Increase quantity',
          onPressed: canIncrement ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
