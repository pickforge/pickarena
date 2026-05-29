# Flutter Task Authoring Guide

## Required metadata

- Stable `id`, `version`, `category`, `track`, `difficulty`, `tags`, `timeout`, and platform requirements.
- Visible fixtures only in task workspaces.
- Hidden verifier fixtures and reference solutions outside agent workspaces and prompts.

## Prompt rules

- Describe user-visible behavior and constraints.
- Do not mention hidden verifier names, hidden paths, reference files, or author notes.
- Keep tasks bounded, deterministic, and free of network or external service requirements.

## Verifier rules

- Baseline must fail hidden verification for the intended reason.
- Reference solution must pass public tests, hidden tests, analyzer checks, and task QA.
- Hidden checks should assert observable behavior and accept plausible alternative implementations.

## Reference solution rules

- MVP tasks must use executable `ReferenceFileSolution` mappings.
- Multi-file tasks may replace multiple full files.
- Do not admit patch-only references until patch application is implemented and covered by QA.

## Difficulty labels

- `easy`: focused one-file task with straightforward behavior.
- `medium`: realistic task with edge cases, async behavior, or UI/platform concerns.
- `hard`: multi-file or agentic task requiring project exploration and coordinated changes.

## Review checklist

- Prompt and verifier cover the same behavior.
- Public tests smoke the task without revealing hidden checks.
- Hidden/reference/authoring assets are excluded from workspaces.
- Fixtures fit the task budget and run locally without flaky timing.
- Task has difficulty, track, tags, timeout, and platform metadata.
