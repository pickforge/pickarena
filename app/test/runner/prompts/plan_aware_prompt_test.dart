import 'package:dart_arena/runner/prompts/plan_aware_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('null plan returns the prompt unchanged', () {
    final out = buildPromptWithPlan(taskPrompt: 'do thing', planMarkdown: null);
    expect(out, 'do thing');
  });

  test('non-null plan injects a fenced plan block exactly once', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'do thing',
      planMarkdown: '1. step one\n2. step two',
    );
    expect(out.contains('do thing'), isTrue);
    expect(
      RegExp(r'```plan').allMatches(out).length,
      1,
      reason: 'plan fence opener should appear exactly once',
    );
    expect(out.contains('1. step one'), isTrue);
    expect(out.contains('2. step two'), isTrue);
  });

  test('null plan is the only no-op case', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'unrelated input',
      planMarkdown: null,
    );
    expect(out, 'unrelated input');
    expect(out.contains('REFERENCE PLAN'), isFalse);
  });

  test('target context is inserted before reference plan', () {
    final out = buildPromptWithPlan(
      taskPrompt: 'do thing',
      targetContext: 'File: lib/thing.dart\n```dart\nclass Thing {}\n```',
      planMarkdown: '1. keep the API',
    );

    expect(out, contains('CURRENT TARGET FILE API/SKELETON'));
    expect(out, contains('File: lib/thing.dart'));
    expect(
      out.indexOf('CURRENT TARGET FILE API/SKELETON'),
      lessThan(out.indexOf('REFERENCE PLAN')),
    );
  });

  test(
    'safe target context exposes public API without implementation bodies',
    () {
      final context = buildPromptSafeTargetContext(
        targetPath: 'lib/counter_bloc.dart',
        fixtures: const {
          'lib/counter_bloc.dart': '''
import 'package:bloc/bloc.dart';

// TODO: preserve public API.
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
    on<Reset>((event, emit) => emit(0));
  }
}
''',
          'test/_hidden/counter_hidden_test.dart': 'hidden secret',
          'reference/lib/counter_bloc.dart': 'reference secret',
        },
      );

      expect(context, isNotNull);
      expect(context, contains('File: lib/counter_bloc.dart'));
      expect(context, contains("import 'package:bloc/bloc.dart';"));
      expect(context, contains('// TODO: preserve public API.'));
      expect(context, contains('sealed class CounterEvent'));
      expect(context, contains('const Increment();'));
      expect(context, contains('const Decrement();'));
      expect(context, contains('const Reset();'));
      expect(context, contains('CounterBloc() : super(0)'));
      expect(context, contains('implementation omitted'));
      expect(context, isNot(contains('emit(')));
      expect(context, isNot(contains('hidden secret')));
      expect(context, isNot(contains('reference secret')));
    },
  );

  test('missing target fixture produces no target context', () {
    final context = buildPromptSafeTargetContext(
      targetPath: 'lib/missing.dart',
      fixtures: const {'lib/other.dart': 'class Other {}'},
    );

    expect(context, isNull);
  });

  test(
    'public test fixture context excludes hidden and reference fixtures',
    () {
      final context = buildPublicTestFixtureContext(
        fixtures: const {
          'test/counter_bloc_test.dart': 'void main() => testPublic();',
          'test/_hidden/counter_hidden_test.dart': 'hidden secret',
          'test/_reference/counter_reference_test.dart': 'reference secret',
        },
      );

      expect(context, contains('test/counter_bloc_test.dart'));
      expect(context, contains('testPublic'));
      expect(context, isNot(contains('hidden secret')));
      expect(context, isNot(contains('reference secret')));
    },
  );
}
