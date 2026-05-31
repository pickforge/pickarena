# Dart Arena Benchmark Reliability Master Spec

Status: active master spec
Created: 2026-05-31

## Goal

Make Dart Arena a trustworthy Flutter/Dart model benchmark where headline scores reflect objective task success, subjective evaluators cannot mask hard failures, tasks are fair but not leaky, and runs are reproducible enough to compare models over time.

## Reliability principles

1. **Objective correctness first**: compile, analyze, tests, hidden verifiers, and widget checks determine pass/fail.
2. **LLM judge is secondary**: judge scores are diagnostics/tie-breakers, never authority over objective failures.
3. **Fair prompts, no solution leakage**: models must see required public API/skeleton contracts, but never full reference implementations or hidden verifiers.
4. **Reproducible runs**: every result should be traceable to task versions, evaluator versions, run config, model IDs, prompts, and artifacts.
5. **Clear failure taxonomy**: users should understand whether a result failed, was blocked, timed out, hit infrastructure issues, or broke API compatibility.
6. **Safe execution**: generated code should run with bounded time, output, filesystem, environment, and eventually network/resource isolation.

## Current baseline

Already implemented:

- Headless JSON CLI with reproducible bundle export.
- Primary pass/failure tags for objective reliability.
- Safe prompt API/skeleton context for codegen tasks.
- Objective aggregate caps:
  - compile failure: max `0.20`
  - analyze failure: max `0.35`
  - public/hidden/widget/test-author failure: max `0.60`
- LLM judge skipping when previous objective evaluators failed.
- LLM judge context enrichment with target API/skeleton, public test snippets, and prior objective summaries.
- UI status for ignored/skipped evaluator results.
- Regression coverage for the `state.counter_bloc` missing-`const` constructor case.

## Headline metrics

Use these as primary ranking metrics:

- `primary_pass` / pass@1
- pass@k when multiple trials are configured
- confidence intervals for repeated trials
- failure breakdown by normalized `failure_tag`

Use these only as secondary diagnostics:

- weighted aggregate score
- `llm_judge`
- `diff_size`
- speed/latency
- estimated cost
- elegance/readability dimensions

## Roadmap

### Phase 1: Blocked evaluator semantics

Problem: one root cause can currently produce multiple objective `0`s, which is technically correct but confusing.

Design:

- Add blocked evaluator representation for downstream checks that cannot run meaningfully after an earlier hard failure.
- Example:
  - compile fails
  - tests are reported as `blocked_by_compile`, not as an independent behavioral failure
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

### Phase 4: Statistical reporting

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

### Phase 5: Execution sandboxing

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

### Phase 6: Public benchmark governance

Problem: public leaderboards need stable versioning and reproducibility rules.

Design:

- Freeze benchmark releases by task set, task versions, evaluator versions, and scoring schema.
- Store provenance bundles for official runs.
- Separate tracks:
  - Dart codegen;
  - Flutter UI/widgets;
  - agentic Flutter dev tasks.
- Require CI validation before publishing official results.

Success criteria:

- A score can be traced to an immutable benchmark version.
- Results from different benchmark versions are not mixed silently.
- Official leaderboard entries have reproducible artifacts.

## DeepSWE alignment addendum

DeepSWE is a useful north star for turning Dart Arena from a useful local benchmark into a trusted public benchmark. Dart Arena is directionally aligned, especially after objective scoring, hidden verifiers, task QA, and headless exports, but it is not yet DeepSWE-grade.

### DeepSWE reference model

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

### What Dart Arena already has

Dart Arena already aligns with several DeepSWE principles:

- Benchmark tasks encode prompts, fixtures, generated paths, hidden verifiers, and reference solutions.
- Objective evaluators include compile, analyze, public tests, hidden tests, widget/golden checks, and task-specific verifiers.
- Hidden verifier failures are classified as objective failures.
- LLM judges are secondary and skipped or ignored after objective failures.
- Task QA validates baseline hidden failure and reference public/hidden success, including repeated hidden flake runs.
- Headless runs and exports provide a reproducible foundation for public reporting.
- Existing Phase 3 seed tasks cover Flutter-relevant areas:
  - BLoC cancellation;
  - Riverpod stale cache;
  - responsive UI/goldens;
  - localization and RTL behavior;
  - flaky widget test repair;
  - rebuild performance;
  - `go_router` auth redirects;
  - code generation migration;
  - platform channel mocks;
  - large-screen behavior-preserving refactors.

### Gaps versus DeepSWE

Current gaps:

- The official corpus is still small relative to DeepSWE.
- Many tasks are fixture/codegen-style rather than long-horizon repo-level agent tasks.
- Public in-repo task definitions risk future training contamination.
- Environment isolation is not yet as strong as pinned containerized verifier execution.
- Official task artifacts are code-defined rather than portable file-backed bundles.
- Verifier admission reports and false-positive/false-negative audits are not yet first-class.
- Result exploration does not yet match DeepSWE's public task/model/trial heatmaps with cost, tokens, duration, steps, context, and error filters.

### Flutter-focused benchmark strategy

Dart Arena should keep separate tracks:

- **Fast Dart codegen track**: small deterministic tasks for quick local model checks.
- **Flutter widget/UI track**: visible UI behavior, semantics, golden, localization, layout, and interaction tests.
- **Agentic Flutter dev track**: flagship DeepSWE-equivalent track where agents modify full Flutter repositories by patch.

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

### DeepSWE-style Flutter task artifact format

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

### Flutter verifier strategy

Official Flutter verifiers should prioritize observable behavior:

- `flutter analyze` as a required objective gate.
- Pure Dart unit tests for algorithms, domain logic, and state machines.
- Widget tests for visible user behavior, interactions, responsive layout, semantics, theming, localization, and RTL behavior.
- Golden tests only when visual fidelity is part of the task contract.
- Integration tests for navigation, persistence, platform channels, lifecycle, and end-to-end flows.
- Performance/rebuild tests for tasks whose purpose is performance.
- Hidden tests that validate behavior through public surfaces, not reference implementation shape.

LLM judge remains diagnostic only. It may help explain quality, tradeoffs, or partial behavior, but must never override objective compile/analyze/test/hidden verifier failures.

### Task admission and verifier audit requirements

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

### Contamination and corpus governance

Use two corpora:

- **Public diagnostic corpus**: open tasks for development, smoke testing, examples, and local comparisons.
- **Private official corpus**: non-public/unmerged or otherwise contamination-resistant tasks used for official leaderboards.

Governance rules:

- Add benchmark canary strings to public benchmark data.
- Retire exposed official tasks into the public diagnostic corpus after a benchmark cycle.
- Do not mix public diagnostic scores with official private-corpus leaderboard scores.
- Version official releases by task set, task versions, evaluator versions, scoring schema, SDK, and environment.

### Public data and efficiency metrics

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

Headline metrics should be:

1. primary pass rate;
2. cost per primary pass;
3. median duration;
4. error rate;
5. confidence interval and trial count.

## Next recommended implementation

Start with **Phase 1: Blocked evaluator semantics**, **Phase 2: Task QA expansion**, and a first pass at the **DeepSWE-style Flutter task artifact format**. These directly address confusing “0 in everything” results, improve trust without requiring heavy infrastructure, and establish the path toward an agentic Flutter benchmark track.

## Definition of done for reliability work

- Objective pass/fail is explainable from stored evaluator details.
- LLM judge cannot raise a failed objective result into a competitive score.
- Prompt context exposes required contracts without leaking solutions.
- Every benchmark-grade task has reference, negative, and hidden QA coverage.
- Official tasks have file-backed artifacts, admission reports, and pinned verifier metadata.
- Public benchmark exports include trials, errors, cost, tokens, duration, and primary failure tags.
- Full validators pass: formatting, analyze, focused reliability tests, and full test suite when code changes.
