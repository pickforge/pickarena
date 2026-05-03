import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    final tmp = Directory('/tmp/dart_arena_smoke_${DateTime.now().microsecondsSinceEpoch}')
      ..createSync(recursive: true);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    await tester.pumpWidget(App(
      database: db,
      workdir: WorkdirManager(root: tmp),
      settings: SettingsRepository(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('dart_arena'), findsOneWidget);
  });
}
