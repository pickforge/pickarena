import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

class CartLine extends Equatable {
  const CartLine({
    required this.id,
    required this.unitPriceCents,
    required this.quantity,
  });

  final String id;
  final int unitPriceCents;
  final int quantity;

  int get subtotalCents => unitPriceCents * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
    id: id,
    unitPriceCents: unitPriceCents,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [id, unitPriceCents, quantity];
}

class CartState extends Equatable {
  const CartState({this.lines = const []});

  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
  int get subtotalCents => lines.fold(0, (sum, l) => sum + l.subtotalCents);

  CartState copyWith({List<CartLine>? lines}) =>
      CartState(lines: lines ?? this.lines);

  @override
  List<Object?> get props => [lines];
}

sealed class CartEvent {
  const CartEvent();
}

class AddItem extends CartEvent {
  const AddItem({
    required this.id,
    required this.unitPriceCents,
    this.quantity = 1,
  });
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
    on<AddItem>(_onAddItem);
    on<RemoveItem>(_onRemoveItem);
    on<UpdateQuantity>(_onUpdateQuantity);
  }

  void _onAddItem(AddItem event, Emitter<CartState> emit) {
    final index = state.lines.indexWhere((l) => l.id == event.id);
    if (index >= 0) {
      final updated = state.lines[index].copyWith(
        quantity: state.lines[index].quantity + event.quantity,
      );
      final newLines = List<CartLine>.from(state.lines);
      newLines[index] = updated;
      emit(state.copyWith(lines: newLines));
    } else {
      emit(
        state.copyWith(
          lines: [
            ...state.lines,
            CartLine(
              id: event.id,
              unitPriceCents: event.unitPriceCents,
              quantity: event.quantity,
            ),
          ],
        ),
      );
    }
  }

  void _onRemoveItem(RemoveItem event, Emitter<CartState> emit) {
    final index = state.lines.indexWhere((l) => l.id == event.id);
    if (index >= 0) {
      emit(
        state.copyWith(
          lines: state.lines.where((l) => l.id != event.id).toList(),
        ),
      );
    }
  }

  void _onUpdateQuantity(UpdateQuantity event, Emitter<CartState> emit) {
    final index = state.lines.indexWhere((l) => l.id == event.id);
    if (index < 0) return;
    if (event.quantity <= 0) {
      emit(
        state.copyWith(
          lines: state.lines.where((l) => l.id != event.id).toList(),
        ),
      );
    } else {
      final newLines = List<CartLine>.from(state.lines);
      newLines[index] = state.lines[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(lines: newLines));
    }
  }
}
