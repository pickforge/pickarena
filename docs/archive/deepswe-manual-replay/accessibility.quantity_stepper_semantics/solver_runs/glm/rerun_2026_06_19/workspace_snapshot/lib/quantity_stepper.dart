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

  bool get _canDecrement => value > min;
  bool get _canIncrement => value < max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: 'Decrease quantity',
          button: true,
          enabled: _canDecrement,
          onTap: _canDecrement ? () => onChanged(value - 1) : null,
          excludeSemantics: true,
          child: IconButton(
            key: decrementButtonKey,
            icon: const Icon(Icons.remove),
            onPressed: _canDecrement ? () => onChanged(value - 1) : null,
          ),
        ),
        Semantics(
          label: 'Quantity',
          value: '$value',
          excludeSemantics: true,
          child: Text('$value', key: valueTextKey),
        ),
        Semantics(
          label: 'Increase quantity',
          button: true,
          enabled: _canIncrement,
          onTap: _canIncrement ? () => onChanged(value + 1) : null,
          excludeSemantics: true,
          child: IconButton(
            key: incrementButtonKey,
            icon: const Icon(Icons.add),
            onPressed: _canIncrement ? () => onChanged(value + 1) : null,
          ),
        ),
      ],
    );
  }
}