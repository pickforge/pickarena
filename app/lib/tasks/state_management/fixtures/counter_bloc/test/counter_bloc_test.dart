import 'package:bloc_test/bloc_test.dart';
import 'package:counter_bloc_fixture/counter_bloc.dart';
import 'package:test/test.dart';

void main() {
  group('CounterBloc', () {
    blocTest<CounterBloc, int>(
      'starts at 0',
      build: CounterBloc.new,
      verify: (bloc) => expect(bloc.state, 0),
    );

    blocTest<CounterBloc, int>(
      'Increment emits 1',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(const Increment()),
      expect: () => [1],
    );

    blocTest<CounterBloc, int>(
      'Increment x3 emits 1, 2, 3',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Increment())
        ..add(const Increment()),
      expect: () => [1, 2, 3],
    );

    blocTest<CounterBloc, int>(
      'Decrement at 0 stays at 0 (no emission)',
      build: CounterBloc.new,
      act: (bloc) => bloc.add(const Decrement()),
      expect: () => <int>[],
    );

    blocTest<CounterBloc, int>(
      'Increment then Decrement returns to 0',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Decrement()),
      expect: () => [1, 0],
    );

    blocTest<CounterBloc, int>(
      'Reset after increments emits 0 once',
      build: CounterBloc.new,
      act: (bloc) => bloc
        ..add(const Increment())
        ..add(const Increment())
        ..add(const Reset()),
      expect: () => [1, 2, 0],
    );
  });
}
