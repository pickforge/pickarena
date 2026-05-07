import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate parses stdout into ModelResponse', () async {
    final p = DroidExecProvider(
      runner: (executable, args) async => const DroidProcessResult(
        stdout: 'hello from droid',
        stderr: '',
        exitCode: 0,
      ),
    );
    final r = await p.generate(prompt: 'hi', model: 'gpt-5.5');
    expect(r.rawText, 'hello from droid');
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
}
