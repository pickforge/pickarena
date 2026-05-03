# Plan 6 — Analytics: Dashboard + Leaderboard (Design)

> **Status:** Draft design. Awaiting user review before implementation-plan authoring (writing-plans).
> **Source roadmap stub:** `docs/roadmap/2026-05-02-plan-6-analytics.md`

## 1. Goal

Turn the accumulated run history into actionable comparisons across providers, models, and tasks. Two new surfaces:

1. **Dashboard** (`/`) — replaces the current stub `HomePage`. Three stacked sections: in-progress run banner (when applicable), showcase strip (top model per category), recent activity (last 5 runs).
2. **Leaderboard** (`/leaderboard`) — single-question page: *"which model wins?"* Ranked list (left) + detail pane (right) with selectable + pinnable rows, dimension toggle, and filters. Drill-down from chart click into the existing run / task-run detail pages.

A single pure mapping from raw evaluator scores into four interpretable dimensions — **Intelligence / Speed / Elegance / Reliability** — feeds both surfaces, the radar chart, and any future export.

## 2. Scope

**In scope:**

- New `DashboardPage` replacing `HomePage` at route `/`, plus a new `LeaderboardPage` at route `/leaderboard`.
- A pure-function dimension mapper (`Dimensions.fromTaskRuns(...)`) computing the four axes from `TaskRun` + `Evaluation` records.
- A read-only `LeaderboardRepository` doing on-demand SQL aggregation over existing `runs` / `task_runs` / `evaluations` tables. No schema change, no rollup table, no cache.
- `fl_chart` integration for one radar chart (model dimensions, with an optional pinned overlay) and one bar chart (per-task scores for the selected model). Drill-down from bar tap → existing `TaskRunDetailsPage`.
- Filter UI: single-select category, single-select provider, date-range preset chips (7d / 30d / All / Custom), dimension toggle (Intelligence / Speed / Elegance / Reliability / Overall).
- URL-state for all filters and selection (`go_router` query params), so dashboard showcase cards can deep-link into a pre-filtered Leaderboard.
- Empty-state designs for fresh-install (zero runs) on both pages.

**Out of scope (explicit deferrals to follow-up plans):**

- Trend lines / sparklines (per-model score over time).
- CSV export of the leaderboard view.
- Saved filter presets (URL-state covers the realistic use).
- Per-task radar (one mini-radar per task).
- Provider-group aggregation ("all OpenAI models as one row").
- Multi-select category / multi-select provider filters.
- New tasks, evaluators, providers.
- Real-time / streaming charts.
- Schema migrations or derived rollup tables.
- Documentation / README updates (per repo conventions).

## 3. Architecture

### 3.1 The four dimensions — single source of truth

A new pure module owns the dimension definitions. Same code feeds the radar, the showcase strip cards, and any future README export. No SQL aggregation tricks.

```dart
// lib/analytics/dimensions.dart
class Dimensions {
  const Dimensions({
    required this.intelligence,
    required this.speed,
    required this.elegance,
    required this.reliability,
    required this.overall,
    required this.problems,
  });

  final double intelligence; // 0..1
  final double speed;        // 0..1
  final double elegance;     // 0..1
  final double reliability;  // 0..1
  final double overall;      // 0..1, mean of the four
  final int problems;        // count of failed evaluator results, footer only

  static const double latencyLoMs = 2000;
  static const double latencyHiMs = 60000;
  static const double reliabilityThreshold = 0.5;

  static Dimensions fromTaskRuns(
    List<TaskRun> taskRuns,
    Map<String, List<Evaluation>> evalsByTaskRunId,
  );
}
```

**Formulas** (pinned):

| Dimension       | Formula                                                                        |
|-----------------|--------------------------------------------------------------------------------|
| `intelligence`  | weighted mean of `compile`, `analyze`, `test`, `test_author`, `widget_tree` evaluator scores across all evaluations in scope, using the existing `defaultEvaluatorWeights` |
| `speed`         | `clip(1 - (median(latencyMs) - latencyLoMs) / (latencyHiMs - latencyLoMs), 0, 1)` |
| `elegance`      | mean of `llm_judge` and `diff_size` evaluator scores (whichever are present)   |
| `reliability`   | `count(taskRun.aggregateScore >= reliabilityThreshold) / count(taskRuns)`      |
| `overall`       | arithmetic mean of the four above                                              |
| `problems`      | `sum over evaluations of (passed == false ? 1 : 0)`                            |

Notes:

- `latencyLoMs` / `latencyHiMs` constants are tuneable; comments at the constant declaration site explain the choice (typical good-model latency floor / typical agent-mode timeout ceiling).
- When an evaluator group is absent for a model (e.g. only oracle-graded tasks were run, so `test_author` never fires), the contributing dimension uses the available evaluators only — never imputes a 0.
- Empty-input contract: `Dimensions.fromTaskRuns([], {})` returns all-zero dimensions and `problems = 0`. Callers render the "no data" state, not a misleading zero radar.

### 3.2 `LeaderboardRepository` — on-demand aggregation

A new read-only repository owns leaderboard queries. No writes. No cache. Sits on top of `AppDatabase` and is constructed wherever `RunDao` is constructed (page-owned `AppDatabase` or injected for tests).

```dart
// lib/analytics/leaderboard_repository.dart
class LeaderboardRepository {
  LeaderboardRepository(this._db);
  final AppDatabase _db;

  Future<List<ModelRanking>> rank({required LeaderboardFilter filter});
  Future<ModelDetail> detail({
    required String providerId,
    required String modelId,
    required LeaderboardFilter filter,
  });
}

class LeaderboardFilter {
  final Category? category;          // null = all
  final String? providerId;          // null = all
  final DateRange dateRange;         // last7d / last30d / allTime / custom(from,to)
  final ScoreDimension dimension;    // intelligence | speed | elegance | reliability | overall
}

class ModelRanking {
  final String providerId;
  final String modelId;
  final Dimensions dimensions;       // computed from filtered task runs
  final int taskRunCount;
}

class ModelDetail {
  final ModelRanking ranking;
  final List<PerTaskScore> perTask;  // for bar chart
}

class PerTaskScore {
  final String taskId;
  final Category category;
  final double aggregateScore;
  final String? lastRunId;           // for drill-down navigation
  final String? lastTaskRunId;       // for drill-down navigation
}
```

Implementation strategy:

- One Drift query joins `task_runs` × `evaluations`, filtered by date range, category (via task id whitelist from the `TaskRegistry`), and provider id. Pulls all rows into memory, then groups by `(providerId, modelId)` in Dart and runs `Dimensions.fromTaskRuns` per group.
- For ≤500 runs this is cheap. The roadmap-stated volume cap makes a rollup table unnecessary; a comment in the repo file pins this assumption.
- `dateRange.custom` is a `(DateTime from, DateTime to)` pair inclusive on both ends.
- `category` filter is applied by intersecting on the task ids registered in the live `TaskRegistry` for that category — no `category` column is added to the schema.

### 3.3 Routing & URL-state

```
/                     → DashboardPage   (replaces HomePage)
/leaderboard          → LeaderboardPage
/leaderboard?...      → LeaderboardPage with filters + selection from query params
```

Query parameters on `/leaderboard`:

| Param      | Values                                              | Default     |
|------------|-----------------------------------------------------|-------------|
| `category` | one of `Category` enum values (e.g. `bugFix`)       | none (all)  |
| `provider` | provider id string                                  | none (all)  |
| `since`    | `7d` / `30d` / `all` / ISO `from..to`               | `all`       |
| `dim`      | `intelligence`/`speed`/`elegance`/`reliability`/`overall` | `overall` |
| `sel`      | `<providerId>:<modelId>` of selected row            | first row   |
| `pin`      | `<providerId>:<modelId>` of pinned row              | none        |

Showcase cards on the dashboard deep-link to e.g. `/leaderboard?category=bugFix&dim=overall`.

`go_router` route definitions live in `lib/app.dart` next to the existing routes.

### 3.4 Page composition

```
lib/ui/pages/dashboard_page.dart       (new, replaces home_page.dart)
lib/ui/pages/leaderboard_page.dart     (new)
lib/ui/widgets/showcase_card.dart      (new — used by dashboard)
lib/ui/widgets/in_progress_banner.dart (new — used by dashboard)
lib/ui/widgets/recent_runs_strip.dart  (new — used by dashboard)
lib/ui/widgets/dimension_radar.dart    (new — fl_chart radar wrapper, with optional overlay)
lib/ui/widgets/per_task_bar_chart.dart (new — fl_chart bar wrapper, taps drill down)
lib/ui/widgets/leaderboard_filters.dart (new — header strip widget)
lib/ui/widgets/ranked_models_list.dart (new — left-pane list)
```

`HomePage` is deleted (or renamed to `DashboardPage`); the `home_page.dart` file is removed and `app.dart` is updated to import `dashboard_page.dart`.

#### 3.4.1 Dashboard layout (`/`)

```
┌────────────────────────────────────────────────────────┐
│ AppBar: dart_arena              [history] [settings]   │
├────────────────────────────────────────────────────────┤
│ [InProgressBanner: "Run 'baseline-2' in progress…"]    │  (only when applicable)
├────────────────────────────────────────────────────────┤
│ Top model per category                                 │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐                     │
│ │UI  │ │Stat│ │Bug │ │Refa│ │Test│   ← ShowcaseCard  │
│ │opus│ │opus│ │gpt5│ │opus│ │ds-v│   each card has:   │
│ │.91 │ │.84 │ │.81 │ │.79 │ │.76 │   model name        │
│ └────┘ └────┘ └────┘ └────┘ └────┘   overall score    │
│                                       4-axis sparkradar│
├────────────────────────────────────────────────────────┤
│ Recent runs                          [View all →]      │
│ • Run "baseline-2"      2026-05-03  3 tasks  avg 0.74  │
│ • Run "claude-vs-gpt"   2026-05-02  10 tasks avg 0.81  │
│ ...                                                    │
├────────────────────────────────────────────────────────┤
│ [+ New Run]  (FAB)                                     │
└────────────────────────────────────────────────────────┘
```

- Showcase strip uses `LeaderboardRepository.rank(filter: dim=overall, category=X, since=all)` once per category and picks the top row. Tap → `/leaderboard?category=X&dim=overall&sel=<provider>:<model>`.
- Recent runs strip is the existing `_RunRowData` rendering extracted from `RunHistoryPage`'s `_RunTile` (refactored to a shared widget). Tap → `/runs/:runId`.
- Empty state (zero runs across all categories): single illustrated card with "Run your first benchmark" CTA. Showcase strip is hidden, recent activity strip is hidden.
- In-progress banner: shown if `_db.runs` has any row with `completedAt == null`. Tap → `/run` (existing `RunProgressPage`). When multiple runs are in flight (rare), the banner shows the most recent one and a count.

#### 3.4.2 Leaderboard layout (`/leaderboard`)

```
┌────────────────────────────────────────────────────────┐
│ AppBar: Leaderboard                       [back]       │
├────────────────────────────────────────────────────────┤
│ [Category ▾] [Provider ▾] [Since: 30d ▾] [Dim: Overall▾]│  ← LeaderboardFilters
├──────────────────────────┬─────────────────────────────┤
│ Ranked models (~55%)     │ Detail (~45%)               │
│ ┌──────────────────────┐ │ ┌─────────────────────────┐ │
│ │# │ model     │score│📌│ │ │ DimensionRadar          │ │
│ │1 │ opus-4.7  │0.87 │● │ │ │ (selected solid +       │ │
│ │2 │ gpt-5     │0.83 │○ │ │ │  pinned overlay)        │ │
│ │3 │ ds-v4     │0.79 │○ │ │ ├─────────────────────────┤ │
│ │ ...                 │ │ │ │ PerTaskBarChart         │ │
│ │                     │ │ │ │ (selected model only)   │ │
│ └──────────────────────┘ │ └─────────────────────────┘ │
└──────────────────────────┴─────────────────────────────┘
                              footer: "12 task-runs ·
                              3 problems"
```

- Selecting a row in the ranked list updates `?sel=...`; the detail pane re-queries `LeaderboardRepository.detail(...)`.
- Tapping the pin icon toggles `?pin=...`. At most one pin in v1. Pinned model appears as a translucent overlay polygon on the radar; the bar chart still shows only the selected model (one bar chart per model — no overlay there).
- "Score" column value comes from the current `dim` toggle. Switching `dim` re-sorts the list and updates the column header.
- Tapping a bar in `PerTaskBarChart` navigates to `/runs/<lastRunId>/task-runs/<lastTaskRunId>` for that task — both ids come from `PerTaskScore` (the most recent task-run for the (model, task) pair within the filter window, plus its parent run id).
- Filters: `Category` is a single-select dropdown including an "All" option; `Provider` is the same; `Since` is a chip row (`7d`, `30d`, `All time`, `Custom…`). `Custom…` opens a date-range picker dialog. `Dim` is a dropdown with five options.
- Empty state ("zero rows match the filter"): the right pane shows "No data for this filter — try widening the date range." The ranked list shows nothing.
- Empty state ("zero runs in the database at all"): full-page card "No benchmark data yet — start a run from the dashboard."

### 3.5 Charts (fl_chart wiring)

#### `DimensionRadar` widget

```dart
DimensionRadar({
  required Dimensions selected,
  Dimensions? pinned,
  String? selectedLabel,
  String? pinnedLabel,
});
```

Four-spoke radar (Intelligence, Speed, Elegance, Reliability) using `fl_chart`'s `RadarChart`. Selected polygon is solid theme primary; pinned is translucent secondary. Numeric labels on each spoke at fixed positions (0, 0.5, 1.0). No interactivity beyond rendering.

#### `PerTaskBarChart` widget

```dart
PerTaskBarChart({
  required List<PerTaskScore> scores,
  required void Function(PerTaskScore) onTap,
});
```

Horizontal bar chart, one bar per task, sorted by `aggregateScore` descending. Tap delegates to `onTap` which the page wires to `context.push('/runs/<runId>/task-runs/<taskRunId>')`. Color-codes bars by category (uses the same color palette the showcase cards use).

### 3.6 Wiring — where the pieces meet

- `app.dart` adds two routes (`/leaderboard` and a refactored `/`) and wires the `DashboardPage`/`LeaderboardPage` constructors. Both pages own their `AppDatabase` the same way `RunHistoryPage` and `RunDetailsPage` do, with optional injection for tests (`dao`, `repo` parameters).
- `DashboardPage` and `LeaderboardPage` share construction of `LeaderboardRepository(_db)` next to their existing `RunDao(_db)`.
- `RunHistoryPage._RunTile` is extracted into a shared `widgets/run_row.dart` so the dashboard's recent-runs strip and the history page render rows identically.

## 4. Components — file map

### 4.1 Created

- `lib/analytics/dimensions.dart` — `Dimensions`, `ScoreDimension`, formulas.
- `lib/analytics/leaderboard_filter.dart` — `LeaderboardFilter`, `DateRange`.
- `lib/analytics/leaderboard_repository.dart` — `LeaderboardRepository`, `ModelRanking`, `ModelDetail`, `PerTaskScore`.
- `lib/ui/pages/dashboard_page.dart` — replaces `home_page.dart`.
- `lib/ui/pages/leaderboard_page.dart` — new.
- `lib/ui/widgets/showcase_card.dart`
- `lib/ui/widgets/in_progress_banner.dart`
- `lib/ui/widgets/recent_runs_strip.dart`
- `lib/ui/widgets/dimension_radar.dart`
- `lib/ui/widgets/per_task_bar_chart.dart`
- `lib/ui/widgets/leaderboard_filters.dart`
- `lib/ui/widgets/ranked_models_list.dart`
- `lib/ui/widgets/run_row.dart` — extracted from `RunHistoryPage._RunTile`.
- `test/analytics/dimensions_test.dart`
- `test/analytics/leaderboard_repository_test.dart`
- `test/ui/pages/dashboard_page_test.dart`
- `test/ui/pages/leaderboard_page_test.dart`

### 4.2 Modified

- `lib/app.dart` — replace `HomePage` import/route, add `/leaderboard` route.
- `lib/ui/pages/run_history_page.dart` — replace inline `_RunTile` with shared `RunRow` widget.
- `lib/ui/pages/home_page.dart` — **deleted**.

### 4.3 Untouched

- `lib/storage/database.dart` (no schema change).
- `lib/storage/dao/run_dao.dart` (analytics reads through new repository, not DAO).
- All evaluator, provider, task, and runner code.

## 5. Testing

- **`Dimensions.fromTaskRuns`** — pure function, easy to unit-test exhaustively: empty input, all-evaluators-present, missing `llm_judge`, missing `test_author`, latency at LO/HI/clamped, mixed pass/fail. ≥10 unit tests.
- **`LeaderboardRepository.rank`** — Drift in-memory database fixture seeded with hand-built `Run` / `TaskRun` / `Evaluation` rows; assert grouping, filter application, and ordering by selected dimension. ≥6 tests.
- **`LeaderboardRepository.detail`** — same fixture; assert per-task scores include the correct `lastTaskRunId` when there are multiple task runs for the same `(model, task)`.
- **Pages** — widget tests using injected `RunDao` + `LeaderboardRepository` and an in-memory database. Cover empty state, populated state, in-progress banner visibility, deep-link query-param parsing, drill-down navigation via mocked `GoRouter`.
- **Verification gate** — `flutter analyze` clean, `flutter test` green, manual smoke run on Linux desktop with a populated database.

## 6. Risks & open questions

- **Latency normalization constants** (`2000ms`, `60000ms`) are guesses informed by current providers. If they turn out wrong (e.g., agent-mode runs routinely exceed `60000ms`), `Speed` will pin to 0 for many models. Acceptance criterion: on a representative dataset, `Speed` should produce a meaningful spread (not >50% of models pinned to either end). If it doesn't, retune the constants — code-only change, no schema impact.
- **Reliability threshold** (`0.5`) is also a guess. Same acceptance criterion applies.
- **Single-pin overlay** may feel limiting once the page is in use ("I want to compare three models on the radar"). Defer the multi-pin upgrade to Plan 6.5; the API of `DimensionRadar` already takes one `pinned` and can grow to a `List<Dimensions> pinned` cleanly.
- **`PerTaskScore.last{Run,TaskRun}Id`** semantics: drill-down navigates to *the most recent* task-run for that (model, task) within the filter window. If the user wants "the run where this score happened (averaged)", that's a different feature (history of task-runs per task), deferred.
- **Dashboard showcase `category` mapping** depends on `Category` enum values being stable over time. If a category is removed or renamed, the dashboard breaks gracefully (missing card slot) rather than crashing — handled by enum iteration, not hard-coded keys.

## 7. Sequencing hint for the implementation plan

Suggested order (to be detailed by writing-plans):

1. `Dimensions` + tests.
2. `LeaderboardFilter` + `LeaderboardRepository` + tests.
3. Extract `RunRow` widget (touches `RunHistoryPage`); regression-test the history page still renders.
4. `DimensionRadar` + `PerTaskBarChart` widgets (no page wiring yet).
5. `LeaderboardPage` + `LeaderboardFilters` + `RankedModelsList` + route + URL-state + tests.
6. `ShowcaseCard` + `InProgressBanner` + `RecentRunsStrip`.
7. `DashboardPage` + delete `HomePage` + route swap + tests.
8. Final verification gate.

## 8. See also

- `docs/roadmap/2026-05-02-plan-6-analytics.md` — source roadmap stub.
- `docs/specs/2026-05-02-plan-4-data-and-navigation-design.md` — `RunSummary`, `RunMatrix`, `RunHistoryPage` (drill-down destinations).
- `docs/specs/2026-05-02-evaluators-and-scoring-design.md` — the evaluator score axes the dimensions aggregate from.
- `lib/core/scoring.dart` — existing per-evaluator weight table reused inside `intelligence`.
