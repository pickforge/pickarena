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
- Cost estimation has candidate-model summaries, unknown-cost counts, cost-per-pass export fields, pricing-registry provenance, and separate judge-overhead summaries.
- Active specs have been consolidated into this master spec; older specs/plans are archived under `docs/**/old/`.

Current recommendation:

1. Treat **Phase 0** through the official reporting pass as completed for the current local release candidate.
2. Use `spark-sandboxed-official-repeated-clean-20260605` as the current clean-provenance release evidence.
3. Keep future public claims tied to aggregate-compatible exports, stored task QA reports, Bubblewrap provenance, and release-report readiness output.

Official benchmark status: **release-report ready for the current local candidate**. The clean run `spark-sandboxed-official-repeated-clean-20260605` produced a ready release report with no blockers; Droid trace/token/cost telemetry remains explicitly unknown where Droid does not report it.

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
   - [x] Record provider, model, effort, temperature, max tokens, tool/agent settings, retry policy, and model snapshot where available.
     - Completed: export surfaces now record provider/model plus normalized `baseModelId` and structured `modelConfig`, provenance now carries sanitized provider runtime config, explicit temperature configuration status, raw API max-output-token settings, Droid direct tool/agent settings, OpenAI-compatible retry policy, and Factory custom-model configured snapshots where available.
   - [x] Keep base model and effort variants separate.

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
- [x] Remaining work: add official long-horizon Flutter agentic task bundles and release-grade QA reports.
  - The private-official Flutter corpus now includes five active agentic bundles, including `forms.email_validation`, `lists.contact_search`, and `state.selection_controller`, with public tests, hidden verifier coverage, reference solutions, noop/API-breaking/overfit negative cases, release metadata, resource/network policy metadata, and generated admission reports proving baseline hidden failure, reference public/hidden pass, three hidden flake runs, prompt-safety checks, and rejection of every required negative case.
  - The `state.selection_controller` hidden verifier now accepts both mutable-copy and unmodifiable-snapshot `selectedIds` implementations while still proving callers cannot mutate internal controller state; Task QA re-admitted the corrected bundle, and the official file-backed bundle test passes with the regenerated admission report.

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
- Bubblewrap now provides Linux namespace/mount/network controls for generated-code prepare/evaluator subprocesses in public-run mode, with systemd-run cgroup CPU quotas and evaluator-side memory/process/output enforcement recorded in provenance.

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
- Static exports include these fields plus pricing registry version/currency metadata for downstream web/data consumers.
- Run provenance snapshots the source-controlled pricing registry version, currency, model prices, source, and effective dates.
- LLM judge calls record separate judge-overhead token usage, estimated cost, pricing status, and pricing registry metadata in evaluator details; public JSON and leaderboard exports expose sanitized overhead summaries without adding judge cost to candidate model cost.

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

Implementation progress:

- Release-report output includes verifier-audit summaries with hidden verifier digest counts, hidden flake run ranges, QA check counts, and negative-case rejection summaries by kind.
- Task QA admission reports include admission tool identity, evaluator-version metadata, captured run environment metadata, execution-policy/resource metadata, and verifier-quality summaries for false positives, false negatives, public/hidden disagreements, infrastructure errors, hidden flake failures, and accepted negative cases; generated summaries reference per-task reports with portable relative paths; release-report output audits task QA summary schema/count/timestamp integrity, summary-to-loaded-report status/failure-count/timestamp-order consistency, per-report schema/status/timestamp integrity, per-report admission-check integrity, per-report admission provenance/tool/evaluator/SDK/dependency metadata, per-report task execution policy/network/resource-limit metadata, per-report prompt-safety component/pass evidence and negative-case-kind consistency, negative-case evidence integrity, hidden-verifier digest format integrity, verifier-quality field/evidence consistency, and report path safety, skips absolute or unsafe relative paths, aggregates verifier fields, and blocks readiness on missing summaries, malformed summaries, inconsistent summaries, future-dated summaries or reports, reports generated after their summary, unsupported per-task report schemas or statuses, failed/missing admission checks, missing or incomplete admission provenance, invalid admission tool identity, missing or unsafe task execution policy/resource metadata, missing or mismatched prompt-safety evidence, inconsistent prompt-safety negative-case kind metadata, missing or malformed hidden-verifier digest metadata, malformed negative-case evidence, malformed or inconsistent verifier-quality summaries, admitted reports with failure messages, unsafe report paths, or unsafe verifier-quality findings.
- Release-report corpus readiness now requires repeated hidden-verifier flake evidence per loaded task QA report, defaulting to at least three hidden flake runs per task, and blocks official readiness when any task falls below that threshold.
- File-backed task manifests and generated task QA reports now carry explicit release corpus metadata, and release-report corpus readiness blocks official releases when a loaded task report is missing metadata, belongs to the public diagnostic corpus, or is marked retired instead of active private-official.
- Stored official file-backed task admission reports now carry admission tool identity, evaluator version, SDK/dependency environment metadata, execution policy/resource metadata, hidden verifier digests, three hidden flake runs, prompt-safety evidence, verifier-quality summaries, negative-case audit entries, and empty failure messages.
- Release-report CLI can load generated Task QA summaries, repeated stored per-task `admission_report.json` files directly, or task-report roots that discover nested `qa/admission_report.json` files, synthesizing a compatible summary so first-class official task admission artifacts can be audited without a separate generated summary file.
- Workdir paths for generated-code and agentic benchmark tasks now use compact digest-backed path segments, and the Droid agent harness runs long benchmark workdirs through a short copy-backed cwd proxy that syncs results back before patch capture, avoiding Droid/Factory physical-cwd/session path-length failures for long custom model IDs and nested official task workdirs.
- Agentic runs that time out or fail without stdout/stderr previews now persist a sanitized fallback response record with harness status, exit code, and latency, so headless bundles can still export a response artifact for every agentic task run that reached the harness; regression coverage verifies no-preview timeouts export both response and patch artifacts without `missing_response_text` warnings, and no-preview harness failures with no patch export a response artifact plus an explicit `missing_patch_text` bundle warning and sanitized `run_results.v1.json` agent-harness status metadata without raw stdout/stderr previews.
- The Droid agent harness default runner now caps live stdout/stderr collection, terminates the harness process tree when the cap is exceeded, returns a failed harness result with bounded previews and output-limit metadata, and has an adversarial stdout-flood regression test.
- The Droid direct provider default runner now applies the same live stdout/stderr cap and process-tree termination behavior for codegen-style Droid calls, preserving timeout exceptions while turning output floods into bounded failed provider responses with diagnostic stderr; regression coverage exercises a fake output-flooding Droid executable.
- Workspace dependency preparation now caps live `dart pub get` / `flutter pub get` stdout/stderr collection, terminates the prepare process tree when the cap is exceeded, returns a bounded `PrepareFailed` diagnostic without retrying online, and has an adversarial output-flooding pub-get regression test.
- Generated-code prepare and evaluator subprocesses now isolate `HOME`, `USERPROFILE`, XDG config/cache, and Windows app-data environment paths to the benchmark workdir while preserving the original default `PUB_CACHE` for offline dependency resolution; regression coverage verifies the helper, prepare, and analyze evaluator subprocess environments.
- Generated-code isolated environments now also set `ANALYZER_STATE_LOCATION_OVERRIDE` inside the benchmark workdir so Dart analysis server plugin state stays local and deterministic under heavy parallel QA; regression coverage verifies the override and the long corpus QA test passes with the isolated analyzer state root.
- Final validation after the analyzer state-root and official admission timeout fixes passed the full Flutter suite with `20:16 +698: All tests passed!`, followed by clean `flutter analyze` and `git diff --check` runs.
- Evaluator resource probes, process-tree cleanup helpers, baseline Git cleanup helpers, agentic patch-capture Git helpers, Droid harness/provider cleanup helpers, default run-provenance capture, and artifact-bundle export environment capture now run helper subprocesses with explicit scrubbed environments and no inherited parent environment; regression coverage uses fake `ps`, `git`, and `flutter` executables to prove sensitive token/proxy variables are absent while normal helper variables remain available.
- Agentic patch capture now runs `git add -N`, `git status`, and `git diff --binary` through a bounded subprocess runner with timeout, stdout/stderr caps, scrubbed Git config/prompt environment, no inherited parent environment, and process-tree termination on timeout/output-limit exits; regression coverage verifies sensitive environment scrubbing, fail-fast behavior for output-flooding diffs, and child-process cleanup before patch text reaches storage or artifact export.
- Droid direct-provider failure diagnostics no longer echo the generated prompt, shell command, executable path, cwd, `TMPDIR`, `HOME`, or `PATH`; the message keeps bounded stdout/stderr previews, prompt length, argument count, duration, and actionable custom-model hints, with regression coverage preventing prompt and local-path leakage.
- Agentic harness evaluator details now sanitize returned harness metadata before storage, preserving safe scalar telemetry such as `argc`, output-limit flags, and trace metrics while redacting raw workspace/executable/command/prompt/credential-like keys or path-like string values; regression coverage verifies raw local paths and secret-looking metadata do not enter stored evaluator details.
- Hidden verifier cleanup now removes empty injected verifier directories after deleting hidden test files, while preserving nonempty visible task directories; regression coverage verifies injected `_hidden` directories do not linger after hidden evaluation.
- The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-hidden-cleanup-20260605` exercised hidden verifier injection and cleanup on `state.bloc_debounce_cancellation`, passed with aggregate score `1.0`, emitted zero bundle warnings, exported a codegen aggregate-compatible leaderboard, and left no `_hidden` paths in the scratch workdir.
- The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-env-isolation-20260605` exercised the isolated generated-code environment path on `state.bloc_debounce_cancellation`, passed with aggregate score `1.0`, emitted zero bundle warnings, exported a codegen aggregate-compatible leaderboard, and produced no environment or output-limit failure markers.
- The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-helper-scrub-20260605` exercised the scrubbed helper subprocess paths on `state.bloc_debounce_cancellation`, passed with aggregate score `1.0`, emitted zero bundle warnings, exported a codegen aggregate-compatible leaderboard with one complete trial summary, produced no secret/proxy marker hits in the smoke artifacts, and generated a release report whose artifact/privacy checks stayed intact while remaining blocked on expected non-release conditions such as missing sandbox enforcement, dirty git provenance, diagnostic task-QA coverage, and incomplete resource-limit provenance.
- The custom `gpt-5.3-codex-spark` one-trial agentic smoke `spark-patchcapture-bound-20260605` exercised the scrubbed and bounded Droid/patch-capture helper paths on `forms.email_validation`; Droid returned a real harness failure before objective grading, but the run emitted zero bundle warnings, exported both response and patch artifacts, produced no secret/proxy marker hits in smoke artifacts, exported an agentic aggregate-compatible leaderboard, and generated a release report with matching task-QA coverage, corpus/scoring/privacy gates passing, zero missing response/patch/harness metadata, and only expected non-release blockers for missing sandbox enforcement and dirty git provenance plus unknown Droid telemetry warnings.
- The custom `gpt-5.3-codex-spark` one-trial agentic smoke `spark-patchcapture-tree-20260605` exercised the patch-capture process-tree cleanup build on `forms.email_validation`; Droid again returned a real `harness_error` before objective grading, but the run completed headless with one task run, six evaluations, zero bundle warnings, response and patch artifacts present, an aggregate-compatible agentic leaderboard, no secret/proxy/provider-key marker hits in smoke artifacts, and a release report blocked only by expected local non-release conditions such as missing sandbox enforcement, dirty provenance, scoped one-task task-QA coverage, and unknown Droid telemetry.
- The custom `gpt-5.3-codex-spark` one-trial agentic smoke `spark-harness-metadata-sanitized-20260605` exercised the sanitized Droid harness metadata path on `forms.email_validation`; Droid returned a real `harness_error`, but the run completed headless with one task run, six evaluations, zero bundle warnings, response and patch artifacts present, an aggregate-compatible agentic leaderboard, stored agent-harness details containing only safe `argc` plus `metadata_redacted_count` from Droid metadata, no raw `workspace`/`executable`/workdir/secret/proxy/provider-key marker hits in public smoke artifacts, and a release report blocked only by expected local non-release conditions such as missing sandbox enforcement, dirty provenance, scoped one-task task-QA coverage, and unknown Droid telemetry.
- The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-prepare-outputcap-20260605` exercised the updated prepare path on `state.bloc_debounce_cancellation`, passed with aggregate score `1.0`, emitted zero bundle warnings, exported a codegen aggregate-compatible leaderboard, and produced no prepare output-limit markers.
- The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-provider-outputcap-20260605` exercised the updated Droid direct provider path on `state.bloc_debounce_cancellation`, passed with aggregate score `1.0`, emitted zero bundle warnings, exported a codegen aggregate-compatible leaderboard, and produced no output-limit markers.
- The custom `gpt-5.3-codex-spark` one-trial smoke `spark-harness-outputcap-20260605` exercised the updated Droid harness path on `forms.email_validation`; Droid failed before patch generation without triggering the output cap, emitted one `missing_patch_text` bundle warning, exported compatible leaderboard/release-report artifacts, and the release report recorded zero missing or invalid agent-harness status metadata while blocking on the expected missing agentic patch artifact.
- Public leaderboard exports now include explicit aggregate telemetry coverage maps and per-trial telemetry status maps for trace metrics and token usage, so release-report readiness distinguishes omitted or malformed public metric schema from explicitly unknown telemetry; regression coverage keeps old/malformed exports blocked while allowing Droid-style non-reporting runs through with unknown-telemetry warnings.
- A custom `gpt-5.3-codex-spark` Droid smoke against the two active private-official Flutter tasks generated matching scoped leaderboard, artifact bundle, and release-report evidence. The post-fallback rerun `spark-official-fallback-20260604` passed both tasks, emitted zero bundle warnings, exported response and patch artifacts for both agentic task runs, and produced a latest-run release report with zero missing response/patch artifacts and zero missing public metric counts; it still reports unknown trace/token/cost telemetry as warnings and remains blocked on non-release-smoke conditions such as aggregate-compatible data policy, generated-code sandbox enforcement, and dirty worktree provenance.
- The follow-up custom `gpt-5.3-codex-spark` smoke `spark-official-reporting-20260604` again passed both active private-official Flutter tasks, emitted zero bundle warnings, exported a fresh scoped leaderboard and artifact bundle, and produced a latest-run release report with zero missing response/patch artifacts, zero missing leaderboard-trial artifact coverage, and zero missing public metric counts; it remains blocked only on known latest-run/data-policy, generated-code sandbox enforcement, and dirty worktree provenance conditions.
- The expanded custom `gpt-5.3-codex-spark` smoke `spark-official-forms-20260604` covered all three active private-official Flutter tasks, including the new `forms.email_validation` task; `forms.email_validation` and `platform.channel_mock` passed, `navigation.auth_redirect_race` failed compile in that smoke, the run emitted zero bundle warnings, and the latest-run release report loaded all three task QA reports with zero missing task-QA coverage, zero missing response/patch artifacts, zero missing leaderboard-trial artifact coverage, and zero missing public metric counts. It remains blocked on the known latest-run/data-policy, generated-code sandbox enforcement, and dirty worktree provenance conditions.
- The targeted custom `gpt-5.3-codex-spark` smoke `spark-official-lists-20260604` covered the new `lists.contact_search` task; the task passed, emitted response and patch artifacts, generated a bundle with zero warnings, and produced an isolated latest-run release report with zero missing task-QA coverage, zero missing response/patch artifacts, zero missing leaderboard-trial artifact coverage, and zero missing public metric counts. It remains blocked on latest-run/data-policy, one-sample minimum, generated-code sandbox enforcement, and dirty worktree provenance conditions.
- The targeted custom `gpt-5.3-codex-spark` smoke `spark-official-selection-20260604` covered the new `state.selection_controller` task; the task passed, emitted response and patch artifacts, generated a bundle with zero warnings, and produced an isolated latest-run release report with zero missing task-QA coverage, zero missing response/patch artifacts, zero missing leaderboard-trial artifact coverage, and zero missing public metric counts. It remains blocked on latest-run/data-policy, one-sample minimum, generated-code sandbox enforcement, and dirty worktree provenance conditions.
- The custom `gpt-5.3-codex-spark` repeated local validation run `spark-official-repeated-20260605` covered all five active private-official Flutter tasks with two trials each, produced 10 task runs, 60 evaluations, zero bundle warnings, an aggregate-compatible leaderboard export, and a release report with corpus and scoring gates passing, 5/5 task-QA coverage, 20/20 artifact files verified, zero missing response/patch artifacts, zero missing leaderboard trial summaries, and no missing task-model/trial metric schema. The run reported 8/10 primary passes before a `state.selection_controller` hidden-verifier correction: both failed patches passed public tests and replayed cleanly against the corrected hidden verifier, so this run is useful local evidence but is not a publishable official score. The generated release report remains blocked on missing generated-code sandbox enforcement and dirty git provenance, with unknown Droid trace/token/cost telemetry recorded as warnings.
- Follow-up targeted `state.selection_controller` rechecks `spark-official-selection-recheck-20260605` and `spark-official-selection-recheck-retry-20260605` attempted two trials each against the corrected bundle, but both runs failed at the Droid agent harness before patch generation, emitted `missing_patch_text` bundle warnings, and therefore do not validate task behavior; the replayed patches from `spark-official-repeated-20260605` are the current corrected-verifier evidence.
- A fresh targeted custom `gpt-5.3-codex-spark` rerun `spark-selection-corrected-20260605` again attempted two `state.selection_controller` trials against the corrected verifier, but both trials failed inside the Droid harness before patch generation with no stdout/stderr preview. The run produced response fallback artifacts for both task runs, emitted two `missing_patch_text` bundle warnings, exported an aggregate-compatible one-task leaderboard, and generated a one-task release report where corpus and scoring gates passed, response artifact coverage and leaderboard-trial coverage were complete, `artifactBundle.warningCodeCounts` / reporting `artifactBundleWarningCodeCounts` recorded `missing_patch_text: 2`, and reporting remained blocked by the warnings and missing agentic patch artifacts. This confirms the release audit path for real no-preview harness failures, but still does not validate corrected task behavior.
- The custom `gpt-5.3-codex-spark` one-trial smoke `spark-agentharness-metadata-20260605` regenerated the no-preview harness-failure bundle after adding sanitized `agentHarness` export metadata. The bundle emitted one `missing_patch_text` warning, exported an aggregate-compatible one-task leaderboard and one-task release report, and the release report recorded zero missing or invalid agent-harness status metadata while still blocking on the expected missing agentic patch artifact.
- The custom `gpt-5.3-codex-spark` health run `spark-health-forms-20260605` passed `forms.email_validation` with one agentic trial, 6/6 evaluator checks passing except the expected secondary diff-size penalty, zero bundle warnings, response and patch artifacts present, a latest-run leaderboard export, and a single-task release report with zero missing task-QA, response, patch, or leaderboard-trial coverage. The report remains blocked by expected non-release conditions: latest-run data policy, one-sample minimum, missing generated-code sandbox enforcement, dirty git provenance, and unknown Droid trace/token/cost telemetry.
- The custom `gpt-5.3-codex-spark` sandboxed repeated rerun `spark-sandboxed-official-repeated-proxy-20260605` covered all five active private-official Flutter tasks with two trials each under `requireGeneratedCodeSandbox: true` after the Droid cwd proxy fix, produced 10 task runs, 60 evaluator records, 10/10 primary passes, zero bundle warnings, Bubblewrap enforcement in manifest/provenance, 20 response/patch artifacts, an aggregate-compatible leaderboard export scoped to the run, and `release_report.sandboxed-official-repeated-proxy.v1.json` with corpus, execution, scoring, task-QA, artifact, checksum, run-results, CSV, report-md, sandbox, resource-policy, and trial-summary coverage passing. The release report remains blocked only by dirty git provenance in this development worktree, with expected unknown Droid trace/token/cost telemetry warnings.
- The clean-provenance custom `gpt-5.3-codex-spark` sandboxed repeated run `spark-sandboxed-official-repeated-clean-20260605` covered all five active private-official Flutter tasks with two trials each from committed revision `3b582f9`, produced 10 task runs, 60 evaluator records, 7/10 primary passes, zero bundle warnings, Bubblewrap enforcement in manifest/provenance, clean git export metadata, 20 response/patch artifacts, an aggregate-compatible leaderboard export scoped to the run, and `release_report.sandboxed-official-repeated-clean.v1.json` with `status == ready`, no blockers, corpus/execution/scoring/reporting readiness gates passed, 5/5 task-QA coverage, clean manifest git metadata, and expected unknown Droid trace/token/cost telemetry warnings.
- Release-report corpus readiness now cross-checks the public leaderboard task/version/track set against loaded task QA admission reports, blocking official releases when leaderboard tasks lack matching QA evidence or when QA reports belong to tasks outside the selected leaderboard task set.
- Public leaderboard exports now include immutable benchmark version, task-set ID, and evaluator schema version metadata; release-report output blocks official readiness when those fields are absent, and the web methodology surface displays them alongside scoring/provenance metadata.
- Release-report output fingerprints its input artifacts with display-only paths, byte counts, and SHA-256 hashes for replayability.
- Release-report output accepts run artifact bundle manifests, checksums files, standard bundle outputs, decoded `run_results.v1.json` data, parsed `results.csv` task rows, and parsed `report.md` task-run tables as first-class inputs, fingerprints them, summarizes response/patch/checksum/warning-code/path-safety/manifest-provenance/run-results/results-csv/report-markdown coverage, and blocks official readiness when bundle warnings exist, artifact bundle inputs use unsupported schema versions, artifact paths or checksum entries are absolute, parent-traversing, outside the expected bundle roots, unexpected, or point at hidden/reference/fixture content, required response or agentic patch artifacts are missing, `manifest.json` or `run_results.v1.json` task runs lack task ID, provider ID, model ID, nonnegative trial index, positive task version, or benchmark track metadata, `manifest.json` or `run_results.v1.json` has duplicate task-run IDs, `manifest.json` and `run_results.v1.json` lack matching run IDs, `manifest.json` provenance is missing or has a run ID that does not match the manifest, does not record generated-code sandbox enforcement with a backend, has incomplete task execution policy/resource limits, records network-enabled generated-code task policy, or lacks SDK, dependency lockfile, or pricing registry provenance, `run_results.v1.json` task-run rows lack the same run ID as the top-level run, the bundle run ID is not listed in the leaderboard source run IDs, bundle task-run metadata is not exactly represented by public leaderboard trial summaries, `run_results.v1.json` task-run outcome fields mismatch public leaderboard trial summaries or use unsupported failure tags / pass-inconsistent task-run outcome semantics, `results.csv` task rows are missing required columns, missing, extra, or duplicated against manifest task runs, mismatch `run_results.v1.json` task-run outcomes, or use unsupported failure tags / pass-inconsistent task-run outcome semantics, `report.md` is missing required report sections or task table columns, has task rows missing, extra, or duplicated against manifest task runs, has declared task-run counts that differ from parsed task rows, mismatches `run_results.v1.json` task-run outcomes, or uses unsupported failure tags / pass-inconsistent task-run outcome semantics, `run_results.v1.json` task runs lack valid nonempty evaluation evidence with scores in `[0, 1]`, known pass-consistent statuses, nonempty rationale, valid blocked-check and judge-overhead metadata, and valid detail digest/byte metadata or have duplicate evaluation IDs or duplicate task-run/evaluator IDs, `manifest.json` evaluation counts do not match `run_results.v1.json`, `manifest.json` evaluator IDs are missing/invalid/duplicated or do not match `run_results.v1.json` evaluator IDs, `manifest.json` has unknown artifact kinds or duplicate task-run/artifact-kind references, `checksums.json` does not cover `manifest.json`, `run_results.v1.json`, `results.csv`, `report.md`, and every exported artifact path, the `manifest.json`, `run_results.v1.json`, `results.csv`, or `report.md` checksum entries do not match the fingerprinted inputs, or `run_results.v1.json` task runs/artifact references are missing, extra, or inconsistent with the bundle manifest.
- `run_results.v1.json` now exposes sanitized `agentHarness` status summaries for `agent_harness` evaluator records, including only status, nullable exit code, and boolean stdout/stderr/trajectory presence flags while keeping raw previews, local workspace paths, executable paths, and trajectory paths behind private details digests. Release-report readiness blocks if those agent harness status summaries are missing or malformed.
- Release-report regression coverage now explicitly models an agentic harness-failure bundle with response evidence present but no patch artifact, verifies official readiness is blocked by the bundle warning and missing agentic patch while `missingResponseArtifactCount` remains zero, and asserts sanitized artifact-bundle warning-code counts in both single-run and multi-run readiness summaries.
- Release-report artifact bundle readiness now includes manifest metadata subgates for top-level `manifest.json` release metadata, run timing metadata, population counts, outcome summary metadata, `run_results.v1.json` top-level run metadata, per-task-run timing/token usage telemetry metadata, agentic harness metadata matching between `manifest.json` and `run_results.v1.json`, physical artifact file fingerprint validation, and response/patch artifact byte/digest metadata, blocking official readiness when `generatedAt`, app version, Drift schema version, export tool identity/version, export environment SDK/host metadata, clean git metadata, run name, `startedAt`, `completedAt`, ordered run/generated timestamps, `taskCount` / `providerCount` / `modelCount`, `passSummary` / `failureSummary` counts, run-results run name/timing fields, run-results task-run completed-at/latency/token usage fields, agentic harness IDs, artifact files, or response/patch artifact byte/SHA-256 fields are missing, invalid, future-dated, unknown, unsupported, incomplete, dirty, inconsistent, changed on disk, or mismatched against `taskRuns` / `manifest.json` / `run_results.v1.json` / `checksums.json`.
- Run artifact bundle manifests now store per-artifact SHA-256 digests alongside byte counts for response, patch, and trajectory artifacts; release-report readiness blocks manifests with missing/malformed artifact digests or manifest artifact digests that do not match `checksums.json`, and the custom Spark smoke `spark-manifest-digest-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, zero bundle warnings, a codegen aggregate-compatible leaderboard, and manifest artifact digests matching both the physical artifact file and checksum entry.
- `run_results.v1.json` now includes sanitized per-artifact metadata for exported response, patch, and trajectory artifacts, preserving stable relative path, byte count, and SHA-256 digest separately from the compatibility path map; release-report readiness blocks missing, malformed, or mismatched run-results artifact metadata, and the custom Spark smoke `spark-runresults-artifact-metadata-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, zero bundle warnings, a codegen aggregate-compatible leaderboard, and run-results artifact metadata matching `manifest.json` with zero release-report metadata mismatch counts.
- Run artifact bundle manifests and `run_results.v1.json` artifact metadata now include stable path-independent `artifactId` values for exported response, patch, and trajectory artifacts; release-report readiness blocks missing, malformed, duplicated, or mismatched artifact IDs, and the custom Spark smoke `spark-artifact-id-20260605` passed `state.bloc_debounce_cancellation` with zero bundle warnings, a codegen aggregate-compatible leaderboard, unique manifest artifact IDs, run-results artifact IDs matching `manifest.json`, and zero release-report artifact-ID mismatch counts.
- Public leaderboard model rows, task-model cells, trial summaries, run artifact bundle manifests, `run_results.v1.json`, and run provenance now carry normalized `baseModelId` plus structured `modelConfig` while preserving raw `modelId`; release-report readiness blocks missing or mismatched model identity metadata across leaderboard, manifest, and run-results rows. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-model-config-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded `baseModelId == modelId` and empty `modelConfig` for the custom Spark model across all public surfaces, and reported zero model-identity mismatch counters.
- Provider/model config provenance now preserves sanitized runtime metadata through run provenance, artifact-bundle manifests, `run_results.v1.json`, and public leaderboard rows, including Droid direct execution settings, Factory custom-model configured snapshot/provider/display metadata, and raw API max-output-token/retry settings where available, while release-report validation accepts those public `modelConfig` fields and still gates base-model/effort mismatches. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-provider-model-metadata-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded the sanitized custom Spark metadata across all public surfaces, reported zero model-identity mismatch counters, and produced no sensitive marker hits for API keys, authorization headers, base URLs, or Factory env references in the generated public JSON artifacts.
- Provider/model config normalization now records explicit temperature configuration status for raw API providers and Droid direct execution, using `provider_default` when the app does not set a temperature. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-temperature-metadata-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded `temperature.configured == false` and `temperature.status == provider_default` across provenance, manifest, `run_results.v1.json`, and leaderboard model/cell/trial rows, reported zero model-identity mismatch counters, and produced no sensitive marker hits for API keys, authorization headers, base URLs, or Factory env references in the generated public JSON artifacts.
- Generated-code sandboxing now uses Bubblewrap for Linux public-run prepare/evaluator subprocesses, binding only required SDK/cache/system paths read-only, binding the generated workdir read-write, using private temp/cache/stamp writes, and applying `--unshare-net` unless the task explicitly allows internet. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-bubblewrap-sandbox-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded `generatedCodeSandbox.required == true`, `enforced == true`, and `backend == bubblewrap` in manifest/provenance and leaderboard source provenance, reported no sandbox-enforcement release blocker, and produced no sensitive marker hits beyond expected public `factoryCustomModel` metadata.
- Generated-code task resource policy now has an effective default envelope for incomplete task declarations, filling missing limits with 2 CPUs, 8192 MB, 64 processes, and 1 MiB output, and the effective policy is used consistently for evaluator enforcement, run provenance, task artifacts, and task QA metadata. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-bubblewrap-resource-policy-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded Bubblewrap enforcement plus concrete `allowInternet=false` and resource policy metadata in manifest/provenance and leaderboard source provenance under the earlier resource-metadata gate, and produced no sensitive marker hits beyond expected public `factoryCustomModel` metadata.
- The official/public-run Bubblewrap sandbox contract is now documented in `docs/specs/2026-06-05-bubblewrap-public-run-sandbox.md`, covering required activation through `requireGeneratedCodeSandbox`, Linux/Bubblewrap/systemd-run fail-fast behavior, provider/model non-scope, mount/network/environment/resource-policy guarantees, cgroup-backed CPU quota enforcement, and explicit non-guarantees for cgroup memory/process limits, seccomp filtering, pinned OS images, and provider/model sandboxing.
- Bubblewrap hidden-verifier safety coverage now stages hidden verifier files outside the generated workdir, passes the staged root into Bubblewrap read-only, proves generated code cannot read hidden verifier source through the workspace `test/_hidden` path, blocks sandboxed verifier tampering, detects non-sandboxed staged-file tampering, and cleans up staged files after evaluation. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-bubblewrap-hidden-safety-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, exported aggregate-compatible leaderboard/release-report evidence, recorded Bubblewrap enforcement plus concrete `allowInternet=false` and resource policy metadata under the earlier resource-metadata gate, and produced no sensitive marker hits beyond expected public `factoryCustomModel` metadata.
- Task resource provenance now distinguishes declared limits from enforcement mechanisms via a `resourceEnforcement` map in run provenance, Task QA reports, artifact manifests, and leaderboard source provenance. The pre-cgroup Bubblewrap release-report gate correctly blocked evidence with CPU recorded as not enforced; CPU-limited generated-code prepare/evaluator subprocesses now run through `systemd-run --user --scope` around Bubblewrap with `CPUQuota=<cpus * 100>%`, and CPU provenance is recorded as `systemdCpuQuota` with `kernelEnforced=true`. The custom `gpt-5.3-codex-spark` one-trial codegen smoke `spark-cgroup-cpu-20260605` passed `state.bloc_debounce_cancellation` with aggregate score `1.0`, emitted zero bundle warnings, passed the release-report execution gate, and reported `manifestProvenanceTaskResourceLimitStatus == present`; the smoke release report remained blocked only by expected one-task/dirty-worktree/task-QA-scope blockers.
- Bubblewrap Flutter SDK cache handling now overlays the Flutter `bin/cache/lockfile` as a sandbox-local writable bind while keeping the SDK tree read-only, fixing a sandboxed official repeated-run failure where Flutter could not open the SDK cache lockfile during offline dependency resolution. Agentic workspaces also reset the patch baseline after initial dependency preparation and ignore benchmark tool-state paths such as `.dart_arena/`, `.flutter`, and `.config/tool_state`, so prepare/sandbox bookkeeping cannot be exported as candidate patches; regression coverage verifies both the lockfile overlay and prepared-baseline patch capture behavior.
- Release-report CLI now accepts repeated `--artifact-bundle-root` inputs and validates aggregate-compatible releases across multiple run bundles by matching each bundle's manifest run ID to its public leaderboard trial summaries, summing bundle readiness counters, fingerprinting bundle-relative inputs, and blocking when source run IDs are missing, extra, or duplicated; regression coverage verifies a two-run aggregate leaderboard with two complete bundle roots remains ready instead of falsely reporting missing or extra trial coverage.
- Run artifact bundle export tests now assert that produced `run_results.v1.json` artifact references match `manifest.json` artifact descriptors and that `checksums.json` covers every emitted bundle file except itself.
- Static leaderboard exports include sanitized model-by-task aggregate cells, and the public web surface renders them as a compact task matrix without exposing prompts, responses, hidden verifier output, or local paths.
- Static leaderboard exports include a sanitized source run-provenance readiness summary for selected runs, covering embedded provenance, generated-code sandbox enforcement, task execution policy metadata, SDK versions, dependency lockfile snapshots, pricing registry metadata, environment IDs, and compact warnings without exposing raw provenance or private paths.
- Release-report output validates the public leaderboard source run-provenance summary and cross-checks it against stored sanitized run provenance when a database is provided, so official release reports can catch missing or inconsistent public provenance metadata before publishing.
- Public leaderboard source run-provenance summaries and release-report readiness gates now separately audit network-disabled generated-code task policy coverage and concrete task resource-limit coverage, instead of only counting generic task policy presence.
- Task-model heatmap exports include aggregate error counts and median token/cost/duration metrics, and release-report output blocks official readiness if expected model/task cells are missing or lack required public metrics.
- Static leaderboard exports include pass@k summaries and capped sanitized per-trial summaries with outcome, public/hidden status, failure tag, latency, token, candidate cost, step count, peak-context, and blocked-check counts; the web surface renders a compact public trial browser, and release-report output blocks official readiness if trial transparency metadata is missing, truncated, or incomplete.
- Public leaderboard model, task, and task/model aggregate rows expose sanitized median step-count and peak-context metrics when agent harness metadata records them, plus explicit coverage counts when those metrics are unknown; release-report output blocks official readiness when task/model cells or trial summaries omit or contradict the public telemetry schema.
- Public leaderboard task and task/model aggregate rows now include Wilson confidence intervals alongside sample counts and pass rates, the web surface renders those intervals, and release-report output blocks official readiness when public confidence interval metadata is missing or incomplete.
- The public web surface explicitly labels low-sample and unknown-cost rows, including model table rows, task/model cells, and per-trial rows where candidate cost cannot be estimated.
- Static leaderboard exports include sanitized scoring-contract metadata for primary/ranking metrics, Wilson interval policy, LLM judge policy, objective/secondary evaluator IDs, hidden verifier pattern, failure tags, objective failure caps, and default evaluator weights; the web surface renders the core fields, and release-report output blocks official readiness when scoring metadata is missing or inconsistent.
- Hidden verifier output-flooding is now treated as an explicit hidden-verifier output-limit failure, with sanitized metadata and injected hidden files removed afterward.
- Release-report output now runs a count-only privacy audit over the public leaderboard export and blocks official readiness if it detects secret-looking keys/values, private local paths, hidden verifier content markers, private prompt fields, or raw model-output fields, without echoing the leaked values.
- Release-report output now includes a structured `readinessGates` matrix for corpus, execution, scoring, and reporting evidence, summarizing task QA coverage, hidden verifier audit coverage, stored/source provenance coverage, scoring metadata, judge-overhead metadata, public reporting completeness, privacy audit status, and input artifact fingerprint coverage.
- Generated-code workdirs are recreated cleanly inside `workdirRoot/runs` before fixtures and model output are written, so stale public files or previously injected hidden-test paths cannot carry across reused run/task paths.
- Generated-code subprocess environment scrubbing now removes common proxy variables (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, and `NO_PROXY`) case-insensitively unless explicitly allowlisted, preventing proxy credentials or network bypass settings from leaking into evaluator processes.
- Generated-code subprocess environment scrubbing now removes common credential-file, package-registry, and Git helper variables such as `NETRC`, `KUBECONFIG`, `DOCKER_CONFIG`, `NPM_CONFIG_USERCONFIG`, `PIP_INDEX_URL`, `UV_INDEX_URL`, `GIT_ASKPASS`, `GIT_SSH_COMMAND`, and `COMPOSER_AUTH` case-insensitively unless explicitly allowlisted.
- Agentic workdir baseline Git initialization now runs with the same scrubbed subprocess environment and no inherited parent environment, removes home/XDG config roots, disables system Git config and terminal prompts, and has regression coverage using a fake Git executable to verify denied variables are absent.

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

- [x] **Blocked evaluator semantics**
  - [x] Add `blocked`/`blockedBy` details to evaluator results or a compatible representation.
  - [x] Update UI/export to show blocked checks separately from failed checks.
  - [x] Add regression tests for compile-failed and harness-failed runs.

- [x] **Task QA admission reports**
  - [x] Expand task QA with no-op/API-breaking/overfit negative solutions.
  - [x] Write JSON admission reports for each task.
  - [x] Add CI/headless command to validate the active corpus.

- [x] **Hidden verifier and failure taxonomy polish**
  - [x] Ensure all hidden verifier IDs classify as objective.
  - [x] Add clearer hidden/public pass split to exports and UI.
  - [x] Add blocked and infrastructure failure tags to public reports.

- [x] **File-backed task bundle loader**
  - [x] Define `task.yaml` schema.
  - [x] Load public development bundles from disk.
  - [x] Keep code-defined tasks supported during migration.

- [x] **Sandbox hardening**
  - [x] Scrub generated-code process environments.
  - [x] Add process/resource/network controls.
    - Progress: Bubblewrap is selected and wired through generated-code prepare/evaluator subprocesses for codegen and agentic grading paths when `requireGeneratedCodeSandbox` is enabled. Current work covers Bubblewrap mount/network isolation, documented official/public-run Bubblewrap guarantees and unsupported fallback behavior, environment scrubbing with provider-only Factory custom model credential allowlisting, proxy-variable removal, credential-file and package-registry pointer removal, generated-code prepare/evaluator home and user-config environment isolation with default `PUB_CACHE` preservation and isolated Dart analyzer state roots, scrubbed helper subprocess environments for resource probes, process-tree cleanup, patch capture, provenance capture, and bundle export metadata, scrubbed baseline Git initialization for agentic workdirs with global/system config and prompts disabled plus timeout/process-tree cleanup and bounded output, bounded patch-capture Git output with timeout/process-tree cleanup, sanitized Droid direct-provider failure diagnostics without prompt/local-path echoing, sanitized agent-harness metadata storage without raw workspace/executable/command values, hidden verifier staged-file cleanup, explicit effective task network/resource policy metadata in file-backed tasks, task QA, provenance, and artifacts, network-disabled prepare enforcement for offline dependency resolution, evaluator and prepare timeout/process-tree cleanup with cancellable timeout timers on successful completion, bounded live prepare output with process-tree termination and no online retry after prepare output floods, shared bounded subprocess output for public/hidden test, analyze, compile, widget-tree, and test-author evaluators, bounded live Droid agent-harness and direct-provider output with process-tree termination, default effective task resource limits for output/process/RSS memory evaluator enforcement, systemd-run cgroup CPU quota enforcement around Bubblewrap for generated-code prepare/evaluator subprocesses, explicit resource-enforcement mechanism provenance, codegen executor coverage proving task output/process/memory policies reach real public-test subprocesses, adversarial analyze process-count and memory exhaustion cleanup tests, Bubblewrap filesystem/network/policy/prepare integration tests including private temp mounts, read-only system-bind write blocking, allowed-network loopback reachability, sandboxed CPU cgroup wrapping, sandboxed process-count enforcement, sandboxed output-limit enforcement, sandboxed RSS memory-limit enforcement, sandboxed hidden-verifier read-only staging and tamper blocking, and Spark evidence including `spark-cgroup-cpu-20260605` proving the release-report execution gate now accepts enforced task resource provenance.
    - Progress: Bubblewrap now provides a writable sandbox-local overlay for Flutter's SDK cache lockfile while keeping the Flutter SDK read-only, and agentic patch capture resets the baseline after initial dependency preparation so sandbox/prepare bookkeeping is not attributed to model patches.
  - [x] Add adversarial harness safety tests.
    - Progress: adversarial tests cover environment scrubbing, proxy-variable scrubbing, generated-code prepare/evaluator home and user-config environment isolation, isolated analyzer state-root metadata, credential-file and package-registry pointer scrubbing, scrubbed and config-isolated baseline Git initialization, scrubbed patch-capture Git helper environments, output-flooding patch-capture Git diffs, patch-capture child-process cleanup after output floods, scrubbed evaluator resource-probe helper environments, scrubbed provenance helper environments, hanging and output-flooding baseline Git commands, prompt child-process shutdown after successful evaluator runs with long timeouts, analyze timeout cleanup, analyze process-count and memory exhaustion cleanup, codegen executor task policy propagation for public-test output/process/memory caps, compile output flooding, path escape protection, clean generated-code workdir recreation, hidden/reference asset exclusion, hidden verifier staged-file tamper detection, hidden verifier staged-file cleanup, hidden-test read attempts against workspace `test/_hidden`, malformed policy rejection, network-disabled dependency prepare behavior, Bubblewrap no-network loopback isolation, Bubblewrap allowed-network loopback reachability, Bubblewrap private temp and read-only system-bind checks, Bubblewrap CPU cgroup wrapping, Bubblewrap process-count enforcement, Bubblewrap output-limit enforcement, Bubblewrap RSS memory-limit enforcement, Bubblewrap hidden-verifier read-only staging and tamper blocking, release-report regression coverage for missing/incomplete/unenforced resource-limit provenance, output-flooding dependency prepare behavior, runaway processes, deterministic public output flooding including fast-exiting flooded test processes, hidden-verifier output flooding, hidden verifier cleanup, Droid agent harness stdout-flood termination with bounded previews, Droid direct provider stdout-flood termination with bounded diagnostics, Droid direct-provider failure diagnostics without prompt/local-path leakage, agent-harness metadata storage without raw path/command/credential-like values, and no-preview harness failure bundle evidence with response artifacts plus missing-patch warnings.
    - Progress: focused sandbox regressions now also cover Flutter SDK cache lockfile overlay command construction and prepared-baseline patch capture that excludes `.dart_arena`, `.flutter`, `.config/tool_state`, and other dependency-prepare artifacts from model patches.

- [x] **Official release/reporting pass**
  - [x] Run repeated trials.
    - Completed: `spark-sandboxed-official-repeated-clean-20260605` used the selected custom `gpt-5.3-codex-spark` / Droid model from `~/.factory/settings.json`, Bubblewrap enforcement via `requireGeneratedCodeSandbox: true`, all five active private-official Flutter tasks, and two trials per task. It produced 10 task runs, 60 evaluator records, zero bundle warnings, 7/10 primary passes, and 20 response/patch artifacts from a clean committed worktree.
    - Prior scratch evidence: `spark-sandboxed-official-repeated-proxy-20260605` used the same selected model/tasks/sandbox settings before the clean-provenance commit and produced 10 task runs, 60 evaluator records, zero bundle warnings, 10/10 primary passes, and 20 response/patch artifacts, but its release report remained blocked by dirty git provenance.
    - Superseded blocked evidence: one-trial custom `gpt-5.3-codex-spark` smokes exercised the active private-official tasks, the earlier local repeated validation run `spark-official-repeated-20260605` produced 8/10 primary passes before the corrected `state.selection_controller` hidden verifier, and `spark-sandboxed-official-repeated-baseline-20260605` proved Bubblewrap/resource provenance but failed all 10 Droid harness invocations before patch generation.
    - Blocked: the sandboxed repeated custom Spark/Droid run `spark-sandboxed-official-repeated-baseline-20260605` covered all five active private-official Flutter tasks with two trials each under `requireGeneratedCodeSandbox: true`, produced 10 task runs and 60 evaluator records, and recorded Bubblewrap enforcement plus `systemdCpuQuota` CPU resource enforcement for every task. All 10 Droid agent harness invocations exited with `harness_error` before producing patches, so the run is valid blocked infrastructure evidence but not publishable repeated trial performance data.
  - [x] Export compatible aggregate leaderboard data.
    - Completed: `leaderboard.sandboxed-official-repeated-clean.aggregate.v1.json` was exported with `--strategy aggregate-compatible --run-id spark-sandboxed-official-repeated-clean-20260605`, contains one source run, 5 tasks, 10 trial summaries, 10 samples for `custom:gpt-5.3-codex-spark---Codex`, aggregate pass rate 0.7, pass@1/pass@2 rates of 0.8, public pass rate 1.0, hidden pass rate 0.7777777777777778, Bubblewrap source provenance, and explicit unknown Droid trace/token/cost telemetry coverage.
  - [x] Publish release provenance and verifier-audit summary.
    - Completed: `release_report.sandboxed-official-repeated-clean.v1.json` was generated for `spark-sandboxed-official-repeated-clean-20260605` from the aggregate leaderboard, the run artifact bundle, the run database, and task QA report root. The report has `status == ready`, no blockers, corpus/execution/scoring/reporting readiness gates passed, 5/5 leaderboard tasks covered by task QA, zero bundle warnings, 20 verified response/patch artifacts, clean manifest git metadata, Bubblewrap sandbox provenance, concrete task resource-policy provenance, complete checksum/run-results/results.csv/report.md coverage, valid trial-summary coverage, public privacy audit passed, and expected warnings for unknown Droid trace metrics, token usage, and candidate cost.
    - Completed: release-report CLI support now validates stored run provenance with generated-code sandbox enforcement and backend, task execution policy/resource metadata, network-disabled task policy coverage, CPU/memory/process/output resource-limit coverage, SDK versions, dependency lockfile hashes, pricing registry metadata, benchmark version/task-set/evaluator schema metadata, scoring-contract metadata, judge-overhead and source run-provenance summaries, task QA admission reports, active private-official corpus metadata, hidden verifier digest and flake evidence, negative-case audit entries, verifier-quality summaries, input artifact fingerprints, bundle manifests, checksums, standard bundle outputs, `run_results.v1.json`, `results.csv`, `report.md`, safe artifact paths, response/patch artifacts for every agentic task run, matching bundle and leaderboard trial coverage, pass-consistent task-run outcomes, evaluator evidence, sanitized agent-harness status metadata, model/task heatmap cells, pass@k/trial summaries, and structured readiness gates for corpus, execution, scoring, and reporting evidence.
    - Superseded blocked evidence: `release_report.sandboxed-official-repeated-baseline.v1.json` proved the audit path for a sandboxed repeated run with all 10 harness failures, and `release_report.sandboxed-official-repeated-proxy.v1.json` proved the post-proxy artifacts before commit; both are replaced by the clean ready report above.

## Definition of done for reliability work

- Objective pass/fail is explainable from stored evaluator details.
- LLM judge cannot raise a failed objective result into a competitive score.
- Prompt context exposes required contracts without leaking solutions.
- Every benchmark-grade task has reference, negative, and hidden QA coverage.
- Official tasks have file-backed artifacts, admission reports, and pinned verifier metadata.
- Public benchmark exports include trials, errors, cost, tokens, duration, and primary failure tags.
- Full validators pass: formatting, analyze, focused reliability tests, and full test suite when code changes.
