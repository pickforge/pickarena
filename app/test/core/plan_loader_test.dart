import 'dart:io';

import 'package:dart_arena/core/plan_loader.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'PlanLoader.load returns a ReferencePlan with filesystem text',
    () async {
      final root = await Directory.systemTemp.createTemp('plan_loader_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final file = File(p.join(root.path, 'plans/reference.v1.md'));
      await file.create(recursive: true);
      await file.writeAsString('Use the filesystem-backed plan.\n');

      final plan = await PlanLoader.load(
        assetPath: 'plans/reference.v1.md',
        version: 1,
        repoRoot: root.path,
      );

      expect(plan.version, 1);
      expect(plan.markdown, contains('filesystem-backed plan'));
    },
  );

  test('PlanLoader throws when the filesystem path is missing', () async {
    final root = await Directory.systemTemp.createTemp('plan_missing_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    await expectLater(
      PlanLoader.load(
        assetPath: 'plans/missing.md',
        version: 1,
        repoRoot: root.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
