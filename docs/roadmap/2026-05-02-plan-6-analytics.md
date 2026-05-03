# Plan 6 (roadmap stub) — Analytics: Dashboard + Leaderboard

> **Status:** Roadmap stub. Not yet specced. Brainstorm + write the full plan doc when ready to start.

## Goal

Turn the accumulated run history into actionable comparisons across providers, models, and tasks. Two new surfaces:

1. **Dashboard** — landing page replacing/augmenting the current Home page. Shows recent runs at a glance and the current top model per category.
2. **Leaderboard** — dedicated page with `fl_chart` bar charts and radar charts, filterable by category, provider, date range, and aggregate score dimension.

Multi-dimensional score display: surface the **Intelligence / Speed / Elegance / Problems** axes (mapping from existing evaluator scores) so users can see *why* a model wins, not just that it does.

## Scope

- New `DashboardPage` (route: `/`, replacing or extending `HomePage`).
- New `LeaderboardPage` (route: `/leaderboard`).
- Aggregation queries on `AppDatabase` (top-N per category, model-vs-model comparison).
- `fl_chart` integration: bar charts (per-task, per-model) and radar charts (multi-dimensional per-model snapshot).
- Filter widgets: category multi-select, provider multi-select, date range picker, score-dimension toggle.

## Out of scope

- New tasks, evaluators, or providers.
- CSV export (lives in Plan 4 — Data & navigation).
- Real-time updates / streaming charts.

## Dependencies / when to start

- **Hard dependency on Plan 4** (data & navigation): this plan reuses Plan 4's run history and run details views as drill-down destinations from chart elements.
- **Soft dependency on Plan 5** (more tasks): charts are visually unconvincing with only 1 task. Wait until at least ~5 of the 9 new tasks are implemented before starting Plan 6, otherwise you'll be tuning charts on data that doesn't represent the steady state.

## Notes for the future spec

- `fl_chart` is already in `pubspec.yaml` (added in Plan 1). No new deps expected.
- Decide on an aggregation strategy: store rolling per-(provider, model, task) summaries in a derived table, or compute on-demand from `task_runs` + `evaluations`. On-demand is simpler and probably fast enough at this data volume; revisit only if queries get slow.
- Define the **Intelligence / Speed / Elegance / Problems** mapping explicitly:
  - Intelligence = mean(test, widget_tree) ?
  - Speed = inverse-normalized latency ?
  - Elegance = mean(analyze, llm_judge, diff_size) ?
  - Problems = count of evaluator failures ?
  - These are guesses — pin them down during brainstorming.
- Empty-state design matters: dashboard should look reasonable on a fresh install with zero runs.

## See also

- `docs/plans/2026-05-02-foundation-and-first-slice.md` — closing notes describe the multi-dimensional dashboard intent.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — defines the per-evaluator scores the dimensions aggregate from.
