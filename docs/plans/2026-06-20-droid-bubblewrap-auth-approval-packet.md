# Droid/Bubblewrap auth approval packet

Status: awaiting maintainer approval
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is approval-only. No Droid auth is implemented, exposed, or configured by this packet. Full DeepSWE remains blocked, and first-wave slices remain `deepSWEComplete: false`.

Validation note: independent read-only security review accepted this packet as actionable, safely scoped, strong enough on disallowed auth/leakage options, and free of DeepSWE/runtime/provider completion overclaim.

## Why this exists

- `droid --version` under Bubblewrap passed.
- `droid-bwrap-smoke-20260620c` reached the real headless harness path and persisted sanitized `runtimeBoundary: {enforced: true, backend: bubblewrap}` metadata.
- Provider/session execution failed because Droid auth/config was unavailable inside the sandbox.
- Solver/agent harness boundary details stay in the existing [plan](./2026-06-20-solver-agent-harness-boundary-proof-plan.md) and [implementation report](./2026-06-20-solver-agent-harness-boundary-implementation-report.md); this packet only asks how auth may be supplied.

## Decision needed

The maintainer chooses one approved auth strategy before any implementation or real provider/session rerun.

## Options

- Recommended: maintainer-provided benchmark-scoped auth bundle copied into a sandbox-private location. Use only approved files/keys, sandbox-private writable state, and documented cleanup expectations; do not expose host home/config/cache.
- Alternative: narrow read-only bind of explicitly approved Droid auth/config inputs, plus sandbox-private writable state.
- Alternative: explicit credential environment allowlist, only if Droid officially supports it and redaction tests cover it.
- Alternative: supported Droid config/profile override, if available, pointing only at benchmark-scoped auth material.
- Defer: no auth exposure; blocker stays open.

## Disallowed options

- Broad host home/config/cache/runtime exposure.
- Parent environment inheritance.
- Broad secret-pattern allowlists.
- Storing auth in repo docs, task bundles, artifacts, or exports.
- Publishing raw stdout/stderr, prompts, transcripts, provider messages, commands, environment, auth paths, or sandbox args.
- Using hidden/restricted task artifacts for first provider proof.
- Treating auth-blocked smoke as completion evidence.

## Explicit approvals required

- Selected strategy by name.
- Approved material source/scope, with no secrets or concrete sensitive paths in docs.
- Network/provider use approval.
- Approval for code changes touching sandbox binds, environment, config, or state.
- Separate approval for staging, commit, or clean replay.

## Required validations after approved implementation

- Unit/redaction tests.
- Public-only real Droid/Bubblewrap smoke reaches successful provider/session execution.
- Metadata remains sanitized.
- Leak scan passes.
- Clean committed replay stays separate.

## Status preservation

No blocker is closed by this packet. `deepSWEComplete: false`.
