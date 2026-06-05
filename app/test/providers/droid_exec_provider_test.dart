import 'dart:async';
import 'dart:io';

import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('runtime metadata records direct exec defaults without secrets', () {
    final provider = DroidExecProvider();

    expect(provider.providerRuntimeConfig(), {
      'providerMode': 'agent',
      'execution': 'droid_exec',
      'secretsRedacted': true,
    });
    expect(provider.modelRuntimeConfig('builtin-test-model'), {
      'executionMode': 'direct_prompt',
      'autonomyMode': 'medium',
      'outputFormat': 'text',
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolsEnabled': false,
      'toolPolicy': 'disabled',
    });
  });

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
    expect(seenArgs, containsAllInOrder(['--auto', 'medium']));
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

  test('throws actionable hint for generic custom model exec failures', () {
    final provider = DroidExecProvider(
      runner: (executable, args, timeout) async => const DroidProcessResult(
        stdout: '',
        stderr: 'Error during droid execution: Exec failed',
        exitCode: 1,
      ),
    );
    expect(
      () => provider.generate(prompt: 'hi', model: 'custom:gpt-5.5---Codex'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(
            contains('Droid session log'),
            contains('custom/BYOK model'),
            contains('gpt-5.5'),
            contains('gpt-5.3-codex'),
          ),
        ),
      ),
    );
  });

  test(
    'failure diagnostics omit prompt text and local environment paths',
    () async {
      final provider = DroidExecProvider(
        droidPath: '/home/dev/private/bin/droid',
        runner: (executable, args, timeout) async => const DroidProcessResult(
          stdout: '',
          stderr: 'something went wrong',
          exitCode: 1,
        ),
      );

      try {
        await provider.generate(
          prompt: 'prompt-secret-content',
          model: 'gpt-5.5',
        );
        fail('Expected provider.generate to throw.');
      } on Object catch (error) {
        final message = error.toString();
        expect(message, contains('droid exec failed'));
        expect(message, contains('configured droid executable'));
        expect(message, contains('promptLen'));
        expect(message, isNot(contains('prompt-secret-content')));
        expect(message, isNot(contains('/home/dev/private')));
        expect(message, isNot(contains('shell cmd')));
        expect(message, isNot(contains('TMPDIR')));
        expect(message, isNot(contains('HOME')));
        expect(message, isNot(contains('PATH')));
      }
    },
  );

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
    'generate scrubs denied environment keys from droid exec',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_droid_env_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final fakeDroid = File(p.join(root.path, 'fake_droid_env.sh'));
      await fakeDroid.writeAsString('''
#!/bin/sh
env > '${p.join(root.path, 'env.txt')}'
''');
      final chmod = await Process.run('chmod', ['+x', fakeDroid.path]);
      expect(chmod.exitCode, 0);

      final provider = DroidExecProvider(
        droidPath: fakeDroid.path,
        deniedEnvironmentKeys: const ['HOME'],
      );
      await provider.generate(prompt: 'Generate a function.', model: 'fake');

      final env = await File(p.join(root.path, 'env.txt')).readAsString();
      expect(
        env.split('\n').where((line) => line.startsWith('HOME=')),
        isEmpty,
      );
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
  );

  test(
    'generate kills output-flooding droid exec process',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'dart_arena_droid_output_flood_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final fakeDroid = File(p.join(root.path, 'fake_droid_flood.sh'));
      await fakeDroid.writeAsString('''
#!/bin/sh
while :; do
  printf '0123456789abcdef0123456789abcdef\\n'
done
''');
      final chmod = await Process.run('chmod', ['+x', fakeDroid.path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr.toString());

      final provider = DroidExecProvider(
        droidPath: fakeDroid.path,
        maxProcessOutputChars: 128,
      );

      await expectLater(
        provider.generate(
          prompt: 'Generate a function.',
          model: 'fake',
          timeout: const Duration(seconds: 5),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('droid exec output exceeded 128 characters'),
              contains('stdout (128B)'),
            ),
          ),
        ),
      );
    },
    skip: Platform.isWindows ? 'POSIX shell script test' : false,
    timeout: const Timeout(Duration(seconds: 8)),
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
sleep 20 && echo done >> '${marker.path}'
''');
  final chmod = await Process.run('chmod', ['+x', script.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return script;
}
