import 'dart:io';

import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wm_dispatch_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('prepare uses dart pub get for non-Flutter projects', () async {
    final wd = Directory(p.join(tmp.path, 'plain'));
    await wd.create(recursive: true);
    await File(p.join(wd.path, 'pubspec.yaml')).writeAsString('''
name: plain
environment:
  sdk: ">=3.5.0 <4.0.0"
''');
    final mgr = WorkdirManager(root: tmp);
    final res = await mgr.prepare(wd, isFlutter: false);
    expect(res, isA<PrepareOk>());
  });
}
