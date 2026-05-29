import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate parses stdout into ModelResponse', () async {
    late List<String> seenArgs;
    final p = DroidExecProvider(
      runner: (executable, args) async {
        seenArgs = args;
        return const DroidProcessResult(
          stdout: 'hello from droid',
          stderr: '',
          exitCode: 0,
        );
      },
    );
    final r = await p.generate(prompt: 'hi', model: 'gpt-5.5');
    expect(r.rawText, 'hello from droid');
    expect(seenArgs, containsAllInOrder(['--enabled-tools', '']));
    expect(seenArgs, containsAllInOrder(['--model', 'gpt-5.5']));
    expect(seenArgs.last, contains('Do not use tools'));
    expect(seenArgs.last, contains('hi'));
  });

  test('throws when droid returns non-zero exit code', () async {
    final p = DroidExecProvider(
      runner: (executable, args) async => const DroidProcessResult(
        stdout: '',
        stderr: 'something went wrong',
        exitCode: 1,
      ),
    );
    expect(
      () => p.generate(prompt: 'hi', model: 'gpt-5.5'),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'listModels returns ModelInfo with curated list with real CLI models',
    () async {
      final p = DroidExecProvider();
      final m = await p.listModels();
      final ids = m.map((mi) => mi.id).toSet();
      expect(ids, contains('gpt-5.5'));
      expect(ids, contains('claude-sonnet-4-6'));
      for (final mi in m) {
        expect(mi.efforts, isEmpty);
      }
    },
  );

  test('listModels includes custom models from factory settings', () async {
    final p = DroidExecProvider();
    final m = await p.listModels();
    final ids = m.map((mi) => mi.id).toSet();
    const builtInCount = 6;
    expect(m.length, greaterThanOrEqualTo(builtInCount));
    final customIds = ids.difference({
      'gpt-5.5',
      'gpt-5.4',
      'gpt-5.3-codex',
      'claude-sonnet-4-6',
      'claude-opus-4-7',
      'gemini-3-flash',
    });
    for (final id in customIds) {
      expect(
        id,
        isNot(
          anyOf([
            'gpt-5.5',
            'gpt-5.4',
            'gpt-5.3-codex',
            'claude-sonnet-4-6',
            'claude-opus-4-7',
            'gemini-3-flash',
          ]),
        ),
      );
    }
  });
}
