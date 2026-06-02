# Dart Arena by Pickforge — Master Spec

Status: active consolidated master spec
Created: 2026-05-31
Updated: 2026-06-02

## Goal

Create a trustworthy Dart and Flutter AI coding benchmark under the Pickforge brand, with the Flutter/Dart app as the benchmark runner and source of truth, a static public web surface for leaderboard publishing, objective-first scoring, reproducible exports, cost/efficiency reporting, and DeepSWE-style task/verifier rigor.

## Current status and execution posture

This file is the single active master spec. It is both the product direction and the implementation roadmap.

Completed foundation:

- Flutter app lives under `app/` and remains the benchmark runner/source of truth.
- Static web app lives under `web/` and consumes exported leaderboard JSON rather than the internal database.
- Headless codegen CLI exists.
- Headless agentic CLI parity exists for Droid-backed agentic tasks.
- Leaderboard export CLI exists.
- Objective scoring and LLM judge gating are in place.
- Safe prompt API/skeleton context exists for codegen tasks.
- Initial task QA exists for reference/baseline/hidden verifier checks.
- File-backed task bundle loading exists for DeepSWE-style task authoring experiments.
- Headless runs can load file-backed task bundles with `taskBundleRoots`.
- Public-vs-hidden pass splits are exported and rendered by the static web leaderboard.
- Generated-code evaluator subprocesses scrub unrelated environment variables by default.
- Cost estimation has candidate-model summaries, unknown-cost counts, and cost-per-pass export fields.
- Active specs have been consolidated into this master spec; older specs/plans are archived under `docs/**/old/`.

Current recommendation:

1. Treat **Phase 0** as completed foundation.
2. Implement **Phase 1: Blocked evaluator semantics** next; it remains the largest UX/scoring gap.
3. Promote the new file-backed loader from infrastructure to official corpus work by adding 5-10 real Flutter agentic tasks and QA reports.
4. Finish stronger public-run sandboxing before any official public/private leaderboard release.
5. Add judge-overhead cost tracking and pricing-registry provenance before official efficiency claims.

Official benchmark status: **not release-grade yet**. The app is useful for local/internal comparison, but official public claims should wait until task admission, sandboxing, repeated trials, and release provenance are stronger.

## How to use this spec

- Each roadmap phase should be implemented as a focused branch/worktree.
- Each phase should produce tests, updated exports/UI where relevant, and a short note in this spec if scope changes.
- Do not create new active specs for sub-work unless the task is large enough to need a temporary implementation plan under `docs/plans/`.
- Completed/superseded implementation plans go to `docs/plans/old/`; this file remains the canonical source of direction.
- A phase is not complete until validators pass and the success criteria in this file are met.

## Product direction

- Public name: **Dart Arena by Pickforge**
- Positioning: a benchmark for comparing AI coding models on Dart and Flutter engineering tasks.
- Visual identity: Pickforge near-black geometric shapes, orange dot accent, white/near-white canvas, bracket/dot motif from `pickforge_mark.png`.

## Target architecture

```txt
dart_arena/
  .factory/
  .github/
  .vscode/
  package.json
  bun.lock

  app/
    .factory/
    pubspec.yaml
    lib/
    bin/
    test/
    assets/
    linux/
    macos/
    windows/

  web/
    .factory/
    package.json
    src/
    static/
      branding/
      data/
        leaderboard.v1.json
```

The Flutter app moves into `app/` to avoid collision with Svelte's `web/` directory. The Dart package/import name remains `dart_arena`.

## Data source and contract

The public site must not read the Drift/sqlite database directly. The database remains an internal runner store; the site consumes a generated, versioned static JSON file.

```txt
Flutter/headless benchmark runner
  -> Drift/sqlite database
  -> Dart export CLI
  -> web/static/data/leaderboard.v1.json
  -> Svelte static site
```

Add a Dart executable such as:

```sh
cd app
dart run dart_arena:dart_arena_export_leaderboard \
  --database .dart_arena/dart_arena.sqlite \
  --out ../web/static/data/leaderboard.v1.json \
  --strategy aggregate-compatible
```

Supported export strategies:

- `aggregate-compatible` default: aggregate all compatible task runs matching the selected filters.
- `latest-run`: export only the latest completed run, useful for local preview.
- `best-observed`: optional/labeled mode only; never the public default because it can look cherry-picked.

## Aggregation semantics

Default public leaderboard uses `aggregate-compatible`.

Compatibility filters:

- same benchmark track, e.g. `codegen` or `agentic`
- same task IDs and task versions
- same harness/scoring schema
- same evaluator weights when applicable
- selected provider/model variants only

Model rows should be grouped by provider, model, and effort/config variant when present. The default score is aggregate primary pass rate across compatible samples, not the best single run.

Metrics should reuse existing analytics where possible:

- pass rate
- Wilson confidence interval
- task-run/sample count
- solved count
- median latency
- median prompt tokens
- median completion tokens
- median estimated cost
- cost per solved task
- failure breakdown

## `leaderboard.v1.json` shape

Initial public contract:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-31T00:00:00.000Z",
  "benchmark": {
    "name": "Dart Arena",
    "brand": "Pickforge",
    "title": "Dart Arena by Pickforge",
    "track": "agentic",
    "dataPolicy": "aggregate-compatible"
  },
  "source": {
    "runIds": [],
    "taskCount": 0,
    "taskRunCount": 0
  },
  "models": [],
  "tasks": []
}
```

Do not include provider secrets, raw prompts, hidden verifier content, private local paths, or full model responses in the public JSON.

## Svelte landing page

Use Bun + Svelte/SvelteKit as a static site under `web/`.

Core sections:

1. Header with Pickforge mark and **Dart Arena by Pickforge**
2. Hero with benchmark summary and primary CTA
3. Key metrics cards
4. Pass-rate vs cost/time scatter plot
5. Ranked model table
6. Task examples
7. Methodology/provenance section
8. Footer with Pickforge branding

The first implementation should be static and data-driven from `leaderboard.v1.json`. Add richer interactivity only after the contract is stable.

## Branding assets

Use:

- `pickforge_logo.png`
- `pickforge_mark.png`

During the monorepo migration, keep canonical Flutter assets under `app/assets/branding/` and copy the public web-safe assets into `web/static/branding/`. A shared root branding folder can be introduced later if duplication becomes a problem.

## Execution slices

1. **Monorepo migration**
   - Move Flutter project files into `app/`.
   - Add root Bun workspace metadata.
   - Update CI, IDE paths, `.gitignore`, and validation commands.

2. **Leaderboard export CLI**
   - Add Dart executable for `leaderboard.v1.json`.
   - Reuse existing Drift DB access and analytics helpers.
   - Add tests for grouping, filtering, and JSON shape.

3. **Svelte/Bun scaffold**
   - Create `web/`.
   - Add Svelte static build setup.
   - Load sample `leaderboard.v1.json`.

4. **Landing page UI**
   - Implement Pickforge-styled page sections.
   - Add responsive layout and accessible tables/charts.

5. **Validation and polish**
   - Run app and web validators.
   - Fix migration fallout.
   - Confirm static build output.

## Validation

App validation:

```sh
cd app
flutter pub get
dart format --set-exit-if-changed lib test bin
flutter analyze
flutter test
```

Web validation:

```sh
cd web
bun install
bun run check
bun run build
```

Root validation should eventually expose convenience scripts:

```sh
bun run check
bun run build
```

## Risks and decisions

- Moving the Flutter project into `app/` is path-heavy and should be its own implementation slice.
- Public aggregation must avoid cherry-picking; default to compatible aggregate results.
- The export contract should be versioned from the start to avoid tying the web app to DB schema migrations.
- Hidden verifier data and raw model outputs must stay out of public site data by default.
- Existing untracked local files should not be moved or removed unless explicitly requested.

## Benchmark reliability principles

1. **Objective correctness first**: compile, analyze, public tests, hidden verifiers, widget checks, integration tests, and task-specific behavioral checks determine pass/fail.
2. **LLM judge is secondary**: judge scores are diagnostics or tie-breakers, never authority over objective failures.
3. **Fair prompts, no solution leakage**: models should see required public API/skeleton contracts, but never full reference implementations or hidden verifiers.
4. **Reproducible runs**: every result should be traceable to task versions, evaluator versions, scoring schema, run config, model IDs, prompts, and artifacts.
5. **Clear failure taxonomy**: users should understand whether a result failed, was blocked, timed out, hit infrastructure issues, or broke API compatibility.
6. **Safe execution**: generated code runs with bounded time, output, filesystem, environment, process tree, and eventually network/resource isolation.
7. **Cost transparency**: candidate model cost, judge overhead, and unknown pricing/usage are separate and explicit.
8. **Contamination resistance**: public diagnostic tasks and official private leaderboard tasks are governed separately.

## Current reliability baseline

Already implemented or established:

- Headless JSON CLI with reproducible bundle export.
- Headless agentic CLI support for Droid-backed agentic tasks.
- Primary pass/failure tags for objective reliability.
- Safe prompt API/skeleton context for codegen tasks.
- Objective aggregate caps:
  - compile failure: max `0.20`;
  - analyze failure: max `0.35`;
  - public/hidden/widget/test-author failure: max `0.60`.
- LLM judge skipping when previous objective evaluators failed.
- LLM judge context enrichment with target API/skeleton, public test snippets, and prior objective summaries.
- UI status for ignored/skipped evaluator results.
- Regression coverage for the `state.counter_bloc` missing-`const` constructor case.
- Task QA foundation that checks baseline hidden failure, reference public pass, reference hidden pass, and repeated hidden flake runs.
- Droid agent harness failures are captured as explicit `agent_harness` evaluator failures.

## Non-negotiable benchmark invariants

These invariants should be preserved across all future work:

1. A failed objective gate must never become a competitive result through aggregate weighting or judge scoring.
2. Hidden verifier contents, reference implementations, and private corpus tasks must never be included in prompts, judge prompts, public exports, or public logs.
3. Public leaderboard scores must rank by compatible aggregate samples, not cherry-picked best runs.
4. Agent/harness failures must be distinguishable from model behavioral failures.
5. Generated code must never receive provider API keys or unrelated host environment secrets.
6. Official result exports must be replayable enough to explain task versions, model config, scoring schema, evaluator versions, SDK/runtime, and pricing version.
7. Unknown cost or missing usage must be shown as unknown, not zero.
8. Any official benchmark task must have an executable reference solution, negative-case failures, hidden verifier coverage, and flake checks.

## Benchmark tracks

Dart Arena should keep separate tracks because they measure different abilities:

- **Fast Dart codegen track**: small deterministic tasks for quick local model checks.
- **Flutter widget/UI track**: visible UI behavior, semantics, golden, localization, responsive layout, interaction, and accessibility tests.
- **Agentic Flutter dev track**: flagship public benchmark track where agents modify full Flutter repositories by patch.

The public headline track should become the **agentic Flutter dev track**, not the single-file codegen track.

Good agentic Flutter task categories:

- Add a real feature to an existing Flutter app while preserving architecture.
- Fix `go_router` auth redirect races, deep-link behavior, or nested navigation state.
- Repair BLoC/Cubit/Riverpod async state bugs.
- Fix offline cache, persistence, or hydration edge cases.
- Add or repair platform-channel integrations with mocks.
- Improve responsive layouts while preserving accessibility and behavior.
- Repair flaky widget or integration tests without weakening assertions.
- Reduce rebuilds or jank with measurable performance assertions.
- Preserve semantics, localization, theming, and RTL behavior during UI changes.

## DeepSWE alignment

DeepSWE is a useful north star for turning Dart Arena from a useful local benchmark into a trusted public benchmark. Dart Arena is directionally aligned, especially after objective scoring, hidden verifiers, task QA, and headless exports, but it is not yet DeepSWE-grade.

Observed DeepSWE properties:

- 113 tasks across roughly 91-92 repositories and 5 languages.
- Corpus shape: 106 feature requests, 4 bugfixes, and 3 enhancements.
- Mean prompt length around 2,158 characters.
- Reference solutions average about 668 added lines, with median around 612.
- Verifier/test patches average about 969 added lines, with median around 795.
- Standard task resources: 2 CPUs, 8192 MB memory, 5400 second agent timeout, and 1800 second verifier timeout.
- Tasks are repo-level, realistic, and designed to be contamination-resistant.
- Public data exposes pass rate, trial counts, errors, average cost, steps, duration, input tokens, output tokens, and peak context.
- Published verifier audit numbers are part of the trust story, including false positives, false negatives, and disagreement rates.

DeepSWE task artifacts are file-backed and roughly shaped as:

```text
task.toml
instruction.md
environment/
tests/test.sh
tests/test.patch
solution/solution.patch
solution/solve.sh
```

The core verifier pattern is:

1. Check out a pinned base repository state.
2. Apply the model patch.
3. Reset or protect verifier-owned files.
4. Apply the verifier test patch.
5. Run baseline and new behavioral tests.
6. Record reward, errors, logs, and trial metadata.

Current gaps versus DeepSWE:

- The official corpus is still small relative to DeepSWE.
- Many tasks are fixture/codegen-style rather than long-horizon repo-level agent tasks.
- Public in-repo task definitions risk future training contamination.
- Environment isolation is not yet as strong as pinned containerized verifier execution.
- Official task artifacts are code-defined rather than portable file-backed bundles.
- Verifier admission reports and false-positive/false-negative audits are not yet first-class.
- Result exploration does not yet match DeepSWE's public task/model/trial heatmaps with cost, tokens, duration, steps, context, and error filters.

## DeepSWE-style Flutter task artifact format

Add a file-backed task format for official benchmark tasks:

```text
tasks/flutter/<task-id>/
  task.yaml
  instruction.md
  baseline/
  public_tests/
  hidden_tests/
  solution/
    solution.patch
  verifier/
    run.sh
  qa/
    admission_report.json
```

`task.yaml` should include at least:

```yaml
id: navigation.auth_redirect_race
version: 1
track: agentic_flutter
category: navigation
difficulty: medium
sdk:
  flutter: 3.x
timeout:
  agent_seconds: 5400
  verifier_seconds: 1800
resources:
  cpus: 2
  memory_mb: 8192
network: false
metrics:
  primary: hidden_behavior_pass
  secondary:
    - analyze
    - public_tests
    - cost
    - duration
```

## Flutter verifier strategy

Official Flutter verifiers should prioritize observable behavior:

- `flutter analyze` as a required objective gate.
- Pure Dart unit tests for algorithms, domain logic, and state machines.
- Widget tests for visible user behavior, interactions, responsive layout, semantics, theming, localization, and RTL behavior.
- Golden tests only when visual fidelity is part of the task contract.
- Integration tests for navigation, persistence, platform channels, lifecycle, and end-to-end flows.
- Performance/rebuild tests for tasks whose purpose is performance.
- Hidden tests that validate behavior through public surfaces, not reference implementation shape.

LLM judge remains diagnostic only. It may help explain quality, tradeoffs, or partial behavior, but must never override objective compile/analyze/test/hidden verifier failures.

## Task admission and verifier audit requirements

Before a task becomes benchmark-grade:

- Baseline must fail at least one hidden verifier for the intended reason.
- Reference solution must pass public and hidden verifiers.
- Hidden verifier must pass repeated flake runs.
- Empty/no-op solution must fail.
- API-breaking solution must fail.
- At least one plausible incomplete or overfit solution should fail when applicable.
- Prompt-safe context must expose required public API/skeleton details without leaking reference or hidden verifier content.
- A reviewer or automated checklist must confirm prompt-test alignment.
- Admission report must be stored with task version, evaluator version, run environment, and negative-case results.

Long-term verifier audits should track:

- false positives: incorrect solutions accepted;
- false negatives: correct solutions rejected;
- disagreement cases between public, hidden, and human review;
- flake rate and infrastructure error rate.

## Contamination and corpus governance

Use two corpora:

- **Public diagnostic corpus**: open tasks for development, smoke testing, examples, and local comparisons.
- **Private official corpus**: non-public/unmerged or otherwise contamination-resistant tasks used for official leaderboards.

Governance rules:

- Add benchmark canary strings to public benchmark data.
- Retire exposed official tasks into the public diagnostic corpus after a benchmark cycle.
- Do not mix public diagnostic scores with official private-corpus leaderboard scores.
- Version official releases by task set, task versions, evaluator versions, scoring schema, SDK, and environment.

## Scoring and headline metrics

Use these as primary ranking metrics:

- `primary_pass` / pass@1;
- pass@k when multiple trials are configured;
- confidence intervals for repeated trials;
- failure breakdown by normalized `failure_tag`.

Use these only as secondary diagnostics:

- weighted aggregate score;
- `llm_judge`;
- `diff_size`;
- speed/latency;
- estimated cost;
- elegance/readability dimensions.

For public leaderboard ranking, the main metrics should be:

1. primary pass rate;
2. cost per primary pass;
3. median duration;
4. error rate;
5. confidence interval and trial count.

## Cost estimation and efficiency

Expose reliable cost comparisons between benchmarked models at run, model, and task level, without mixing candidate model cost with evaluator/judge overhead.

Existing usage foundation:

- task runs store `promptTokens`, `completionTokens`, `providerId`, and `modelId`;
- `app/lib/analytics/cost_estimator.dart` provides a basic estimator;
- `app/lib/analytics/benchmark_statistics.dart` provides ranking summaries.

Principles:

1. Use provider-reported token usage when available.
2. Do not invent precision: if token usage or pricing is missing, show `unknown`, not `$0.00`.
3. Separate candidate model cost from benchmark overhead:
   - candidate cost: model being benchmarked;
   - judge cost: LLM judge calls;
   - infrastructure cost: local execution, CI, evaluator subprocesses, not estimated in-app initially.
4. Rank cost by solved work; cheapest failed runs are not useful.
5. Version pricing because model prices change.

Per task run, compute:

- input tokens;
- output tokens;
- total tokens;
- estimated candidate cost in micros/USD;
- pricing lookup status: `exact`, `normalized_model_match`, `model_only_match`, `missing_usage`, or `missing_pricing`.

Per task/model, compute:

- trial count;
- pass count;
- pass rate;
- median input tokens;
- median output tokens;
- median estimated cost;
- total estimated candidate cost when all costs are known;
- cost per primary pass when at least one pass exists;
- cheapest passing trial cost;
- unknown-cost count.

Per model leaderboard, compute:

- total estimated candidate cost;
- median estimated task-run cost;
- cost per primary pass;
- cost per hidden pass when hidden results are available;
- estimated judge overhead separately;
- unknown-cost count and percentage.

Per run, compute:

- total candidate cost;
- total judge/evaluator LLM cost;
- total known cost;
- unknown-cost count by provider/model;
- pricing version;
- generated-at timestamp.

Minimum pricing registry shape:

```json
{
  "version": "2026-05-31",
  "currency": "USD",
  "models": {
    "openai:gpt-5.3-codex": {
      "input_cost_per_million_tokens": 1.25,
      "output_cost_per_million_tokens": 10.0,
      "source": "manual",
      "effective_from": "2026-05-31"
    }
  }
}
```

Pricing rules:

- Keep prices in source control for reproducibility.
- Allow user override in settings/headless config for custom providers.
- Include the effective registry version in exports and provenance bundles.
- Prefer exact `provider:model` matches.
- Normalized/fallback matches must be visible in details.

Candidate model calls already produce task-run token usage. LLM judge calls should be tracked separately with evaluator ID, judge provider/model, prompt tokens, completion tokens, estimated judge cost, and associated task-run ID. Do not add judge cost to the candidate model's task-run cost.

Cost implementation phases:

1. Candidate cost visibility.
2. Pricing registry provenance.
3. Judge overhead tracking.
4. Public website efficiency views.

Cost decisions:

- Official releases should use a versioned pricing registry stored in source control, with source/effective date recorded per model.
- User-entered pricing may live in UI settings for convenience, but official/headless runs must snapshot pricing into run config/provenance.
- Tokenizer-estimated usage is allowed only as `estimated_usage`; it must be visibly labeled and excluded from official cost rankings by default.
- Runs with unknown candidate cost remain eligible for pass-rate rankings but are marked `cost_unknown` and excluded from cost-per-pass ordering unless the user explicitly includes unknown-cost rows.

## Public data and efficiency reporting

To match DeepSWE-style transparency, public result views and exports should include:

- task/model/effort heatmap;
- pass rate and pass@k;
- trial count and error count;
- primary failure tags;
- candidate cost;
- judge/evaluator overhead cost;
- cost per primary pass;
- input tokens, output tokens, and peak context;
- duration and step count;
- run metadata, task version, evaluator version, SDK version, and environment ID.

CSV, Markdown, bundle, and headless JSON exports should include:

- prompt tokens;
- completion tokens;
- estimated candidate cost micros;
- pricing match status;
- judge overhead cost micros;
- pricing registry version;
- cost per primary pass at model summary level.

## Recommended additions for a safer and better benchmark

These are the highest-value improvements to add beyond the current baseline:

1. **Hermetic sandbox v2**
   - Container or namespace isolation for generated code.
   - Network disabled by default during evaluation.
   - Explicit CPU, memory, process, wall-clock, and output limits.
   - Environment variable scrubbing so generated code cannot read provider keys.
   - Workdir-only filesystem access with path escape detection.

2. **Protected verifier workflow**
   - Apply the model patch first.
   - Reset/protect verifier-owned files.
   - Apply hidden/public verifier patches after model changes.
   - Fail attempts to modify the harness, hidden tests, scoring files, or verifier scripts.

3. **File-backed official tasks**
   - Move official benchmark-grade tasks to portable task bundles.
   - Keep task code, instruction, environment, reference solution, verifier, and QA report together.
   - Allow the app to load both code-defined development tasks and file-backed official tasks.

4. **Private official corpus**
   - Keep public tasks for development and diagnostics.
   - Use private, contamination-resistant tasks for official leaderboard scoring.
   - Retire old official tasks into the public corpus after each benchmark cycle.

5. **Task admission gate**
   - Require reference pass, baseline fail, negative-case fail, hidden flake pass, and prompt-leakage checks.
   - Store admission reports as first-class artifacts.

6. **Verifier audit program**
   - Track false positives, false negatives, disagreements, infrastructure errors, and flake rates.
   - Periodically audit accepted/rejected model patches manually.
   - Publish aggregate verifier-quality stats for official releases.

7. **Replayable provenance bundles**
   - Store enough metadata to replay official runs: task versions, evaluator versions, prompts, model config, pricing version, SDK, lockfiles, run timestamps, and artifacts.
   - Sanitize secrets, private paths, hidden verifier content, and raw model responses before public export.

8. **Statistical leaderboard discipline**
   - Use repeated trials for official scores.
   - Show Wilson confidence intervals and low-sample warnings.
   - Separate infrastructure errors from model failures.
   - Avoid best-observed ranking as the public default.

9. **Supply-chain and dependency controls**
   - Pin Flutter/Dart SDK versions.
   - Use lockfiles or cached package mirrors for official runs.
   - Disable arbitrary network dependency resolution during verification when possible.
   - Record dependency hashes in provenance.

10. **Task diversity and calibration**
   - Calibrate task difficulty with reference/human baselines and baseline-agent runs.
   - Balance tracks across state management, UI, navigation, persistence, platform, performance, testing, accessibility, localization, and refactoring.
   - Avoid too many small single-file tasks in the headline leaderboard.

11. **Failure taxonomy and blocked checks**
   - Report downstream checks as blocked when an earlier hard failure makes them meaningless.
   - Preserve `primary_pass=false`.
   - Include `blocked_by` details for UI/export clarity.

12. **Public export redaction and privacy**
   - Exclude provider secrets, raw hidden verifier content, private local paths, and sensitive model outputs.
   - Sanitize logs and hidden failure messages.
   - Use stable artifact IDs instead of machine-local paths.

13. **Model/provider config normalization**
   - Record provider, model, effort, temperature, max tokens, tool/agent settings, retry policy, and model snapshot where available.
   - Keep base model and effort variants separate.

14. **Human review and preference sidecar**
   - Keep objective pass/fail as the source of truth.
   - Add optional human review for maintainability, architecture preservation, UX, and code quality on passing solutions.
   - Do not let preference scores override objective failure.

15. **Security smoke tests**
   - Include adversarial tasks or harness tests that attempt path traversal, environment leakage, network access, hidden-test reads, verifier modification, and runaway processes.
   - Treat sandbox escapes as benchmark infrastructure failures requiring immediate fix.

## Unified roadmap

### Phase 0: Headless CLI parity for agentic benchmarks — completed

Problem: the app can run agentic benchmark tasks through the Droid agent harness, but the headless CLI must support the same track so official runs, CI smoke checks, and reproducible exports do not depend on the desktop UI.

Design:

- Route headless codegen tasks through the existing codegen executor.
- Route headless agentic tasks through `AgenticRunOrchestrator`.
- Wire `DroidAgentHarness` automatically for headless `droid` providers.
- Preserve clear `agent_harness` evaluator results for missing harnesses, process failures, timeouts, and successful agent runs.
- Keep headless timeout/cancellation behavior effective for agentic prepare, harness, patch capture, and grading phases.
- Export agentic task runs, patches, evaluator details, provenance, and bundle artifacts with the same static CLI contract as codegen runs.

Success criteria:

- `dart_arena_headless` accepts `BenchmarkTrack.agentic` tasks.
- Agentic CLI runs persist `benchmarkTrack=agentic`, `harnessId`, `patchText`, primary pass/failure tags, and evaluator details.
- Droid/BYOK/permission failures are visible as harness failures rather than silent model failures.
- Focused headless/agentic tests and the full Flutter test suite pass.

Completion evidence:

- Implemented on 2026-06-02.
- Validated with focused headless/agentic tests, full `flutter test`, `flutter analyze`, format check, and diff whitespace check.

### Phase 1: Blocked evaluator semantics

Problem: one root cause can currently produce multiple objective `0`s, which is technically correct but confusing.

Design:

- Add blocked evaluator representation for downstream checks that cannot run meaningfully after an earlier hard failure.
- Example: compile fails, so tests are reported as `blocked_by_compile`, not as an independent behavioral failure.
- Preserve `primary_pass=false`.
- Preserve failure tag priority: timeout/environment/harness before objective failures, then compile/analyze/test.
- Keep aggregate caps unchanged or stricter; blocked evaluators should not inflate scores.

Success criteria:

- Users can tell the difference between “tests failed behaviorally” and “tests could not run because compile failed.”
- Result details include the blocking evaluator ID and rationale.
- Existing benchmark results remain understandable in UI and exports.

### Phase 2: Task QA expansion

Problem: every task needs automated integrity checks before it is benchmark-grade.

Design:

Each task should have QA coverage proving:

- reference solution passes public evaluators;
- reference solution passes hidden verifiers;
- empty/no-op solution fails;
- API-breaking solution fails;
- known overfit/minimal bad solution fails when applicable;
- prompt exposes required public API/skeleton contracts;
- prompt-safe context does not leak implementation bodies, hidden verifiers, or reference files.

Success criteria:

- Corpus QA reports all active benchmark tasks as valid.
- Task authoring rejects or flags tasks without reference and negative-case coverage.
- The report is usable in CI/headless validation.

### Phase 3: Hidden tests and anti-overfit coverage

Problem: public tests are useful for fairness, but public-only tasks can be overfit.

Design:

- Add hidden edge cases for each benchmark-grade task.
- Keep hidden verifiers outside prompt/judge context.
- Version task hidden verifier changes.
- Track public-pass vs hidden-pass in reports.

Success criteria:

- Each active benchmark task has meaningful hidden coverage.
- Hidden failures have clear failure tags and UI/export details.
- Hidden evaluator IDs are consistently classified as objective.

### Phase 4: DeepSWE-style file-backed tasks and agentic Flutter

Problem: code-defined fixture tasks are useful but do not fully represent long-horizon Flutter development work.

Design:

- Add file-backed task loader for official task bundles.
- Add first 5-10 agentic Flutter repository tasks.
- Use patch-based agent execution for the flagship track.
- Keep fast codegen tasks as a separate diagnostic track.

Success criteria:

- Official task bundles can be loaded and validated without hardcoding them into Dart source.
- Agentic Flutter tasks run through objective public/hidden verifiers.
- Public docs and exports clearly separate codegen, widget/UI, and agentic tracks.

Implementation progress:

- File-backed task bundle loading is implemented for DeepSWE-style `task.yaml`, `instruction.md`, `environment/`, `solution/`, and `tests/` bundles.
- File-backed tasks expose public instruction/tests to prompts while keeping hidden verifier and reference files out of prompt/judge context.
- Headless config supports `taskBundleRoots` so official bundles can be loaded without Dart source registration.
- Remaining work: add official long-horizon Flutter agentic task bundles and release-grade QA reports.

### Phase 5: Statistical reporting

Problem: single-run results are noisy across stochastic models and providers.

Design:

- Promote pass@1/pass@k and confidence intervals in leaderboard views.
- Preserve per-trial artifacts.
- Report sample counts and low-sample warnings.
- Make trial count, concurrency, timeouts, model IDs, provider IDs, and evaluator weights explicit in run metadata.

Success criteria:

- Leaderboards rank primarily by measured primary pass rate.
- Low-sample rankings are visibly marked.
- Exports include enough metadata to reproduce a run.

Implementation progress:

- Public exports and the static web leaderboard now include public-pass and hidden-pass counts/rates separately from primary pass rate.
- Existing confidence intervals, sample counts, and low-sample indicators remain the ranking surface.

### Phase 6: Execution sandboxing

Problem: generated code is untrusted code.

Design:

- Scrub unrelated environment variables from evaluator subprocesses.
- Pass only explicitly required secrets to provider calls, never to generated-code test processes.
- Enforce timeouts, process-tree cleanup, output limits, and workdir-only file access.
- Add optional stronger sandboxing for public benchmark runs:
  - container or namespace isolation;
  - network disabled by default during generated-code evaluation;
  - CPU and memory limits.

Success criteria:

- Generated task code cannot access provider API keys by default.
- Runaway processes are terminated reliably.
- Public/untrusted benchmark mode has documented isolation guarantees.

Implementation progress:

- Evaluator subprocess environments now scrub unrelated host variables and provider secret-looking variables by default.
- Remaining work: stronger container/namespace isolation, network controls, and resource limits for official public runs.

### Phase 7: Cost estimation and efficiency

Problem: pass rate alone does not show how expensive a model is to use.

Design:

- Add structured candidate cost estimates.
- Add pricing registry provenance.
- Track judge overhead separately.
- Show cost per primary pass in UI and exports.

Success criteria:

- Users can compare models by cost per solved task.
- Unknown pricing/usage is explicit and never silently treated as free.
- Candidate model cost and judge overhead are separated.
- Exports contain enough pricing metadata to reproduce estimates later.

Implementation progress:

- Candidate model cost summaries include known/unknown estimate counts, total known-all-runs cost, cheapest passing estimate, and cost per primary pass.
- Static exports include these fields for downstream web/data consumers.
- Remaining work: pricing-registry provenance/effective dates and separate judge-overhead usage/cost records.

### Phase 8: Public benchmark governance and data UI

Problem: public leaderboards need stable versioning and reproducibility rules.

Design:

- Freeze benchmark releases by task set, task versions, evaluator versions, scoring schema, SDK, and environment.
- Store provenance bundles for official runs.
- Add public heatmaps and trial browser inspired by DeepSWE.
- Require CI validation before publishing official results.

Success criteria:

- A score can be traced to an immutable benchmark version.
- Results from different benchmark versions are not mixed silently.
- Official leaderboard entries have reproducible artifacts.

## Official release readiness gates

Dart Arena should not publish an official benchmark claim until all gates below pass for the selected release:

### Corpus gates

- Every official task has a task version, reference solution, public tests, hidden verifier, negative cases, and task admission report.
- Every official task passes repeated flake checks on the release environment.
- Public diagnostic tasks are separated from private official leaderboard tasks.
- Any retired official task is moved to the public diagnostic corpus only after its release cycle.

### Execution gates

- Generated-code evaluation runs with environment scrubbing and timeout/process-tree cleanup.
- Official runs use pinned Flutter/Dart SDK versions.
- Official runs record dependency lockfiles or dependency hashes.
- Network behavior is explicit per task and disabled by default for generated-code evaluation.
- Agentic runs persist patches, harness status, trajectory metadata when available, and objective evaluator results.

### Scoring gates

- `primary_pass` is derived from objective gates.
- LLM judge cannot improve a failed objective result.
- Blocked evaluator semantics distinguish blocked checks from independent behavioral failures.
- Infrastructure/harness failures are separated from model failures in UI/export.
- Repeated-trial pass rates include sample count and confidence interval.

### Reporting gates

- Public export excludes secrets, private local paths, raw hidden verifier content, and private corpus prompts.
- Public export includes task versions, evaluator/scoring schema, model/provider config, run metadata, cost/pricing status, and failure tags.
- Website defaults to compatible aggregate results and labels any low-sample or unknown-cost rows.
- Release artifacts include enough provenance to reproduce or audit the score later.

## Recommended immediate implementation sequence

1. **Blocked evaluator semantics**
   - Add `blocked`/`blockedBy` details to evaluator results or a compatible representation.
   - Update UI/export to show blocked checks separately from failed checks.
   - Add regression tests for compile-failed and harness-failed runs.

2. **Task QA admission reports**
   - Expand task QA with no-op/API-breaking/overfit negative solutions.
   - Write JSON admission reports for each task.
   - Add CI/headless command to validate the active corpus.

3. **Hidden verifier and failure taxonomy polish**
   - Ensure all hidden verifier IDs classify as objective.
   - Add clearer hidden/public pass split to exports and UI.
   - Add blocked and infrastructure failure tags to public reports.

4. **File-backed task bundle loader**
   - Define `task.yaml` schema.
   - Load public development bundles from disk.
   - Keep code-defined tasks supported during migration.

5. **Sandbox hardening**
   - Scrub generated-code process environments.
   - Add process/resource/network controls.
   - Add adversarial harness safety tests.

6. **Official release/reporting pass**
   - Run repeated trials.
   - Export compatible aggregate leaderboard data.
   - Publish release provenance and verifier-audit summary.

## Definition of done for reliability work

- Objective pass/fail is explainable from stored evaluator details.
- LLM judge cannot raise a failed objective result into a competitive score.
- Prompt context exposes required contracts without leaking solutions.
- Every benchmark-grade task has reference, negative, and hidden QA coverage.
- Official tasks have file-backed artifacts, admission reports, and pinned verifier metadata.
- Public benchmark exports include trials, errors, cost, tokens, duration, and primary failure tags.
- Full validators pass: formatting, analyze, focused reliability tests, and full test suite when code changes.
