# dart_arena — Design Spec

**Date:** 2026-05-02
**Status:** Draft, awaiting user review

## 1. Goal

A desktop Flutter application that benchmarks LLMs on Flutter-specific coding tasks. For each (model, task) pair, the app submits a prompt to the model, captures the response, runs automated evaluators against the generated code (compile, analyze, tests), optionally rates subjective quality with an LLM-as-judge, persists results, and presents leaderboards so the user can decide which model is best per category and overall.

The user is a Flutter-first developer with active subscriptions to OpenCode Go (Zen), Ollama Cloud, and Factory Droid. The benchmark is for personal use, run locally on Linux desktop primarily.

## 2. Non-goals (v1)

- Mobile or web builds of the benchmark itself
- Multi-machine result sharing or cloud sync
- A managed SaaS dashboard
- Custom user-defined tasks via the UI (tasks are code-defined in v1)
- Cost-tracking dashboards (only basic token counts logged)
- Sandboxing of model-generated code beyond an ephemeral working directory
- Multi-turn / agentic harness benchmarks (Droid Agent Mode is wired as one provider, but each call is still treated as a single round-trip; full multi-turn evaluation is out of scope)

## 3. High-level architecture

Flutter desktop app (Linux primary, macOS/Windows best-effort), layered:

```
lib/
  core/           # Domain models: Task, Run, Score, ModelResponse, Category
  providers/      # ModelProvider implementations (one file per provider)
  tasks/          # Task classes self-registering into a TaskRegistry
  evaluators/     # Evaluator implementations
  runner/         # Orchestrates (model x task) matrix, manages workdirs
  storage/        # Drift (SQLite) data layer
  ui/             # BLoC-based UI: Dashboard, NewRun, RunProgress,
                  # RunDetails, Leaderboard, Settings
```

State management: **flutter_bloc** (Cubits for forms/dialogs, full Blocs for the run lifecycle).

## 4. Domain model

```dart
enum Category { uiFromSpec, stateManagement, bugFix, refactor, widgetTesting }

abstract class BenchmarkTask {
  String get id;
  Category get category;
  String get prompt;
  Map<String, String> get fixtures; // filename -> contents to splice in
  List<Evaluator> get evaluators;
  String? get judgeRubric; // optional, used by LlmJudgeEvaluator
}

class ModelResponse {
  final String rawText;
  final String? extractedCode;       // post-processed to ".dart" content
  final int? promptTokens;
  final int? completionTokens;
  final Duration latency;
}

class EvaluationResult {
  final String evaluatorId;
  final bool passed;
  final double score;        // 0.0 - 1.0
  final String? rationale;   // optional human-readable explanation
  final Map<String, dynamic> details;
}

class TaskRunResult {
  final String runId;
  final String providerId;
  final String modelId;
  final String taskId;
  final ModelResponse response;
  final List<EvaluationResult> evaluations;
  final double aggregateScore;
  final DateTime completedAt;
}
```

## 5. Providers

All providers conform to:

```dart
abstract class ModelProvider {
  String get id;                     // e.g. "opencode_zen"
  String get displayName;
  List<String> get availableModels;  // populated at runtime if possible
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}
```

**v1 ships with all of the following enabled (kitchen sink):**

| ID | Class | Mode | Auth |
|---|---|---|---|
| `opencode_zen` | `OpenCodeZenProvider` | Direct API (OpenAI-compatible) | API key from Go plan |
| `ollama_cloud` | `OllamaProvider` (cloud config) | Direct API (Ollama protocol) | API key |
| `ollama_local` | `OllamaProvider` (local config) | Direct API (Ollama protocol) | None (localhost) |
| `droid` | `DroidExecProvider` | Agent (shell-out to `droid exec`) | `FACTORY_API_KEY=fk_...` |
| `openrouter` | `OpenRouterProvider` | Direct API (OpenAI-compatible) | API key |
| `openai` | `OpenAIProvider` | Direct API | API key (NOT ChatGPT Plus) |
| `anthropic` | `AnthropicProvider` | Direct API (Messages API) | API key |
| `deepseek` | `DeepSeekProvider` | Direct API (OpenAI-compatible) | API key |

API keys are stored via `flutter_secure_storage`. A provider is **enabled in the UI only when its key is set** (or `ollama_local` reaches `localhost:11434`). Each provider declares whether it produces "raw" output or "agent-mediated" output; the leaderboard separates these so comparisons stay honest.

`DroidExecProvider.generate` shells out:

```bash
FACTORY_API_KEY=$key droid exec --auto low --model <m> "<prompt>"
```

and captures stdout. A response post-processor extracts the model's final code block.

## 6. Tasks (v1: 5 categories x 2 tasks = 10)

Tasks live in `lib/tasks/<category>/<id>.dart` and self-register into `TaskRegistry`.

Each category gets two tasks of differing difficulty. Working titles:

- **uiFromSpec**
  - `ui.profile_card`: build a profile card matching a textual spec
  - `ui.expandable_list_tile`: build an expandable list tile with animation
- **stateManagement**
  - `state.counter_bloc`: implement a counter with flutter_bloc
  - `state.shopping_cart_bloc`: implement add/remove/total with persistence stub
- **bugFix**
  - `bug.off_by_one_pagination`: fix pagination off-by-one in provided code
  - `bug.async_race_condition`: fix a setState-after-dispose race
- **refactor**
  - `refactor.god_widget`: split a 300-line widget into composable units
  - `refactor.callback_hell`: convert nested futures to async/await with error handling
- **widgetTesting**
  - `test.todo_input`: write widget tests for a TodoInput widget
  - `test.form_validation`: write tests covering a multi-field form's validation states

Adding tasks post-v1 = drop a new file in `lib/tasks/`.

## 7. Evaluators

```dart
abstract class Evaluator {
  String get id;
  Future<EvaluationResult> evaluate(EvaluationContext ctx);
}

class EvaluationContext {
  final Directory workDir;       // ephemeral project dir for this run
  final ModelResponse response;
  final BenchmarkTask task;
}
```

**v1 evaluators:**

| Evaluator | What it does |
|---|---|
| `CompileEvaluator` | `dart compile js` or `flutter build` (fastest mode); pass/fail |
| `AnalyzeEvaluator` | `flutter analyze` exit code, also counts warnings vs errors |
| `TestEvaluator` | `flutter test <fixtures>` — runs tests we ship per task |
| `WidgetTreeEvaluator` | Loads model's widget into a test harness, asserts via `find.byType` etc. (uiFromSpec) |
| `LlmJudgeEvaluator` | Sends model output + rubric to the configured judge model, parses score 0-1 + rationale |
| `DiffSizeEvaluator` | For bugFix/refactor: penalizes overly large diffs (favors minimal fixes) |

Each task picks the subset of evaluators relevant to it. Aggregate score is a weighted average; default weights live in `core/scoring.dart` and are tweakable from Settings.

The **judge model** is configurable per run (default: best Tier-1 model not in the contestant set). The judge must be a different family than the contestant whenever feasible to mitigate self-bias.

## 8. Runner & lifecycle

```
StartRun (event)
  --> Bloc validates: at least one model selected, at least one task selected
  --> Creates run dir: ~/.dart_arena/runs/<run-id>/
  --> For each task:
        For each (provider, model):
          1. Create workdir: <run-dir>/<provider>/<model>/<task-id>/
          2. Copy task fixtures into workdir (a minimal Flutter package skeleton + task files)
          3. Call provider.generate(prompt) -- emit ModelResponded
          4. Splice extracted code into expected file path(s)
          5. For each evaluator: run -- emit EvaluatorFinished events
          6. Persist TaskRunResult
  --> Emit RunCompleted, navigate to Run Details
```

Concurrency:
- Models for the same task run **sequentially** (fewer surprises, lower load)
- Tasks for the same model run sequentially (Flutter test runs don't parallelize cleanly without conflict)
- Across runs: only one run active at a time in v1

Cancellation: a Bloc-level cancel token aborts in-flight `Process.run` and HTTP calls.

## 9. Storage (Drift)

Tables:
- `runs(id, started_at, completed_at, judge_model)`
- `task_runs(id, run_id, provider_id, model_id, task_id, response_text, prompt_tokens, completion_tokens, latency_ms, aggregate_score, completed_at)`
- `evaluations(id, task_run_id, evaluator_id, passed, score, rationale, details_json)`
- `provider_keys` is **not** in the DB; keys live in secure storage only.

The DB lives at `~/.dart_arena/dart_arena.sqlite`.

## 10. UI

Pages (all using flutter_bloc):

1. **Dashboard** — recent runs, quick-glance leaderboard (top model per category).
2. **New Run** — multi-select models (grouped by provider), multi-select tasks (grouped by category), pick judge model, click Start.
3. **Run Progress** — live grid: rows = tasks, columns = (provider, model). Cells show spinner -> pass/fail icons -> aggregate score. Click a cell to drill into details mid-run.
4. **Run Details** — for one task run: raw model output, evaluator results, judge rationale, diff view of model's code vs fixtures.
5. **Leaderboard** — filters: category, provider, mode (raw vs agent-mediated), date range. Charts via `fl_chart` (bar per model, radar per category).
6. **Settings** — API key entry (per provider), default judge model, evaluator weights, Flutter SDK path override.

## 11. Tech stack

| Concern | Choice | Why |
|---|---|---|
| State management | `flutter_bloc` | User preference, well-suited for run lifecycle events |
| HTTP | `dio` | Interceptors useful for token logging and retries |
| DB | `drift` | Typed SQL, desktop support, codegen ergonomic |
| Secure storage | `flutter_secure_storage` | Cross-desktop, keychain-backed |
| Process spawn | `dart:io Process.run` / `Process.start` | Built-in |
| Charts | `fl_chart` | Good Flutter-native chart lib |
| Code highlighting (run details) | `flutter_highlight` | Show Dart with theming |
| Diff view | `flutter_difftree` or `diff_match_patch` | Compare model code vs fixtures |
| Logging | `logger` | Structured CLI/file logs |

## 12. Risks & caveats

- **API costs**: a full run (10 tasks x N models) burns real tokens. Mitigation: token-count display per run, concurrency cap, ability to dry-run with mock responses.
- **Sandboxing**: model-generated code runs locally via `flutter test`. Risk of malicious or buggy generated code. Mitigation v1: ephemeral workdirs + restricting Flutter execution to that dir; documented as a known risk. Future: containerization.
- **Slow evaluator loop**: `flutter analyze` + `flutter test` take 5-30s each. Total run time ~10 minutes for 10 tasks x 5 models. Mitigation: warm pub cache, persistent SDK path setting, progress UI to keep users informed.
- **LLM-judge bias**: judge may favor outputs from its own family. Mitigation: judge defaults to a different family than contestants; raw judge rationale is shown for inspection.
- **Agent-mode comparison fairness**: `DroidExecProvider` outputs are agent-shaped (multi-step tool use). Comparing them to raw API outputs in the same leaderboard is misleading. Mitigation: leaderboard explicitly separates "Raw API" and "Agent" views; mixing requires an explicit toggle.
- **Token-count accuracy**: not all providers expose usage. When missing, show "n/a" rather than fabricate.

## 13. v1 scope summary

- Flutter desktop (Linux primary)
- All Tier 1 + Tier 2 providers wired in (8 providers); each enabled when a key is present
- 5 categories x 2 tasks = 10 tasks
- 6 evaluator types; per-task subset
- BLoC architecture, Drift DB, secure storage for keys
- Local only; no cloud sync

## 14. Future expansions (explicit non-v1)

- More tasks (target 5-10 per category)
- Web companion for browsing run results
- Container sandboxing for generated code
- Custom user-defined tasks via UI
- Multi-turn / full agentic harness mode
- Cost-tracking dashboards with provider pricing tables
- Cross-machine result sync (e.g., GitHub-backed)

## 15. Open questions for user

None blocking. Will surface during the implementation-planning phase.
