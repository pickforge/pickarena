import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class CartLine extends Equatable {
  const CartLine({required this.id, required this.unitPriceCents, required this.quantity});

  final String id;
  final int unitPriceCents;
  final int quantity;

  int get subtotalCents => unitPriceCents * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(id: id, unitPriceCents: unitPriceCents, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [id, unitPriceCents, quantity];
}

class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  int get subtotalCents => lines.fold(0, (sum, l) => sum + l.subtotalCents);

  CartState copyWith({List<CartLine>? lines}) => CartState(lines: lines ?? this.lines);

  @override
  List<Object?> get props => [lines];
}

sealed class CartEvent {
  const CartEvent();
}

class AddItem extends CartEvent {
  const AddItem({required this.id, required this.unitPriceCents, this.quantity = 1});
  final String id;
  final int unitPriceCents;
  final int quantity;
}

class RemoveItem extends CartEvent {
  const RemoveItem(this.id);
  final String id;
}

class UpdateQuantity extends CartEvent {
  const UpdateQuantity({required this.id, required this.quantity});
  final String id;
  final int quantity;
}

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    // TODO: register handlers for AddItem, RemoveItem, UpdateQuantity such that:
    // - Adding an existing id increments its quantity (does not duplicate the line).
    // - Adding a new id appends a CartLine.
    // - RemoveItem drops the matching line; no-op if not present.
    // - UpdateQuantity sets a line's quantity; quantity 0 removes the line.
  }
}
