# dart_arena — Plan 3 Spec: Evaluators, Weighted Scoring, Judge Config

**Date:** 2026-05-02
**Status:** Draft, awaiting user review
**Predecessors:** Plan 1 (foundation + first slice), Plan 2 (cloud providers) — both fully implemented.

---

## 1. Goal

Move the benchmark from a single pass/fail compile signal to a multi-dimensional, weighted quality score. After Plan 3, every task run produces multiple `EvaluationResult`s (compile, analyze, test, optionally widget-tree, judge, diff-size), aggregated into a weighted score, with the LLM judge model configurable per run from Settings.

This unblocks Plan 4 (the 9 remaining tasks + multi-task UI + leaderboard/dashboard) by ensuring the new tasks can be authored against a complete evaluator set without retro-fitting infrastructure.

## 2. Non-goals (Plan 3)

- The 9 additional benchmark tasks (Plan 4)
- Multi-task selection UI (Plan 4)
- Leaderboard / dashboard / run-details UI (Plan 4)
- A Settings UI to edit evaluator weights (Plan 4 — storage hooks land now, the editor lands then)
- Schema migration in the Drift DB (none required)

## 3. Architecture changes

### 3.1 Workdir prepare step

`lib/runner/workdir_manager.dart` gains a `prepare` method:

```dart
sealed class PrepareResult {
  const PrepareResult();
}

class PrepareOk extends PrepareResult {
  const PrepareOk();
}

class PrepareFailed extends PrepareResult {
  const PrepareFailed(this.stderr);
  final String stderr;
}

class WorkdirManager {
  // ... existing fields and methods ...

  Future<PrepareResult> prepare(Directory workDir) async {
    // dart pub get --offline, fall back to dart pub get on failure
  }
}
```

The implementation runs `dart pub get --offline`, falling back to `dart pub get` on failure, returning `PrepareFailed(stderr)` if both fail. This logic moves out of `CompileEvaluator`.

### 3.2 RunBloc lifecycle (per task run)

```
1. WorkdirManager.createTaskWorkdir(...)               (existing)
2. WorkdirManager.prepare(dir)                         (NEW)
3. If PrepareFailed: emit one synthetic EvaluationResult
   per evaluator declared by the task with
   passed=false, score=0, rationale='prepare failed',
   details={stderr}. Skip running them.
4. Else iterate task.evaluatorsFor(config) sequentially.
5. Aggregate via core/scoring.aggregate(results, weights).
```

### 3.3 Scoring

`lib/core/scoring.dart` (NEW):

```dart
const Map<String, double> defaultEvaluatorWeights = {
  'compile':     0.5,
  'analyze':     0.5,
  'test':        1.0,
  'widget_tree': 1.0,
  'llm_judge':   0.7,
  'diff_size':   0.3,
};

double aggregate(
  List<EvaluationResult> results,
  Map<String, double> weights,
) {
  if (results.isEmpty) return 0.0;
  var num = 0.0, den = 0.0;
  for (final r in results) {
    final w = weights[r.evaluatorId] ?? 1.0;
    num += r.score * w;
    den += w;
  }
  return den == 0 ? 0.0 : num / den;
}
```

Pure function, easy to unit-test. The `RunBloc` reads merged weights from `SettingsRepository.getEvaluatorWeights()` (defaults ∪ overrides) and passes them in.

### 3.4 BenchmarkTask interface evolution

`lib/core/benchmark_task.dart` changes:

```dart
abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures;
  String? get judgeRubric;
  String get generatedCodePath;             // NEW: e.g. 'lib/pagination.dart'
  List<Evaluator> evaluatorsFor(EvaluatorConfig config); // CHANGED
}
```

`lib/core/evaluator_config.dart` (NEW):

```dart
class EvaluatorConfig {
  const EvaluatorConfig({this.judgeProvider, this.judgeModel});

  final ModelProvider? judgeProvider;
  final String? judgeModel;

  bool get hasJudge => judgeProvider != null && judgeModel != null;
}
```

The hardcoded `'lib/pagination.dart'` write-path in `RunBloc` is replaced with `task.generatedCodePath` so each task can target its own file (necessary for Plan 4).

## 4. The 5 new evaluators

### 4.1 `AnalyzeEvaluator` (`lib/evaluators/analyze_evaluator.dart`)

- Runs `dart analyze` (no `--fatal-infos`).
- Parses stdout for severity lines (`error`, `warning`, `info`).
- Score: `errors > 0 → 0.0`. Else `score = clamp(1 - 0.10*warnings - 0.02*infos, 0, 1)`.
- `passed = (errors == 0)`.
- `details: {errors, warnings, infos, raw_stdout}`.

### 4.2 `TestEvaluator` (`lib/evaluators/test_evaluator.dart`)

- Runs `dart test --reporter=json`.
- Parses JSON-line events; counts `success` / `failure` / `error` from `testDone` events.
- Score: `passed_tests / total_tests` (0.0 when total = 0).
- `passed = (score == 1.0 && total > 0)`.
- `details: {total, passed, failed, errored, failures: [{name, message}]}`.

### 4.3 `WidgetTreeEvaluator` (`lib/evaluators/widget_tree_evaluator.dart`)

- Constructor: `WidgetTreeEvaluator({String testDir = 'test/widget'})`.
- Runs `flutter test <testDir> --reporter=json`.
- Same JSON parsing as `TestEvaluator` (shared via private helper file `_test_reporter_parser.dart`).
- Different `id` (`widget_tree`) so it gets its own weight.
- Same scoring shape as `TestEvaluator`.

### 4.4 `LlmJudgeEvaluator` (`lib/evaluators/llm_judge_evaluator.dart`)

```dart
class LlmJudgeEvaluator implements Evaluator {
  LlmJudgeEvaluator({required this.judge, required this.judgeModel});

  final ModelProvider judge;
  final String judgeModel;

  @override
  String get id => 'llm_judge';
}
```

Behavior:
- If `ctx.task.judgeRubric == null` → returns `EvaluationResult(passed:true, score:1.0, rationale:'no rubric')`. This makes the judge a no-op for tasks that don't opt in, so it doesn't drag down their aggregates.
- Otherwise builds the prompt:
  ```
  You are a strict code reviewer for Dart/Flutter.

  TASK PROMPT:
  <ctx.task.prompt>

  RUBRIC:
  <ctx.task.judgeRubric>

  SUBMISSION:
  ```dart
  <ctx.response.extractedCode ?? ctx.response.rawText>
  ```

  Reply with ONLY a fenced ```json block of the form:
  {"score": <number 0.0-1.0>, "rationale": "<short reasoning>"}
  ```
- Calls `judge.generate(prompt: prompt, model: judgeModel, timeout: const Duration(seconds: 60))`.
- Parses with a new helper `extractJsonBlock(String raw)` (mirrors `extractDartCode`) → `jsonDecode`.
- On JSON failure: regex fallback `RegExp(r'(?i)score[:\s]+([0-9.]+)')`; rationale = first 500 chars of raw.
- Score is clamped to `[0, 1]`. `passed = score >= 0.5`.
- `details: {raw_judge_response, judge_model, judge_provider_id}`.

### 4.5 `DiffSizeEvaluator` (`lib/evaluators/diff_size_evaluator.dart`)

```dart
class DiffSizeEvaluator implements Evaluator {
  DiffSizeEvaluator({required this.originalFixturePath, this.k = 20});

  final String originalFixturePath;
  final int k;

  @override
  String get id => 'diff_size';
}
```

Behavior:
- Reads original from `ctx.task.fixtures[originalFixturePath]`.
- Reads post-splice contents from `File(p.join(ctx.workDir.path, originalFixturePath))`.
- Uses `package:diff_match_patch` (added in Task 1) to compute line-level diffs; `changedLines = inserts + deletes`.
- Score: `score = math.exp(-changedLines / k)` (using `dart:math`). With `k = 20`: 0 changes → 1.0, 20 changes → ~0.37, 60 changes → ~0.05.
- `passed = score >= 0.3`.
- `details: {original_lines, new_lines, changed_lines, score_k}`.
- If the splice file doesn't exist or fixture is missing → `passed=false, score=0, rationale='diff source missing'`.

## 5. CompileEvaluator slimming

Plan 1's `CompileEvaluator` did pub-get + analyze (`--fatal-infos`) + test in one shot. Plan 3 splits these:

- `pub get` → `WorkdirManager.prepare`
- `dart analyze --fatal-infos` → `CompileEvaluator` (parse / type errors only; no warning grading)
- full `dart analyze` grading → `AnalyzeEvaluator`
- `dart test` → `TestEvaluator`

`CompileEvaluator` becomes ~20 lines: run `dart analyze --fatal-infos`; pass = exit-0; score = 1 if pass else 0.

## 6. Settings & UI changes

### 6.1 `lib/storage/settings.dart` additions

```dart
Future<String?> getJudgeProviderId();
Future<void>    setJudgeProviderId(String? providerId);

Future<String?> getJudgeModelId();
Future<void>    setJudgeModelId(String? modelId);

Future<Map<String, double>> getEvaluatorWeights(); // defaults ∪ overrides
Future<void>                setEvaluatorWeights(Map<String, double> overrides);
```

Storage keys (in flutter_secure_storage):
- `judge_provider_id`
- `judge_model_id`
- `evaluator_weights_json` (JSON object of override weights; empty/absent → defaults)

### 6.2 Settings page

`lib/ui/pages/settings_page.dart` gains a "Judge Model" section:
- Dropdown of currently-enabled providers (from `buildEnabledProviders`).
- Free-text field for model id (no model-list call to keep the page simple).
- Save persists both via `SettingsRepository`.

The evaluator-weights editor is explicitly deferred to Plan 4. The storage hook exists so Plan 4 only adds UI.

### 6.3 NewRunPage

No new widgets. `_startRun()` is extended to:
1. Read `judgeProviderId` + `judgeModelId` from settings.
2. Look up the matching `ModelProvider` from `buildEnabledProviders(...)` (silently skip judge if not found).
3. Build an `EvaluatorConfig` and include it in the `StartRun` event.

### 6.4 RunEvent

`lib/runner/run_event.dart` — `StartRun` gains:
```dart
final EvaluatorConfig evaluatorConfig;
```

## 7. Storage

No schema changes. `task_runs.aggregate_score` keeps its existing shape — only the value's *computation* changes (weighted vs naive average). The `evaluations` table absorbs five extra rows per task run.

## 8. Testing strategy

One unit test file per new evaluator + one for scoring + an extension to `run_bloc_test.dart`.

| Test file | Coverage |
|-----------|----------|
| `test/core/scoring_test.dart` | empty list (0.0), single evaluator, weighted average, missing weight → 1.0 default |
| `test/evaluators/analyze_evaluator_test.dart` | clean (1.0), 2 warnings (~0.8), 1 error (0.0) |
| `test/evaluators/test_evaluator_test.dart` | all-pass (1.0), 2/3 pass (~0.67), no tests (0.0) |
| `test/evaluators/widget_tree_evaluator_test.dart` | one passing widget test (1.0), tagged `flutter` for slow runs |
| `test/evaluators/llm_judge_evaluator_test.dart` | mocked judge: JSON happy path, regex fallback, skip when no rubric |
| `test/evaluators/diff_size_evaluator_test.dart` | identical (1.0), 5 changes, 30 changes, file missing |
| `test/runner/run_bloc_test.dart` (extended) | prepare-failure short-circuits all evaluators with synthetic results |

All evaluator tests use a real `Directory.systemTemp` and clean up.

## 9. File map

### Created

- `lib/core/scoring.dart`
- `lib/core/evaluator_config.dart`
- `lib/evaluators/analyze_evaluator.dart`
- `lib/evaluators/test_evaluator.dart`
- `lib/evaluators/widget_tree_evaluator.dart`
- `lib/evaluators/llm_judge_evaluator.dart`
- `lib/evaluators/diff_size_evaluator.dart`
- `lib/evaluators/_test_reporter_parser.dart` (private helper shared by Test/WidgetTree)
- `test/core/scoring_test.dart`
- `test/evaluators/analyze_evaluator_test.dart`
- `test/evaluators/test_evaluator_test.dart`
- `test/evaluators/widget_tree_evaluator_test.dart`
- `test/evaluators/llm_judge_evaluator_test.dart`
- `test/evaluators/diff_size_evaluator_test.dart`

### Modified

- `pubspec.yaml` — add `diff_match_patch: ^0.4.1`
- `lib/core/benchmark_task.dart` — `evaluators` → `evaluatorsFor(EvaluatorConfig)`; add `generatedCodePath`
- `lib/core/code_extractor.dart` — add `String? extractJsonBlock(String raw)`
- `lib/runner/workdir_manager.dart` — add `prepare(Directory)`
- `lib/runner/run_bloc.dart` — call `prepare`; carry `EvaluatorConfig`; aggregate via `scoring.dart`; use `task.generatedCodePath`
- `lib/runner/run_event.dart` — `StartRun` adds `evaluatorConfig`
- `lib/storage/settings.dart` — judge provider/model + evaluator weights accessors
- `lib/evaluators/compile_evaluator.dart` — slim down to `dart analyze --fatal-infos`
- `lib/tasks/bug_fix/off_by_one_pagination.dart` — implement `evaluatorsFor` (Compile + Analyze + Test + LlmJudge + DiffSize); add `generatedCodePath = 'lib/pagination.dart'`; populate `judgeRubric` with a short rubric so the judge actually runs on this task
- `lib/ui/pages/settings_page.dart` — Judge Model section
- `lib/ui/pages/new_run_page.dart` — read judge config + pass `EvaluatorConfig` through `StartRun`
- `test/runner/run_bloc_test.dart` — extended for prepare-failure path

## 10. Done criteria

- `flutter analyze` passes with strict-casts/strict-inference.
- `flutter test` passes all tests (existing + 6 new evaluator/scoring suites + extended bloc tests).
- A manual smoke run against Ollama Local on `bug.off_by_one_pagination` produces a `TaskRunResult` with **5 EvaluationResults when a judge is configured** (Compile, Analyze, Test, LlmJudge, DiffSize) — or 4 if no judge is configured — and a non-zero weighted aggregate score.
- The Settings page persists the judge model selection across app restarts.
- All commits land on `master`.

## 11. Risks & caveats

- **`flutter test` slowness:** `WidgetTreeEvaluator` spawning `flutter test` adds ~10-15s per task run. Tagged tests in this plan; in Plan 4 only widget tasks attach the evaluator.
- **Judge cost:** every task run with a configured judge spends real tokens on the judge model. Mitigation: rubric-less tasks short-circuit (cost = 0); judge is optional in `EvaluatorConfig`; users set it explicitly in Settings.
- **JSON-extraction brittleness:** weaker judge models may not honor the JSON-only instruction. Mitigation: regex fallback + `details.raw_judge_response` always logged for inspection.
- **Evaluator weight tuning:** the chosen defaults are first-pass guesses. Override storage exists immediately; the editor UI lands in Plan 4 once we have leaderboard signal to inform tuning.

## 12. After Plan 3 ships

Plan 4 is the natural next step: 9 new tasks across the 5 categories + multi-task selection UI on NewRunPage + the Dashboard / Leaderboard / RunDetails pages + the evaluator-weights editor in Settings.
