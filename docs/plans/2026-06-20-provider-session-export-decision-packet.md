# Provider/session export decision packet

Status: awaiting provider/tooling decision
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

Opening guard:

- Decision-only.
- Does not expose, copy, certify, or generate provider/session content.
- `deepSWEComplete: false` remains.

Validation note: independent read-only review accepted this packet as actionable, metadata-only, strong enough on disallowed provider-content/leakage rules, and free of DeepSWE/provider proof overclaim.

## 1. Why this exists

- Source investigation: [`docs/plans/2026-06-19-provider-session-export-availability-investigation.md`](./2026-06-19-provider-session-export-availability-investigation.md).
- Current durable artifacts contain generic Pi/session/subagent evidence but no confirmed provider-internal stream/session export.
- This blocker needs an owner/tooling decision, not more task-artifact work.

## 2. Decision needed

The provider/tooling owner chooses one:

- Expose or implement a provider-owned durable export.
- Certify an existing artifact class as provider-internal export, including schema, ownership, and task/run/model mapping.
- Mark provider/session export unavailable or deferred, leaving the blocker open.
- Reject or replace the requirement, requiring goal/spec-owner approval.

## 3. Minimum acceptable evidence contract

Only path/count/hash/schema-style metadata is acceptable:

- owner/source
- artifact class
- schema version
- task/run/model mapping
- chunk/event/session counts
- SHA-256/hash refs
- redaction notes

## 4. Disallowed

- Raw prompts, completions, transcripts, JSONL lines, tool calls, provider messages, secrets, absolute paths, solver diffs, hidden or restricted content, raw stdout/stderr, or provider message payloads.
- Inferring provider-internal status from generic session files. Do not infer provider-internal export status from generic Pi/session/subagent evidence.
- Staging, committing, rerunning, or accessing providers in this step.

## 5. After approved decision

- If export or certification is approved, update provenance audit artifacts separately.
- If unavailable or deferred, update blocker status separately without closing DeepSWE.

## Packet guards

- No secrets, absolute temp paths, hidden filenames, prompt transcripts, raw stdout/stderr, provider message payloads, or restricted content.
- No true-valued completion or workspace-isolation flags, goal-completion, or official proof completion claim.
- No auth or Droid changes.
