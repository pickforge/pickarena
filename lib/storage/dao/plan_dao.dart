import 'package:dart_arena/storage/database.dart';
import 'package:drift/drift.dart';

class PlanDao {
  PlanDao(this._db);

  final AppDatabase _db;

  Future<String> upsertReferencePlan({
    required String taskId,
    required int version,
    required String artifact,
  }) async {
    final existing = await (_db.select(_db.plans)
          ..where((p) =>
              p.taskId.equals(taskId) & p.referenceVersion.equals(version))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = 'ref-$taskId-v$version';
    await _db.into(_db.plans).insert(
          PlansCompanion.insert(
            id: id,
            taskId: taskId,
            artifact: artifact,
            createdAt: DateTime.now(),
            referenceVersion: Value(version),
          ),
        );
    return id;
  }

  Future<String> insertModelPlan({
    required String taskId,
    required String plannerModelId,
    required String artifact,
  }) async {
    final id =
        'mp-$taskId-$plannerModelId-${DateTime.now().microsecondsSinceEpoch}';
    await _db.into(_db.plans).insert(
          PlansCompanion.insert(
            id: id,
            taskId: taskId,
            artifact: artifact,
            createdAt: DateTime.now(),
            plannerModelId: Value(plannerModelId),
          ),
        );
    return id;
  }

  Future<Plan?> planById(String id) {
    return (_db.select(_db.plans)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }
}
