# PickArena task multiplication workflow

Status: active note
Created: 2026-06-19

## Goal

Scale PickArena tasks from V1 Flutter breadth toward DeepSWE-grade rigor without turning every candidate into an expensive 5-agent project.

Use `pi-subagents` for this workflow because it supports exact model ordering, saved artifacts, `clarify: false`, and one-writer handoffs. Use pi-crew/team for broader generic implementation/review work, not the model-sensitive authoring panel.

## Required docs

Read these before creating or reviewing a task:

| Need | Source |
| --- | --- |
| Benchmark direction, MVP/V1/V2/DeepSWE standards | `docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md` |
| Task bundle rules, task-card template, authoring-agent counts, prompt/hidden/negative-case standards | `tasks/AUTHORING.md` |
| Current official tasks and QA commands | `tasks/README.md` |
| V1 first-wave backlog and promotion order | `docs/plans/2026-06-18-v1-flutter-task-backlog.md` |
| First-wave readiness checkpoint | `docs/plans/2026-06-19-first-wave-deepswe-readiness.md` |
| Final DeepSWE blockers and approval packets | `docs/plans/2026-06-19-final-deepswe-completion-blocker-audit.md`, `docs/plans/2026-06-20-clean-provenance-approval-packet.md`, `docs/plans/2026-06-20-droid-bubblewrap-auth-approval-packet.md`, `docs/plans/2026-06-20-provider-session-export-decision-packet.md` |
| Agent-assisted authoring rationale and checklist | `docs/plans/2026-06-15-agent-assisted-task-authoring.md` |
| Existing bundle patterns | `tasks/flutter/*/{task.yaml,instruction.md,baseline,hidden_tests,solution,negative_cases}` |
| Current vertical-slice reference task | `tasks/flutter/async.refresh_deduplicator/` |
| Official bundle regression expectations | `app/test/tasks/official_file_backed_task_test.dart` |

Use this file for the workflow and model-count policy. Use `tasks/AUTHORING.md` for the concrete task standards.

## Model order

For authoring panels, use the first N models in this order:

1. GPT 5.5 Xhigh
2. Opus 4.8 Xhigh
3. GLM 5.2 (Ollama) Xhigh
4. Kimi K2.7 Code (Ollama) Xhigh
5. MiniMax M3 (Ollama) Xhigh

For bundle implementation, keep the preferred loop:

1. GPT 5.5 Xhigh planner
2. Opus 4.8 Xhigh coder
3. Opus 4.8 Xhigh reviewer

Always pass `clarify: false` for subagent chains unless the preview UI is explicitly wanted.

## Tiered workflow

```txt
coverage slice
  -> candidate cards
  -> shortlist
  -> draft bundle
  -> cheap QA pre-check
  -> verifier red-team
  -> fresh solver attempts
  -> admission QA
  -> active corpus
  -> optional DeepSWE hardening
```

## Agent counts

| Count | Use for |
| --- | --- |
| 2 agents | Routine V1 Flutter card generation and self-triage. |
| 3 agents | First task in a new family, risky V1 task, or V1+ red-team. |
| 5 agents | DeepSWE-grade, security, cross-framework parity, or flagship public-claim tasks. |

Do not equate agent count with rigor. Model-family diversity and role separation matter more.

## Current first-wave checkpoint

As of 2026-06-20, the first-wave bundles are admitted, have V1+ evidence, and have accepted DeepSWE artifact slices. Cross-slice readiness is tracked in `docs/plans/2026-06-19-first-wave-deepswe-readiness.md`.

Do not call the first wave a DeepSWE finish: all slices keep `deepSWEComplete: false`. `ui.action_bar_overflow` has contract-repaired accepted evidence with promoted GPT, MiniMax, and Kimi solver runs, while GLM remains retained failed-solver evidence.

Clean committed V2 local replay is complete. Further progress is approval-gated: Droid/Bubblewrap auth strategy, provider/session export decision, and authored-by provenance must be resolved before any DeepSWE completion claim.

## Phase 1: coverage slice

Pick one gap before generating tasks. Examples:

- async/state races
- accessibility semantics
- behavior-preserving refactors
- offline persistence
- responsive UI
- localization/theme
- navigation result passing
- mobile security
- cross-framework parity

Output goes in `docs/plans/` as a short backlog note.

## Phase 2: candidate cards

Run 2 agents by default. Each agent generates and self-scores up to 8 task cards.

Task card fields:

```md
id:
framework:
category:
difficulty target:
developer prompt idea:
baseline bug / missing behavior:
expected fix surface:
public smoke behavior:
hidden behaviors:
p2p preservation:
negative cases:
fake-fix risks:
flake risks:
why this task matters:
score / keep-revise-reject:
```

Reject cards that need live network, sleeps, credentials, brittle screenshots, or emulator state unless they are explicitly V2/DeepSWE candidates.

## Phase 3: shortlist

Human picks the top cards. Promote only cards that are realistic, bounded, verifiable, fake-fix resistant, stable, and additive to coverage.

Keep second-wave cards in the backlog. Do not create bundles for low-confidence ideas.

## Phase 4: draft bundle

Create the normal bundle shape:

```txt
tasks/<framework>/<task-id>/
  task.yaml
  instruction.md
  baseline/
  hidden_tests/
  solution/
  negative_cases/
  qa/admission_report.json
```

Creation order:

1. `instruction.md` — natural developer request, no hidden paths/names.
2. `baseline/` — realistic bug and public smoke tests.
3. `hidden_tests/` — behavioral f2p/p2p checks.
4. `solution/` — minimal reference fix.
5. `negative_cases/` — noop, api_breaking, overfit, plus custom V1+/V2 cases.
6. `task.yaml` — paths, metadata, verifiers, resources.

Keep baselines realistic. Do not shape strange code only to satisfy diff-size.

## Phase 5: cheap QA pre-check

Before spending 3-5 red-team agents, run task QA once.

Minimum pre-check:

- baseline fails hidden target behavior
- reference passes public and hidden
- required negatives are rejected
- no obvious analyzer/schema failures

If this fails, fix the task before running the panel.

## Phase 6: verifier red-team

Use 3 agents for promoted V1/V1+ tasks and 5 agents for DeepSWE/security/cross-framework tasks.

V1 red-team output can stay short:

```md
blockers:
fake-pass attempts:
admit / revise / reject:
```

DeepSWE red-team output should add:

```md
recommended hidden checks:
recommended p2p checks:
recommended negative cases:
flake risks:
leakage risks:
```

Human merges only actionable verifier improvements. Do not bloat `instruction.md`.

## Phase 7: fresh solver attempts

Solvers must not be the same model family that authored or red-teamed the task.

Rules:

- V1 routine: 1-2 solvers.
- V1+/V2: 2-3 solvers.
- DeepSWE: 3-5 solvers.
- Every solver set should include at least one off-panel model family.
- Solver sees only `instruction.md` and `baseline/`.
- Solver never sees hidden tests, solution, negative cases, or author notes.

Interpretation:

- repeated same failure means prompt ambiguity or missing context
- easy universal passes may mean task is too easy
- fake passes become new negative cases
- correct-looking failures may mean verifier is too strict

## Phase 8: admission QA

Run from `app/`:

```sh
dart run --verbosity=error dart_arena:dart_arena_task_qa \
  --task-bundle-root ../tasks/flutter \
  --task <task-id> \
  --out build/task_qa_<task-id>
```

Then copy the admitted report to:

```txt
tasks/<framework>/<task-id>/qa/admission_report.json
```

Run the official bundle regression:

```sh
flutter test test/tasks/official_file_backed_task_test.dart
```

## Tier gates

| Tier | Gate |
| --- | --- |
| V1 | Structure resolves, prompt leak-free, baseline f2p, reference public+hidden pass, noop/api_breaking/overfit rejected, p2p covered, flake runs clean, QA report committed. |
| V1+ | V1 plus deleted/weakened public-test negative, hidden fixture literal audit, 3-agent red-team with no blockers, 2+ solver attempts. |
| V2 | V1+ plus cross-framework/security/runtime breadth where relevant, stronger flake evidence, duration/cost/error capture where available. |
| DeepSWE | V2 plus clean patch replay, isolated agent/verifier/grading workspaces, explicit prompt-verifier bijection artifact, solver trajectories, artifact leakage scan, authored/red-teamed/solved model audit. |

V1 admission must not require DeepSWE artifacts. DeepSWE is an additive hardening path.

## Anti-model-shaping rules

Track these per task, even if only in private notes at first:

```yaml
authored_by:
red_teamed_by:
solved_by:
```

Rules:

- authoring models should not be the only solver families
- at least one solver should be off-panel
- periodically run a weaker/cheaper solver; if it trivially passes, the task may be too easy
- do not publish authoring transcripts for active official tasks

## Automation path

Do this in stages:

1. Use this note manually for the next 2-3 tasks.
2. If stable, create saved `pi-subagents` chains for:
   - candidate cards
   - verifier red-team
   - solver attempts
3. Keep bundle implementation as a separate GPT-planner -> Opus-coder -> Opus-reviewer loop.
4. Only automate DeepSWE hardening after V1 task creation is repeatable.
