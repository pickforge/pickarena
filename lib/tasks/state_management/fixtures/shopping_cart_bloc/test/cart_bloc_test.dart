import 'package:bloc_test/bloc_test.dart';
import 'package:shopping_cart_bloc_fixture/cart_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('CartBloc', () {
    blocTest<CartBloc, CartState>(
      'starts empty',
      build: CartBloc.new,
      verify: (bloc) {
        expect(bloc.state.lines, isEmpty);
        expect(bloc.state.itemCount, 0);
        expect(bloc.state.subtotalCents, 0);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem appends new line',
      build: CartBloc.new,
      act: (bloc) => bloc.add(const AddItem(id: 'a', unitPriceCents: 100)),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.id, 'a');
        expect(bloc.state.lines.single.quantity, 1);
        expect(bloc.state.subtotalCents, 100);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem with same id merges (increments quantity, no duplicate line)',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(const AddItem(id: 'a', unitPriceCents: 100))
        ..add(const AddItem(id: 'a', unitPriceCents: 100, quantity: 2)),
      verify: (bloc) {
        expect(bloc.state.lines, hasLength(1));
        expect(bloc.state.lines.single.quantity, 3);
        expect(bloc.state.subtotalCents, 300);
      },
    );

    blocTest<CartBloc, CartState>(
      'AddItem with different id appends second line',
      build: CartBloc.new,
      act: (bloc) => bloc
        ..add(const AddItem(id: 'a', unitPriceCents: 100))
        ..add(const AddItem(id: 'b', unitPriceCents: 250)),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['a', 'b']);
        expect(bloc.state.itemCount, 2);
        expect(bloc.state.subtotalCents, 350);
      },
    );

    blocTest<CartBloc, CartState>(
      'RemoveItem drops the line',
      build: CartBloc.new,
      seed: () => const CartState(
        lines: [
          CartLine(id: 'a', unitPriceCents: 100, quantity: 2),
          CartLine(id: 'b', unitPriceCents: 250, quantity: 1),
        ],
      ),
      act: (bloc) => bloc.add(const RemoveItem('a')),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['b']);
      },
    );

    blocTest<CartBloc, CartState>(
      'RemoveItem is a no-op when id missing',
      build: CartBloc.new,
      seed: () => const CartState(
        lines: [CartLine(id: 'a', unitPriceCents: 100, quantity: 1)],
      ),
      act: (bloc) => bloc.add(const RemoveItem('nope')),
      expect: () => <CartState>[],
    );

    blocTest<CartBloc, CartState>(
      'UpdateQuantity sets new quantity',
      build: CartBloc.new,
      seed: () => const CartState(
        lines: [CartLine(id: 'a', unitPriceCents: 100, quantity: 1)],
      ),
      act: (bloc) => bloc.add(const UpdateQuantity(id: 'a', quantity: 5)),
      verify: (bloc) {
        expect(bloc.state.lines.single.quantity, 5);
        expect(bloc.state.subtotalCents, 500);
      },
    );

    blocTest<CartBloc, CartState>(
      'UpdateQuantity to 0 removes the line',
      build: CartBloc.new,
      seed: () => const CartState(
        lines: [
          CartLine(id: 'a', unitPriceCents: 100, quantity: 3),
          CartLine(id: 'b', unitPriceCents: 250, quantity: 1),
        ],
      ),
      act: (bloc) => bloc.add(const UpdateQuantity(id: 'a', quantity: 0)),
      verify: (bloc) {
        expect(bloc.state.lines.map((l) => l.id), ['b']);
      },
    );
  });
}
