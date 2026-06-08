# Cost Estimation and Efficiency Spec

Status: archived; superseded by `docs/specs/2026-05-31-pickarena-by-pickforge-studio-master.md`
Created: 2026-05-31

## Goal

Expose reliable cost comparisons between benchmarked models at run, model, and task level, without mixing candidate model cost with evaluator/judge overhead.

## Context

The app already stores model usage per task run:

- `promptTokens`
- `completionTokens`
- `providerId`
- `modelId`

The app also already has a basic estimator in `app/lib/analytics/cost_estimator.dart` and ranking summaries in `app/lib/analytics/benchmark_statistics.dart`.

This spec extends that foundation into a benchmark-grade cost reporting system.

## Principles

1. **Use provider-reported token usage when available**.
2. **Do not invent precision**: if token usage or pricing is missing, show `unknown`, not `$0.00`.
3. **Separate candidate cost from benchmark overhead**:
   - candidate cost: model being benchmarked;
   - judge cost: LLM judge calls;
   - infrastructure cost: local execution, CI, evaluator subprocesses, not estimated in-app initially.
4. **Rank cost by solved work**: cheapest failed runs are not useful; prefer cost per primary pass.
5. **Version pricing**: model prices change, so exports must record the pricing source/version used.

## Metrics

### Per task run

For each `TaskRun`, compute:

- input tokens;
- output tokens;
- total tokens;
- estimated candidate cost in micros/USD;
- pricing lookup status:
  - `exact`;
  - `normalized_model_match`;
  - `model_only_match`;
  - `missing_usage`;
  - `missing_pricing`.

### Per task/model

For a model on a task:

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

### Per model leaderboard

For a model across filtered tasks:

- total estimated candidate cost;
- median estimated task-run cost;
- cost per primary pass;
- cost per hidden pass when hidden results are available;
- estimated judge overhead separately;
- unknown-cost count and percentage.

### Per run

For a whole run:

- total candidate cost;
- total judge/evaluator LLM cost;
- total known cost;
- unknown-cost count by provider/model;
- pricing version;
- generated-at timestamp.

## Pricing registry

Replace the hardcoded-only registry with a versioned registry object.

Minimum shape:

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

Rules:

- Keep prices in source control for reproducibility.
- Allow user override in settings/headless config for custom providers.
- Include the effective registry version in exports and provenance bundles.
- Prefer exact `provider:model` matches.
- Normalized/fallback matches must be visible in details.

## Candidate vs judge cost

Candidate model calls already produce `TaskRun.promptTokens` and `TaskRun.completionTokens`.

LLM judge calls should be tracked separately:

- evaluator ID: `llm_judge`;
- judge provider/model;
- judge prompt tokens;
- judge completion tokens;
- estimated judge cost;
- associated `taskRunId`.

Do not add judge cost to the candidate model's task-run cost. Show it as benchmark overhead.

## UI changes

### Task run details

Show a cost card:

- candidate input/output tokens;
- candidate estimated cost;
- pricing match status;
- judge overhead cost if present;
- reason when unknown.

### Run details

Show:

- total candidate cost;
- total judge overhead;
- unknown-cost rows;
- most expensive task runs.

### Leaderboard

Show:

- cost per primary pass as the main efficiency number;
- median cost as a secondary number;
- unknown-cost badge when pricing/usage is incomplete.

### Per-task drilldown

Add a table sorted by cost per pass:

```txt
task_id | model | pass_rate | median_cost | cost_per_pass | unknown_costs
```

## Export changes

CSV/Markdown/bundle exports should include:

- prompt tokens;
- completion tokens;
- estimated candidate cost micros;
- pricing match status;
- judge overhead cost micros;
- pricing registry version;
- cost per primary pass at model summary level.

Headless JSON output should include the same fields so website generation can use static data only.

## Data model options

### Option A: Derived-only, no migration

Compute costs from existing token columns and current pricing registry whenever analytics are loaded.

Pros:

- small implementation;
- no database migration;
- easy to iterate.

Cons:

- historical estimates can change if pricing registry changes unless the export stores pricing version;
- judge cost needs extra storage later.

### Option B: Persist computed cost fields

Add columns/tables for candidate cost and judge overhead.

Pros:

- stable historical cost at run time;
- easier export/report reproducibility.

Cons:

- database migration;
- must handle pricing corrections.

### Recommended path

Start with **Option A plus export provenance**, then add a small judge-usage table only when LLM judge cost tracking is implemented.

## Implementation phases

### Phase 1: Candidate cost visibility

- Expand `CostEstimator` to return a structured result, not only `int?`.
- Add pricing match status and unknown reasons.
- Add per-task/model cost aggregation.
- Surface cost per primary pass in leaderboard detail/export.
- Add tests for exact, normalized, fallback, missing usage, and missing pricing.

### Phase 2: Pricing registry provenance

- Move pricing data into a versioned registry type.
- Include registry version in artifact bundles and leaderboard exports.
- Allow headless JSON config to override/add pricing entries.

### Phase 3: Judge overhead tracking

- Capture token usage from `LlmJudgeEvaluator` provider responses.
- Store judge usage separately from candidate `TaskRun`.
- Show candidate cost and judge overhead separately in UI/export.

### Phase 4: Public website efficiency views

- Add static export fields needed by the Pickforge/Dart Arena web leaderboard.
- Add model efficiency cards:
  - pass rate;
  - cost per pass;
  - median cost;
  - total benchmark cost;
  - unknown-cost warning.

## Success criteria

- Users can compare models by cost per solved task.
- Unknown pricing/usage is explicit and never silently treated as free.
- Candidate model cost and judge overhead are separated.
- Exports contain enough pricing metadata to reproduce estimates later.
- Existing leaderboard reliability metrics remain primary; cost is an efficiency dimension, not correctness.

## Open questions

- Which pricing source should be canonical for official releases?
- Should user-entered provider pricing be stored in settings or only in run config?
- Should tokenizer-estimated usage be allowed for providers that omit usage, and if yes, how prominently should it be labeled?
- Should official benchmark results exclude runs with unknown candidate cost from cost-per-pass rankings?
