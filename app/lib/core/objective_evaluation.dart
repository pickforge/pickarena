import 'package:dart_arena/analytics/result_primitives.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_blocking.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/evaluators/evaluator.dart';

/// Builds the [EvaluationContext] each evaluator runs with, given the
/// ordered results observed so far. Track-specific preparation (sandbox,
/// process, patch replay, harness, workdir policy) stays with the caller;
/// this module only owns the ordered choreography around it.
typedef ObjectiveEvaluationContextBuilder =
    EvaluationContext Function(List<EvaluationResult> previousResults);

/// Runs [evaluators] in order against [evaluations], inserting a blocked
/// placeholder (via [blockedEvaluationFor]) instead of invoking an evaluator
/// once a hard blocker (environment/harness failure, or a compile failure
/// for runtime evaluators) has been observed. Each evaluator sees every
/// prior result, including blocked placeholders, as `previousResults`.
///
/// [evaluations] is mutated in place and returned so callers can seed it
/// with results that must be visible to the first evaluator (for example an
/// agent-harness result or a patch-capture failure).
Future<List<EvaluationResult>> runObjectiveEvaluators({
  required Iterable<Evaluator> evaluators,
  required List<EvaluationResult> evaluations,
  required ObjectiveEvaluationContextBuilder contextFor,
  void Function()? cancellationCheck,
}) async {
  for (final evaluator in evaluators) {
    cancellationCheck?.call();
    final blocked = blockedEvaluationFor(
      evaluatorId: evaluator.id,
      previousResults: evaluations,
    );
    if (blocked != null) {
      evaluations.add(blocked);
      continue;
    }
    final result = await evaluator.evaluate(contextFor(evaluations));
    cancellationCheck?.call();
    evaluations.add(result);
  }
  return evaluations;
}

/// Records a hard failure ([failure]) that blocks every remaining
/// [evaluators] from running, inserting a blocked placeholder for each of
/// them. If [evaluations] already carries a hard downstream blocker (see
/// [hasHardDownstreamBlocker]), [failure] is not appended again; the
/// blocked placeholders still record the earlier blocker as their cause.
///
/// [evaluations] is mutated in place and returned.
List<EvaluationResult> blockEvaluatorsForHardFailure({
  required List<EvaluationResult> evaluations,
  required Iterable<Evaluator> evaluators,
  required EvaluationResult? failure,
}) {
  if (failure != null && !hasHardDownstreamBlocker(evaluations)) {
    evaluations.add(failure);
  }
  for (final evaluator in evaluators) {
    evaluations.add(
      blockedEvaluationFor(
        evaluatorId: evaluator.id,
        previousResults: evaluations,
        blockAllDownstream: true,
      )!,
    );
  }
  return evaluations;
}

/// The aggregate score and primary-pass/failure-tag primitives derived from
/// a completed objective evaluation.
class ObjectiveEvaluationOutcome {
  const ObjectiveEvaluationOutcome({
    required this.evaluations,
    required this.aggregateScore,
    required this.primaryPass,
    required this.failureTag,
  });

  final List<EvaluationResult> evaluations;
  final double aggregateScore;
  final bool primaryPass;
  final String failureTag;
}

/// Derives the aggregate score and primary-pass/failure-tag primitives for
/// [evaluations], using [weights] for aggregation and [response] (when
/// available) for output-presence failure tagging.
ObjectiveEvaluationOutcome finalizeObjectiveEvaluation({
  required List<EvaluationResult> evaluations,
  required Map<String, double> weights,
  ModelResponse? response,
}) {
  final aggregateScore = aggregate(evaluations, weights);
  final primitives = determineResultPrimitives(
    evaluations: evaluations,
    aggregateScore: aggregateScore,
    response: response,
  );
  return ObjectiveEvaluationOutcome(
    evaluations: evaluations,
    aggregateScore: aggregateScore,
    primaryPass: primitives.primaryPass,
    failureTag: primitives.failureTag,
  );
}
