import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/flutter_secure_settings_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final tmp = Directory(
      '/tmp/dart_arena_smoke_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final tmpCache = Directory(
      '/tmp/dart_arena_smoke_cache_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
      tmpCache.deleteSync(recursive: true);
    });

    await tester.pumpWidget(
      App(
        database: db,
        workdir: WorkdirManager(root: tmp),
        settings: FlutterSecureSettingsStore(),
        tmpDirManager: TmpDirManager(root: tmpCache),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PickArena'), findsOneWidget);
  });
}
