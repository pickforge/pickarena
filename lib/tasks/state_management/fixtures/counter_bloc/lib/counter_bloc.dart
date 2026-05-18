import 'package:bloc/bloc.dart';

sealed class CounterEvent {
  const CounterEvent();
}

class Increment extends CounterEvent {
  const Increment();
}

class Decrement extends CounterEvent {
  const Decrement();
}

class Reset extends CounterEvent {
  const Reset();
}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((event, emit) => emit(state + 1));
    on<Decrement>((event, emit) {
      if (state > 0) {
        emit(state - 1);
      }
    });
    on<Reset>((event, emit) => emit(0));
  }
}
