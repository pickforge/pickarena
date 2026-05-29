import 'dart:io';

import 'package:dart_arena/core/patch_capture.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
