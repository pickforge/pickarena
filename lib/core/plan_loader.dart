import 'package:dart_arena/core/benchmark_task.dart';

import 'plan_loader_io.dart' if (dart.library.ui) 'plan_loader_flutter.dart';

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
