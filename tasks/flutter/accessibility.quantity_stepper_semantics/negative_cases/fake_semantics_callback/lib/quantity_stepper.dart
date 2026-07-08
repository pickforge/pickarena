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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          enabled: true,
          label: 'Decrease quantity',
          onTap: () {},
          excludeSemantics: true,
          child: IconButton(
            key: decrementButtonKey,
            icon: const Icon(Icons.remove),
            onPressed: () {
              if (value > min) {
                onChanged(value - 1);
              }
            },
          ),
        ),
        Semantics(
          key: valueTextKey,
          label: 'Quantity',
          value: '$value',
          excludeSemantics: true,
          child: Text('$value'),
        ),
        Semantics(
          button: true,
          enabled: true,
          label: 'Increase quantity',
          onTap: () {},
          excludeSemantics: true,
          child: IconButton(
            key: incrementButtonKey,
            icon: const Icon(Icons.add),
            onPressed: () {
              if (value < max) {
                onChanged(value + 1);
              }
            },
          ),
        ),
      ],
    );
  }
}
