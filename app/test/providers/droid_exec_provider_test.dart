import 'dart:async';
import 'dart:io';

import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('generate parses stdout into ModelResponse', () async {
    late List<String> seenArgs;
    Duration? seenTimeout;
    final provider = DroidExecProvider(
      runner: (executable, args, timeout) async {
        seenArgs = args;
        seenTimeout = timeout;
        return const DroidProcessResult(
          stdout: 'hello from droid',
          stderr: '',
          exitCode: 0,
        );
      },
    );
    final response = await provider.generate(
      prompt: 'hi',
      model: 'gpt-5.5',
      timeout: const Duration(seconds: 3),
    );
    expect(response.rawText, 'hello from droid');
    expect(seenTimeout, const Duration(seconds: 3));
    expect(seenArgs, containsAllInOrder(['--enabled-tools', '']));
    expect(seenArgs, containsAllInOrder(['--model', 'gpt-5.5']));
    expect(seenArgs.last, contains('Do not use tools'));
    expect(seenArgs.last, contains('hi'));
  });

  test('throws when droid returns non-zero exit code', () async {
    final provider = DroidExecProvider(
      runner: (executable, args, timeout) async => const DroidProcessResult(
        stdout: '',
        stderr: 'something went wrong',
        exitCode: 1,
      ),
    );
    expect(
      () => provider.generate(prompt: 'hi', model: 'gpt-5.5'),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'generate kills droid exec process when timeout expires',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_droid_timeout_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final marker = File(p.join(root.path, 'marker.txt'));
      final fakeDroid = await _writeHangingExecutable(root, marker);
      final provider = DroidExecProvider(droidPath: fakeDroid.path);

      final stopwatch = Stopwatch()..start();
      await expectLater(
        provider.generate(
          prompt: 'Generate a function.',
          model: 'fake-model',
          timeout: const Duration(milliseconds: 120),
        ),
        throwsA(isA<TimeoutException>()),
      );
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(marker.readAsStringSync(), contains('started'));
      expect(marker.readAsStringSync(), isNot(contains('done')));
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test(
    'listModels returns ModelInfo with curated list with real CLI models',
    () async {
      final provider = DroidExecProvider();
      final models = await provider.listModels();
      final ids = models.map((mi) => mi.id).toSet();
      expect(ids, contains('gpt-5.5'));
      expect(ids, contains('claude-sonnet-4-6'));
      for (final model in models) {
        expect(model.efforts, isEmpty);
      }
    },
  );

  test('listModels includes custom models from factory settings', () async {
    final provider = DroidExecProvider();
    final models = await provider.listModels();
    final ids = models.map((mi) => mi.id).toSet();
    const builtInCount = 6;
    expect(models.length, greaterThanOrEqualTo(builtInCount));
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

Future<File> _writeHangingExecutable(Directory root, File marker) async {
  final script = File(p.join(root.path, 'fake_droid.sh'));
  await script.writeAsString('''
#!/bin/sh
echo started >> '${marker.path}'
sleep 20
echo done >> '${marker.path}'
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
