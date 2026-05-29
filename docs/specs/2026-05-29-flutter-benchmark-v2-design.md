# Flutter Benchmark v2 — Design Spec

**Date:** 2026-05-29
**Status:** Draft
**Purpose:** Upgrade `dart_arena` from a small Dart/Flutter code-generation benchmark into a reliable Flutter software-engineering benchmark for real developer agents.

## 1. Goal

Create a benchmark that answers:

> Which models and agents can reliably complete realistic Flutter development work end-to-end?

The benchmark should preserve the existing fast single-shot workflow while adding a higher-signal agentic workflow with hidden behavioral verification, realistic Flutter tasks, statistical reporting, and optional blind human review.

## 2. Current context

The current app already has useful foundations:

- Flutter desktop app with persisted runs, leaderboard, filters, run details, CSV/Markdown export.
- 12 task classes across UI, state management, bug fix, refactor, widget testing, and planning/execution.
- Evaluators for compile/analyze/test/widget tree/test-author mutation/LLM judge/diff size.
- Provider abstraction with raw API and agent provider modes.
- Token and latency persistence.

The current benchmark is limited by:

- single-shot prompt → one Dart code block → one generated file;
- small synthetic fixture packages;
- visible tests and rubrics;
- no hidden verifier lifecycle;
- no true inspect/edit/test/iterate agent loop;
- no repeated trials, confidence intervals, or failure taxonomy;
- limited Flutter-specific validation depth.

## 3. Non-goals

- Replacing the existing codegen benchmark track.
- Building a hosted SaaS or shared public leaderboard.
- Fully emulating every native agent product in the first pass.
- Guaranteeing mobile/iOS simulator coverage in early phases.
- Making LLM judgment the primary correctness signal.

## 4. Benchmark tracks

### 4.1 Codegen track

The existing mode remains:

1. prompt model;
2. extract Dart/code response;
3. write one generated file;
4. run evaluators.

This is useful for fast model sweeps and regression checks, but should be labeled clearly as **single-shot codegen**.

### 4.2 Agentic Flutter dev track

The new flagship mode:

1. create a clean workspace;
2. give the agent natural instructions;
3. allow file inspection, edits, test runs, and iteration;
4. capture the final patch and trajectory;
5. inject hidden verifiers only at grading time;
6. grade public behavior, hidden behavior, regression safety, and secondary quality metrics.

## 5. Phased roadmap

| Phase | Name | Dependency | Purpose | Primary outcome |
|---|---|---|---|---|
| 1 | Benchmark integrity | None | Hidden verifiers and task QA | Existing task style becomes harder to game and easier to trust |
| 2 | Agentic track | Phase 1 hidden verifier primitives | Patch-based multi-file agent runs | Benchmark can evaluate real Flutter dev agents |
| 3 | Flutter corpus | Phase 1 for codegen tasks; Phase 2 for multi-file tasks | Original realistic tasks | Task suite reflects real Flutter work |
| 4 | Reliable leaderboard | Can start after Phase 1; most useful after Phases 2–3 | Repeats, CIs, costs, failures | Scores become statistically interpretable |
| 5 | Human review | Best after Phase 4 | Blind subjective quality ranking | UI/code quality gets a preference signal |

Phase 1 should start with a tight MVP: add hidden verifier metadata and a hidden test evaluator, convert two current tasks, and add a task QA runner that proves baseline-fail/reference-pass/repeated-pass before widening scope.

## 6. Task artifact model

Long-term task artifacts should be explicit and versioned:

```text
task_id/
  task.yaml
  instruction.md
  workspace/
  public_tests/
  hidden_tests/
  reference/
    solution.patch
    notes.md
  validate.sh
```

Early phases can implement the same concept in Dart task classes before moving to fully file-based task manifests.

In the current codebase, this means extending `BenchmarkTask` in `lib/core/benchmark_task.dart` without breaking existing tasks:

- `fixtures` remains the visible workspace input;
- hidden verifier fixtures must be stored separately and never passed to `WorkdirManager.createTaskWorkdir`;
- `generatedCodePath` remains codegen-only;
- task `version`, `track`, tags, and difficulty should have safe defaults for legacy tasks.

### Required metadata

- `id`
- `version`
- `category`
- `track`
- `difficulty`
- `prompt`
- `visible fixtures`
- `hidden verifier fixtures`
- `reference solution`
- `required commands`
- `timeout`
- `Flutter/Dart SDK expectations`
- `platform requirements`

Early implementations should keep metadata additive. Existing task constructors and `evaluatorsFor` implementations should compile without changes until each task opts into v2 fields.

## 7. Verification principles

Primary scoring should be hidden behavioral pass/fail.

Verifiers should:

- test public observable behavior;
- avoid private helper/function-name coupling;
- accept multiple valid implementations;
- run existing regression tests;
- reject solutions that only satisfy visible tests;
- avoid flaky timing, sleeps, and network dependence;
- be reviewed for prompt-verifier bijection.

Task admission should require:

1. baseline workspace fails the hidden verifier;
2. reference solution passes all verifiers;
3. verifier passes repeated flake runs;
4. task prompt matches verifier scope;
5. hidden tests are not copied into the agent workspace.

For this local repository, "hidden" means hidden from the generated/agent workspace and from model prompts at runtime. If hidden tests are committed as repo assets, they still carry public-repository contamination risk; plans and reports should describe that limitation instead of treating local hidden tests as secret from a determined agent with repository access.

## 8. Scoring model

Primary score:

```text
hidden_behavioral_pass_rate
```

Secondary dimensions:

- public test pass rate;
- regression safety;
- analyzer cleanliness;
- cost;
- wall-clock duration;
- input/output tokens;
- diff size;
- self-verification behavior;
- human preference score;
- LLM judge quality score.

The aggregate score can remain for legacy views, but the reliable leaderboard should lead with pass rate and uncertainty.

## 9. Flutter-specific validation

The v2 benchmark should cover:

- widget tests;
- golden tests;
- semantics/accessibility;
- dark/light theme;
- responsive layouts;
- localization and RTL;
- navigation and deep links;
- BLoC/Cubit/Riverpod/Provider state behavior;
- integration tests where feasible;
- `build_runner`/generated-code workflows;
- dependency upgrade/migration tasks;
- platform-channel/plugin mocks;
- performance and rebuild smoke tests.

## 10. Data and reporting

Store enough evidence to audit results:

- task version;
- track/mode;
- trial number;
- agent harness;
- model and effort;
- prompt/response tokens;
- latency;
- estimated cost;
- final patch;
- evaluator outputs;
- hidden verifier summary;
- failure taxonomy;
- trajectory/log path where applicable.

Persistence should remain backward-compatible. New rows should record task version, track, harness ID, trial index, primary pass/fail, and failure tag when available; old rows should be interpreted with safe defaults.

Leaderboard rows should show:

- pass rate ± confidence interval;
- number of tasks/trials;
- median cost;
- median duration;
- median tokens;
- failure breakdown;
- rank uncertainty warnings.

## 11. Anti-gaming and contamination

The agent workspace must not contain:

- reference patches;
- hidden tests;
- gold commits;
- hidden verifier names;
- task authoring notes.

Agentic runs should use:

- clean workspaces;
- shallow/no-history repositories where possible;
- hidden tests injected only after final patch;
- optional network disablement;
- trajectory capture for suspicious behavior.

Do not rely on file names such as `hidden_test.dart` being secret once the repository is public. Runtime isolation prevents accidental leakage into prompts and workspaces, while stronger contamination resistance requires unpublished task artifacts, no git history in agent workspaces, and review of trajectory logs for attempts to read authoring assets.

## 12. Recommended implementation sequence

1. Add hidden verifier support to current single-shot tasks.
2. Add task QA tooling and convert two existing codegen tasks as the Phase 1 MVP.
3. Convert the test-authoring task pattern once the MVP evaluator path is stable.
4. Add patch-based agentic run mode with one standardized harness.
5. Author 10–25 realistic Flutter tasks using the new format.
6. Add repeated-trial analytics and confidence intervals.
7. Add blind pairwise human review after the correctness foundation is solid.

## 13. Success criteria

The v2 benchmark is successful when:

- a task can hide tests from the model and inject them only during grading;
- a reference solution is validated automatically;
- an agent can edit multiple files and submit a patch;
- results include confidence intervals over repeated trials;
- Flutter-specific tasks catch failures that generic SWE benchmarks miss;
- leaderboard differences are explainable through trajectories and failure tags.
