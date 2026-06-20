# Authored-by provenance request

Status: awaiting provenance source
Created: 2026-06-20
Goal: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. Every first-wave slice remains `deepSWEComplete: false`.

Validation note: independent read-only review accepted this request as actionable without inference, scoped and redacted enough, strong enough on private/restricted-data non-goals, and free of DeepSWE/provenance completion overclaim.

## Scope

This request covers first-wave Flutter DeepSWE provenance only.

Authored-by provenance must come from a durable provenance source; do not define authorship by inference.

## Current evidence

From the provenance audit:

- `freshSolverRecords: 20`
- `legacySolverRecords: 2`
- `solverMetadataRecords: 23`
- `authoredByKnownCount: 0`
- `cleanCommittedProvenanceCount: 0`
- `providerInternalStreamChunksCapturedCount: 0`

Model family, provider, run ID, file ownership, git author, subagent name, or operator identity are not sufficient to infer authored-by provenance.

## Required durable source

The durable source must be user-provided, maintainer-provided, or provenance-source-provided. It must define what `authored-by` means for this benchmark: task authoring, verifier authoring, reference implementation authoring, solver-candidate generation, review attestation, or another explicit scope.

No authored-by provenance record should be created from guesses; unknown is better than inferred.

## Proposed record shape

Proposal only, not provenance data:

- `scope`
- `attestedBy`
- `attestedAt`
- `sourceOfTruth`
- `tasks[]`
  - `taskId`
  - `authorshipRoles[]`
    - `role`
    - `author`
    - `evidenceRefs[]`
  - `unknowns[]`
- `redactionNotes`

Do not populate real names or authors unless they are explicitly provided for provenance.

## Non-goals and redaction

Do not include hidden verifier contents, private prompts or transcripts, solver diffs or source snippets, private names unless explicitly provided for provenance, or restricted paths.

This request does not close the authored-by blocker and does not change any slice beyond `deepSWEComplete: false`.

## Owner action

A user, maintainer, or provenance owner must provide or approve a durable provenance source before the blocker can close.

After a durable source exists, rerun or review the provenance audit and keep `deepSWEComplete: false` until all blockers are closed.
