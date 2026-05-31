import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

QueryExecutor openDefaultDatabaseConnection() {
  return LazyDatabase(() async {
    final dir = Directory(p.join(Directory.current.path, '.dart_arena'));
    await dir.create(recursive: true);
    return NativeDatabase(File(p.join(dir.path, 'dart_arena.sqlite')));
  });
}
