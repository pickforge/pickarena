# V2 owner decision packet

Status: awaiting owner decisions.

## Context

V2 clean replay is complete at commit `e3b94f9` with subject `test: add V2 benchmark hardening evidence`.

This packet does not claim full completion. It only lists the owner inputs needed before the next runtime/provider step.

## Owner handoff

To continue V2 without new provider/auth exposure, approve the recommended low-risk response below. To continue with provider-session proof, answer all three decision fields and include the scoped auth boundary. If neither is approved, stop at the clean local sandbox replay evidence already recorded.

## Current stop condition

Do not run additional provider/session, auth, or runtime-boundary work until an owner answers this packet. The only approval-free action left is read-only validation of the existing V2 docs.

## Decisions needed

### 1. Authorship provenance

Choose one:

- provide the durable source of authorship truth for V2
- define the allowed metadata-only fields for authorship records
- mark authorship as unavailable for V2

Do not infer authorship from model name, provider, run id, file owner, git author, operator, or agent name.

### 2. Provider/session evidence

Choose one:

- require provider/session metadata for V2 and define the metadata-only artifact shape
- certify an existing metadata artifact as sufficient
- mark provider/session evidence unavailable or deferred for V2
- replace the requirement with an owner-approved V2 criterion

Do not copy raw provider/session content, prompts, transcripts, hidden files, or secrets.

### 3. Droid/Bubblewrap rerun boundary

Choose one:

- approve a scoped auth strategy for a provider-session rerun under Bubblewrap
- reject the rerun and stop V2 at local sandbox replay
- defer provider-session proof to a later milestone

Any approved rerun must keep auth scoped to the benchmark run and must not expose broad host environment or unrestricted secrets.

## Owner response template

```text
V2 authorship provenance: provide source / metadata-only fields / unavailable
V2 provider-session evidence: required / existing metadata sufficient / unavailable / deferred / replaced
V2 Droid-Bubblewrap rerun: approve scoped auth / reject and stop at local sandbox replay / defer
Notes:
```

## Recommended low-risk V2 response

This is a recommendation for owner approval, not an applied decision:

```text
V2 authorship provenance: unavailable unless a durable source is provided
V2 provider-session evidence: deferred for V2; metadata-only shape to be defined before any later provider run
V2 Droid-Bubblewrap rerun: reject for V2 and stop at local sandbox replay until scoped auth is approved
Notes: do not persist generated replay outputs without explicit maintainer approval
```

## Current accepted V2 evidence

- clean committed replay at `e3b94f9`
- required-sandbox replay passed for five tasks
- focused runtime, agent, and headless tests passed
- analyze and official file-backed regression passed

## Validation status

- Local guard checks passed: diff check, V2-only wording, no completion/runtime-proof overclaim, and no secret-pattern hit.
- Fresh-context read-only review accepted this packet as actionable, V2-scoped, aligned with the clean replay report, and clear that the recommended low-risk response is not an applied decision.
- No corrections were required before committing these docs and asking the owner to answer.

## Non-goals

- no full completion claim
- no hidden or restricted content disclosure
- no raw provider/session export
- no generated replay output committed without explicit maintainer approval
