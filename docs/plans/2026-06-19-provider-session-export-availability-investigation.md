# Provider/session export availability investigation

Status: active availability note
Created: 2026-06-19
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. Every first-wave slice remains `deepSWEComplete: false`.

## Scope

This note documents read-only availability evidence for provider/session exports related to the first-wave DeepSWE goal. It does not change any task status or acceptance state.

## Read-only sources checked

- Pi root exists.
- Subagent artifact root exists.
- Active run IDs checked: `54e66617`, `2c8d8e17`, `9e72b221`, `418a9192`, `90f0896e`, `f2ed0622`, `9e788d86`, `13254af7`, `cf75c215`.
- Active DeepSWE JSON repo artifacts were checked with archive material excluded.

## Durable artifacts found

| Run ID | Input | Output | Meta | Generic session JSONL files | Lines |
| --- | ---: | ---: | ---: | ---: | ---: |
| `54e66617` | 2 | 2 | 2 | 2 | 51 |
| `2c8d8e17` | 2 | 2 | 2 | 2 | 47 |
| `9e72b221` | 1 | 1 | 1 | 1 | 22 |
| `418a9192` | 4 | 4 | 4 | 4 | 99 |
| `90f0896e` | 1 | 1 | 1 | 1 | 21 |
| `f2ed0622` | 3 | 3 | 3 | 3 | 110 |
| `9e788d86` | 1 | 1 | 1 | 1 | 25 |
| `13254af7` | 4 | 4 | 4 | 4 | 89 |
| `cf75c215` | 5 | 5 | 5 | 5 | 163 |

Additional read-only checks:

- candidate filename scan for provider/stream/chunk/delta/raw/trace/export artifacts under the Pi root: count 0.
- JSON/JSONL provider-ish key search by class: subagent meta JSON 42, generic session JSONL 153, top-level JSONL 39, other 0, total 234.
- These hits are generic Pi/session/subagent artifacts, not confirmed provider-internal durable stream exports.

## Evidence classification

Acceptable evidence would be a provider/tooling-owned durable export mapped to run ID and model with structured provider event, chunk, or session provenance, summarized by path/count/hash/schema only.

Insufficient evidence includes subagent input/output/meta, generic Pi session JSONL unless tooling certifies it as provider-internal export, README/model audit/replay claims, token/cost/duration metadata, line counts, or digest-only transcript records.

## Conclusion

Active DeepSWE JSON repo artifacts, archive excluded, contain no `providerInternalStreamChunksCaptured: true` found. Several current artifacts record false/null/unavailable state; async predates that field in active JSON.

The provider-internal stream/session export remains blocked. Current durable artifacts are useful provenance support but insufficient for the DeepSWE provider-internal stream/session requirement.

## Redaction

This note does not copy transcript/session JSONL lines, prompts, completions, tool calls, message contents, hidden details, solver diffs, source snippets, or temp/workspace paths. Counts, run IDs, and artifact classes are recorded only.
