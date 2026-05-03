import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs.name is writable and readable', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r1',
            startedAt: DateTime(2026, 5, 2),
            name: const Value('my-run'),
          ),
        );

    final all = await db.select(db.runs).get();
    expect(all, hasLength(1));
    expect(all.first.id, 'r1');
    expect(all.first.name, 'my-run');

    await db.close();
  });

  test('runs.name is nullable (existing rows have no name)', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db.into(db.runs).insert(
          RunsCompanion.insert(
            id: 'r2',
            startedAt: DateTime(2026, 5, 2),
          ),
        );

    final row = await (db.select(db.runs)
          ..where((r) => r.id.equals('r2')))
        .getSingle();
    expect(row.name, isNull);

    await db.close();
  });

  test('schemaVersion is 3', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 3);
    await db.close();
  });
}
