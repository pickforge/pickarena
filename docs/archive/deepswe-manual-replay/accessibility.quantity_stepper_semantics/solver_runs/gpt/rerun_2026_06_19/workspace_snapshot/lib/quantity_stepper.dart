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
        Semantics(
          key: decrementButtonKey,
          container: true,
          label: 'Decrease quantity',
          button: true,
          enabled: canDecrement,
          onTap: canDecrement ? () => onChanged(value - 1) : null,
          child: ExcludeSemantics(
            child: IconButton(
              icon: const Icon(Icons.remove),
              onPressed: canDecrement ? () => onChanged(value - 1) : null,
            ),
          ),
        ),
        Semantics(
          key: valueTextKey,
          container: true,
          label: 'Quantity',
          value: '$value',
          child: ExcludeSemantics(child: Text('$value')),
        ),
        Semantics(
          key: incrementButtonKey,
          container: true,
          label: 'Increase quantity',
          button: true,
          enabled: canIncrement,
          onTap: canIncrement ? () => onChanged(value + 1) : null,
          child: ExcludeSemantics(
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: canIncrement ? () => onChanged(value + 1) : null,
            ),
          ),
        ),
      ],
    );
  }
}
