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
    // TODO: register event handlers so that:
    // - Increment increases value by 1
    // - Decrement decreases value by 1, but never below 0
    // - Reset sets value back to 0
  }
}
