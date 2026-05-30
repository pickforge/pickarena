import 'dart:io';

import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  Future<Directory> makeRoot() async {
    final dir = await Directory.systemTemp.createTemp('tmpdir_mgr_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    return dir;
  }

  test('currentSize returns 0 for an empty dir', () async {
    final root = await makeRoot();
    final mgr = TmpDirManager(root: root);
    expect(await mgr.currentSize(), 0);
  });

  test('currentSize returns 0 when root does not exist', () async {
    final root = await makeRoot();
    await root.delete(recursive: true);
    final mgr = TmpDirManager(root: root);
    expect(await mgr.currentSize(), 0);
  });

  test('currentSize sums file sizes', () async {
    final root = await makeRoot();
    await File(p.join(root.path, 'a')).writeAsBytes(List.filled(100, 0));
    await File(p.join(root.path, 'b')).writeAsBytes(List.filled(250, 0));
    final mgr = TmpDirManager(root: root);
    expect(await mgr.currentSize(), 350);
  });

  test('currentSize recurses into subdirs', () async {
    final root = await makeRoot();
    final sub = Directory(p.join(root.path, 'sub'))..createSync();
    await File(p.join(root.path, 'a')).writeAsBytes(List.filled(50, 0));
    await File(p.join(sub.path, 'b')).writeAsBytes(List.filled(75, 0));
    final mgr = TmpDirManager(root: root);
    expect(await mgr.currentSize(), 125);
  });

  test('currentSize does not follow symlinks', () async {
    final root = await makeRoot();
    final outside = await Directory.systemTemp.createTemp(
      'tmpdir_mgr_outside_',
    );
    addTearDown(() async {
      if (await outside.exists()) {
        await outside.delete(recursive: true);
      }
    });
    await File(p.join(outside.path, 'big')).writeAsBytes(List.filled(1000, 0));
    try {
      Link(p.join(root.path, 'link')).createSync(outside.path);
    } on FileSystemException {
      return;
    }
    await File(p.join(root.path, 'a')).writeAsBytes(List.filled(40, 0));
    final mgr = TmpDirManager(root: root);
    expect(await mgr.currentSize(), 40);
  });

  test('sweep deletes top-level entries older than maxAge', () async {
    final root = await makeRoot();
    final oldFile = File(p.join(root.path, 'old'))
      ..writeAsBytesSync(List.filled(10, 0));
    final newFile = File(p.join(root.path, 'new'))
      ..writeAsBytesSync(List.filled(10, 0));
    final ancient = DateTime.now().subtract(const Duration(days: 30));
    oldFile.setLastModifiedSync(ancient);

    final mgr = TmpDirManager(root: root, maxAge: const Duration(days: 7));
    await mgr.sweep();

    expect(oldFile.existsSync(), isFalse);
    expect(newFile.existsSync(), isTrue);
  });

  test('sweep retains entries newer than maxAge', () async {
    final root = await makeRoot();
    File(p.join(root.path, 'fresh')).writeAsBytesSync(List.filled(10, 0));
    final mgr = TmpDirManager(root: root, maxAge: const Duration(days: 7));
    await mgr.sweep();
    expect(File(p.join(root.path, 'fresh')).existsSync(), isTrue);
  });

  test('sweep with tight maxBytes deletes oldest entries first', () async {
    final root = await makeRoot();
    final a = File(p.join(root.path, 'a'))
      ..writeAsBytesSync(List.filled(500, 0));
    final b = File(p.join(root.path, 'b'))
      ..writeAsBytesSync(List.filled(500, 0));
    final c = File(p.join(root.path, 'c'))
      ..writeAsBytesSync(List.filled(500, 0));

    final now = DateTime.now();
    a.setLastModifiedSync(now.subtract(const Duration(minutes: 30)));
    b.setLastModifiedSync(now.subtract(const Duration(minutes: 20)));
    c.setLastModifiedSync(now.subtract(const Duration(minutes: 10)));

    final mgr = TmpDirManager(
      root: root,
      maxAge: const Duration(days: 365),
      maxBytes: 600,
    );
    await mgr.sweep();

    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isFalse);
    expect(c.existsSync(), isTrue);
  });

  test('sweep does not throw when root is missing', () async {
    final root = await makeRoot();
    await root.delete(recursive: true);
    final mgr = TmpDirManager(root: root);
    await mgr.sweep();
    expect(await root.exists(), isTrue);
  });

  test('clear empties root but leaves root in place', () async {
    final root = await makeRoot();
    File(p.join(root.path, 'a')).writeAsBytesSync(List.filled(10, 0));
    Directory(p.join(root.path, 'sub')).createSync();
    final mgr = TmpDirManager(root: root);
    await mgr.clear();
    expect(await root.exists(), isTrue);
    expect(await root.list().isEmpty, isTrue);
  });

  test('clear is a no-op on a missing root (creates it)', () async {
    final root = await makeRoot();
    await root.delete(recursive: true);
    final mgr = TmpDirManager(root: root);
    await mgr.clear();
    expect(await root.exists(), isTrue);
  });
}
