import 'dart:io';

import 'package:dart_arena/core/patch_capture.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

Future<void> _git(Directory dir, List<String> args) async {
  final result = await Process.run('git', args, workingDirectory: dir.path);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      args,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}

void main() {
  test('captures binary-capable diff and porcelain status', () async {
    final root = await Directory.systemTemp.createTemp('patch_capture_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    await File(p.join(root.path, 'lib.dart')).writeAsString('int a = 1;\n');
    await _git(root, ['init']);
    await _git(root, ['config', 'user.email', 'test@example.invalid']);
    await _git(root, ['config', 'user.name', 'test']);
    await _git(root, ['add', '.']);
    await _git(root, ['commit', '-m', 'baseline']);

    await File(p.join(root.path, 'lib.dart')).writeAsString('int a = 2;\n');
    await File(p.join(root.path, 'new.dart')).writeAsString('int b = 3;\n');

    final result = await const PatchCapture().capture(root);

    expect(result.hasMeaningfulDiff, isTrue);
    expect(result.patch, contains('-int a = 1;'));
    expect(result.patch, contains('+int a = 2;'));
    expect(result.patch, contains('diff --git a/new.dart b/new.dart'));
    expect(result.patch, contains('+int b = 3;'));
    expect(result.status, contains('M lib.dart'));
    expect(result.status, contains(' A new.dart'));
  });

  test(
    'scrubs sensitive environment variables from git subprocesses',
    () async {
      final root = await Directory.systemTemp.createTemp('patch_capture_env_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final log = File(p.join(root.path, 'git_env.log'));
      final fakeGit = await _writeExecutable(root, 'fake_git', '''
#!/bin/sh
{
  echo "SECRET_TOKEN=\${SECRET_TOKEN:-}"
  echo "HTTP_PROXY=\${HTTP_PROXY:-}"
  echo "HOME=\${HOME:-}"
  echo "NORMAL_VALUE=\${NORMAL_VALUE:-}"
  echo "GIT_CONFIG_NOSYSTEM=\${GIT_CONFIG_NOSYSTEM:-}"
  echo "GIT_TERMINAL_PROMPT=\${GIT_TERMINAL_PROMPT:-}"
} >> "\$LOG_PATH"
if [ "\$1" = "status" ]; then
  printf ' M lib.dart\\n'
  exit 0
fi
if [ "\$1" = "diff" ]; then
  printf 'diff --git a/lib.dart b/lib.dart\\n'
  exit 0
fi
exit 0
''');

      final result = await PatchCapture(
        gitExecutable: fakeGit.path,
        baseEnvironment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'LOG_PATH': log.path,
          'SECRET_TOKEN': 'secret-token-value',
          'HTTP_PROXY': 'http://proxy-secret.invalid',
          'HOME': '/home/secret-user',
          'NORMAL_VALUE': 'visible',
        },
      ).capture(root);

      expect(result.hasMeaningfulDiff, isTrue);
      expect(result.status, contains('M lib.dart'));
      final gitLog = await log.readAsString();
      expect(gitLog, contains('NORMAL_VALUE=visible'));
      expect(gitLog, contains('GIT_CONFIG_NOSYSTEM=1'));
      expect(gitLog, contains('GIT_TERMINAL_PROMPT=0'));
      expect(gitLog, isNot(contains('secret-token-value')));
      expect(gitLog, isNot(contains('proxy-secret')));
      expect(gitLog, isNot(contains('/home/secret-user')));
    },
    skip: Platform.isWindows,
  );

  test(
    'fails fast when git diff output exceeds the capture limit',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'patch_capture_output_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final fakeGit = await _writeExecutable(root, 'fake_git_output', '''
#!/bin/sh
if [ "\$1" = "status" ]; then
  printf ' M lib.dart\\n'
  exit 0
fi
if [ "\$1" = "diff" ]; then
  i=0
  while [ "\$i" -lt 64 ]; do
    printf '0123456789abcdef'
    i=\$((i + 1))
  done
  exit 0
fi
exit 0
''');

      expect(
        () => PatchCapture(
          gitExecutable: fakeGit.path,
          maxOutputChars: 32,
        ).capture(root),
        throwsA(
          isA<ProcessException>().having(
            (error) => error.message,
            'message',
            contains('patch capture git output exceeded 32 characters'),
          ),
        ),
      );
    },
    skip: Platform.isWindows,
  );

  test('terminates git child processes after output limit', () async {
    final root = await Directory.systemTemp.createTemp(
      'patch_capture_children_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final marker = File(p.join(root.path, 'child_survived'));
    final fakeGit = await _writeExecutable(root, 'fake_git_children', '''
#!/bin/sh
if [ "\$1" = "status" ]; then
  printf ' M lib.dart\\n'
  exit 0
fi
if [ "\$1" = "diff" ]; then
  (sleep 1; printf survived > "\$MARKER_PATH") &
  i=0
  while [ "\$i" -lt 4096 ]; do
    printf '0123456789abcdef'
    i=\$((i + 1))
  done
  sleep 5
  exit 0
fi
exit 0
''');

    await expectLater(
      () => PatchCapture(
        gitExecutable: fakeGit.path,
        baseEnvironment: {
          'PATH': Platform.environment['PATH'] ?? '',
          'MARKER_PATH': marker.path,
        },
        maxOutputChars: 32,
      ).capture(root),
      throwsA(isA<ProcessException>()),
    );

    await Future<void>.delayed(const Duration(seconds: 2));
    expect(await marker.exists(), isFalse);
  }, skip: Platform.isWindows);
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
