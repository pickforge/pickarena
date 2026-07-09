import 'dart:io';

import 'package:dart_arena/evaluators/evaluator_process.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'resource probe helpers scrub sensitive environment variables',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_eval_probe_env_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
      final log = File(p.join(tmp.path, 'probe_env.log'));
      final tool = await _writeExecutable(
        bin,
        'fake_tool',
        '#!/bin/sh\nsleep 0.35\n',
      );
      await _writeExecutable(bin, 'pgrep', '#!/bin/sh\nexit 0\n');
      await _writeExecutable(bin, 'ps', '''
#!/bin/sh
{
  echo "SECRET_TOKEN=\${SECRET_TOKEN:-}"
  echo "HTTP_PROXY=\${HTTP_PROXY:-}"
  echo "NORMAL_VALUE=\${NORMAL_VALUE:-}"
} >> "\$LOG_PATH"
printf '1\\n'
''');

      final path = [
        bin.path,
        if ((Platform.environment['PATH'] ?? '').isNotEmpty)
          Platform.environment['PATH']!,
      ].join(':');
      final result = await runEvaluatorProcess(
        tool.path,
        const [],
        workingDirectory: tmp.path,
        environment: {'PATH': path},
        includeParentEnvironment: false,
        timeout: const Duration(seconds: 2),
        maxProcesses: 64,
        maxMemoryMb: 4096,
        helperBaseEnvironment: {
          'PATH': path,
          'LOG_PATH': log.path,
          'SECRET_TOKEN': 'secret-token-value',
          'HTTP_PROXY': 'http://proxy-secret.invalid',
          'NORMAL_VALUE': 'visible',
        },
      );

      expect(result.exitCode, 0);
      final probeLog = await log.readAsString();
      expect(probeLog, contains('NORMAL_VALUE=visible'));
      expect(probeLog, isNot(contains('secret-token-value')));
      expect(probeLog, isNot(contains('proxy-secret')));
    },
    skip: Platform.isWindows,
  );
}

Future<File> _writeExecutable(
  Directory directory,
  String name,
  String contents,
) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(contents);
  final chmod = await Process.run('chmod', ['+x', file.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return file;
}
