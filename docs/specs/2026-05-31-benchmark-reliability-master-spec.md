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

## Next recommended implementation

Start with **Phase 1: Blocked evaluator semantics** and **Phase 2: Task QA expansion**. These directly address confusing “0 in everything” results and improve trust without requiring heavy infrastructure.

## Definition of done for reliability work

- Objective pass/fail is explainable from stored evaluator details.
- LLM judge cannot raise a failed objective result into a competitive score.
- Prompt context exposes required contracts without leaking solutions.
- Every benchmark-grade task has reference, negative, and hidden QA coverage.
- Full validators pass: formatting, analyze, focused reliability tests, and full test suite when code changes.
