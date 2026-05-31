# Plan — Add `coverage` Evaluator

## Files to create

1. `lib/coverage_evaluator.dart` — the implementation file. Single output.

## Implementation steps

1. Import the `Evaluator` interface and supporting types from `lib/evaluator.dart`.
2. Define `class CoverageEvaluator implements Evaluator`.
3. Override the `id` getter to return the string `'coverage'`.
4. Override `evaluate(EvaluationContext ctx)`:
   - For this Phase B slice, return a deterministic `EvaluationResult(id: 'coverage', score: 0.5)`.
   - Do not shell out to `dart test --coverage` yet. A future iteration can parse `lcov.info`; the deterministic score is enough to satisfy the acceptance contract.
5. Make the class exportable: top-level (no `_` prefix), no required constructor arguments.

## Tests to satisfy

`test/coverage_evaluator_test.dart` (already provided) asserts:

- `CoverageEvaluator` is assignable to `Evaluator`.
- `CoverageEvaluator().id == 'coverage'`.
- `evaluate(...)` returns an `EvaluationResult` with `id == 'coverage'` and `score` in `[0, 1]`.

## Output format

Return ONLY the contents of `lib/coverage_evaluator.dart` inside a single fenced Dart code block. Do not include any other files.
