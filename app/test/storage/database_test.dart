import 'package:dart_arena/storage/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('insert and read a Run', () async {
    final db = AppDatabase(NativeDatabase.memory());

    await db
        .into(db.runs)
        .insert(
          RunsCompanion.insert(id: 'r1', startedAt: DateTime(2026, 5, 2)),
        );
    final all = await db.select(db.runs).get();
    expect(all, hasLength(1));
    expect(all.first.id, 'r1');

    await db.close();
  });
}
