# Plan 8 (roadmap stub) — Planning + Execution Benchmark

> **Status:** Roadmap stub. Not yet specced. Brainstorm + write the full plan doc when ready to start.

## Goal

Measure each model's ability to **plan** and **execute** as separate, gradable skills — not just "can it produce working code in one shot." Mirrors the cascade used in real agentic workflows (e.g., Factory droid skills: brainstorm → spec → plan → execute), where one model often plans and another (or the same) executes.

The current benchmark only measures single-shot code generation. A strong one-shot coder may be a weak planner; a strong planner may be a mediocre executor. Today there is no way to tell those apart from the score.

## Scope

A new benchmark category and supporting infrastructure, rolled out in three phases. Each phase is independently shippable.

### Phase A — same-model both roles (MVP)

- New `Category.planningAndExecution` (or split: `planning`, `executionFromPlan`).
- New `MultiStageBenchmarkTask` shape (or extension of `BenchmarkTask`) with **two stages**:
  1. `PlanStage` — model receives the task description and produces a plan artifact (markdown). No code execution.
  2. `ExecuteStage` — model receives the original task description **plus its own plan output** as context, then produces code as today.
- Each task ships with: a planning prompt, an execution prompt template, a plan-quality `judgeRubric`, and the usual code-quality evaluator config for the execute stage.
- `RunBloc` orchestrates the chain and persists the intermediate plan artifact.
- New evaluators for plan quality: `plan_judge` (LLM-judged against rubric) and optionally `plan_structure` (cheap structural checks: section headers, numbered steps, mentions of testability).
- Code from the execute stage is graded by the existing evaluator suite (`compile`, `analyze`, `test`, `widget_tree`, `diff_size`).
- Final per-task score combines plan score and execution score with separate weights, exposed via `defaultEvaluatorWeights` (Plan 7 editor will let users tune these).

### Phase B — fixed reference plans

- Each Phase A task ships with one **frozen, human-curated reference plan** alongside the prompt.
- New run mode: "Execute against reference plan." The execute stage receives the reference plan instead of a model-generated one. Plan stage is skipped.
- Cleanly isolates **executor skill** from planning skill without combinatorial blowup. Same `M × N` cost as today's runs.
- UI: a toggle in `NewRunPage` ("Use reference plan" / "Each model plans for itself").

### Phase C — cross-model pairings (opt-in)

- `NewRunPage` exposes a separate **planner model** selector and **executor model(s)** selector.
- Run produces a pairing matrix (`M_planners × M_executors × N_tasks` task-runs).
- New leaderboard view: pairing-matrix heatmap with planner on one axis, executor on the other, score in the cells.
- Gated behind an explicit "Advanced" flag in `NewRunPage`. Disabled by default to protect users from cost surprises.

## Out of scope

- Replacing or modifying any existing single-shot tasks (Plans 1–5 stay as-is).
- Multi-turn execution within a stage (the executor still gets one shot per task).
- Real agentic loops (no "model retries until tests pass"). That's a separate, much larger plan.
- Brainstorming as its own stage. The skill cascade has four stages; this plan compresses to two (plan → execute) for tractability. A future plan can split further.
- Streaming or live progress for stages (existing single-progress-bar UI is fine).
- Cost estimation / spending guardrails. Phase C will surface task-run counts in the UI but won't predict spend.

## Dependencies / when to start

- Strong dependency on Plan 7's DI refactor. The harness changes here will touch `RunBloc` construction; doing it on top of clean DI is much easier than on top of the current inline construction in `_NewRunPageState._startRun`.
- Soft dependency on Plan 6 (analytics). The pairing-matrix view in Phase C reuses Phase 6's leaderboard infrastructure (filters, dimensions, drill-down). Building it before Plan 6 means duplicating that work.
- Independent of Plan 5 (more single-shot tasks). Phase A introduces a new task family from scratch; existing tasks aren't migrated.
- Suggested ordering: Plan 7 → Plan 6 → **Plan 8 Phase A** → validate signal → **Phase B** → **Phase C**. Phases A, B, C are themselves independent commits / sub-plans; treat each as its own brainstorm + spec.

## Notes for the future spec

- **Plan format pinning is a research problem.** Decide upfront whether the plan output is freeform markdown, a structured numbered list, or JSON. Freeform is most natural for models but hardest to feed back into the executor prompt; JSON is brittle (models hallucinate keys). Recommend: freeform markdown with a fenced ``` ```plan ``` ``` block convention, parsed with a tolerant extractor.
- **Plan judge reliability is load-bearing.** In single-shot, `llm_judge` is one of seven signals; here it's the only signal for half the score. Validate the judge's variance on a small fixture set before scaling. If variance is high, consider a "double-judge" (two judges, average) or fall back to `plan_structure` heuristics.
- **Cross-model judge contamination.** When a model judges plans from competing models (Phase C especially), bias is a real risk. Use a judge from a *different family* than any contestant where possible (e.g., a small Anthropic judge for OpenAI/DeepSeek/Ollama contestants).
- **Same-model "self-plan" leakage.** In Phase A, a model is asked to follow its own plan. If the plan stage was vague, the executor stage gets to "interpret" it loosely. Score should reward plans that constrain the executor (the executor doing well on a vague plan is partially the executor's win, partially the planner's failure to commit).
- **Storage:** the plan text is medium-sized (KB, not MB). A new column on `task_runs` (`plan_artifact TEXT NULLABLE`) is simpler than a `task_run_stages` join table. Migrate when adding it.
- **Cost surface in UI:** `NewRunPage` should show a task-run count preview before the Run button enables, so users see "150 task-runs" before clicking. Especially important once Phase C lands.
- **Reference plans in Phase B** must be version-controlled in-repo and treated as benchmark canon — a change to a reference plan invalidates historical runs against it. Tag them with a `referencePlanVersion` field stored on the task-run.

## See also

- `docs/plans/2026-05-02-foundation-and-first-slice.md` — single-stage `BenchmarkTask` shape this extends.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — `llm_judge` evaluator that `plan_judge` will be modeled on.
- `docs/roadmap/2026-05-02-plan-7-polish.md` — DI refactor that Plan 8 builds on top of.
- `docs/roadmap/2026-05-02-plan-6-analytics.md` — leaderboard / dimension infrastructure that Phase C's pairing-matrix view extends.
