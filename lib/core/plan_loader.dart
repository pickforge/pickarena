import 'package:dart_arena/core/benchmark_task.dart';
import 'package:flutter/services.dart';

class PlanLoader {
  static Future<ReferencePlan> load({
    required String assetPath,
    required int version,
  }) async {
    final markdown = await rootBundle.loadString(assetPath);
    return ReferencePlan(version: version, markdown: markdown);
  }
}
