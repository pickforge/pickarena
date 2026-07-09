import 'package:dart_arena/core/benchmark_task.dart';

import 'plan_loader_io.dart';

class PlanLoader {
  static Future<ReferencePlan> load({
    required String assetPath,
    required int version,
    String? repoRoot,
  }) async {
    final markdown = await loadPlanMarkdown(
      assetPath: assetPath,
      repoRoot: repoRoot,
    );
    return ReferencePlan(version: version, markdown: markdown);
  }
}
