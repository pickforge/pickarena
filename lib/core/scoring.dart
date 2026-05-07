import 'dart:math' show sqrt;

import 'package:dart_arena/core/evaluation_result.dart';

const Map<String, double> defaultEvaluatorWeights = {
  'compile': 0.5,
  'analyze': 0.5,
  'test': 1.0,
  'test_author': 4.0,
  'widget_tree': 1.0,
  'llm_judge': 0.7,
  'diff_size': 0.3,
};

double aggregate(List<EvaluationResult> results, Map<String, double> weights) {
  if (results.isEmpty) return 0.0;
  var num = 0.0;
  var den = 0.0;
  for (final r in results) {
    final w = weights[r.evaluatorId] ?? 1.0;
    num += r.score * w;
    den += w;
  }
  return den == 0 ? 0.0 : num / den;
}

enum StageCombine { geometricMean, product, weightedSum }

double combineStages({
  required double planScore,
  required double executeScore,
  StageCombine mode = StageCombine.geometricMean,
}) {
  final p = planScore.clamp(0.01, 1.0);
  final e = executeScore.clamp(0.01, 1.0);
  return switch (mode) {
    StageCombine.geometricMean => sqrt(p * e),
    StageCombine.product => p * e,
    StageCombine.weightedSum => 0.5 * p + 0.5 * e,
  };
}
