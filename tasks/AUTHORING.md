# Task authoring reference

Use this when creating or reviewing PickArena task bundles. The active benchmark source of truth is [`docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md`](../docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md).

## What good tasks look like

A good PickArena mobile task is:

- Realistic: the prompt sounds like a mobile developer issue or feature request.
- Bounded: the expected fix fits the declared timeout and workspace.
- Verifiable: hidden checks can prove behavior without relying on implementation trivia.
- Isolated: no network or external service is required unless the task explicitly admits it.
- Resistant to fake fixes: noop, API-breaking, and overfit solutions fail.
- Replayable: the baseline, reference solution, hidden tests, and QA report are enough to audit the task later.

## Candidate promotion ladder

Use this funnel so task authoring stays cheap until a candidate proves it is worth deeper QA:

```txt
idea -> task card -> draft bundle -> QA candidate -> admitted -> active -> retired
```

- `idea`: a rough mobile developer issue, feature, refactor, or security finding.
- `task card`: a short proposal with verifier and fake-fix notes.
- `draft bundle`: files exist, but QA evidence is not final.
- `QA candidate`: baseline, reference, hidden tests, and negative cases are ready for admission runs.
- `admitted`: QA evidence is current and reviewed.
- `active`: selected by an official preset or release manifest.
- `retired`: archived after replacement, disclosure, or benchmark rotation.

## Task card template

Use this before creating a full bundle:

```md
id:
framework:
category:
difficulty target:
developer prompt idea:
baseline bug / missing behavior:
expected fix surface:
public smoke behavior:
hidden behaviors:
negative cases:
fake-fix risks:
flake risks:
why this task matters:
```

## How many authoring agents

Use the first N agents in this fixed order:

1. GPT 5.5 Xhigh
2. Opus 4.8 Xhigh
3. GLM 5.2 (Ollama) Xhigh
4. Kimi K2.7 Code (Ollama) Xhigh
5. MiniMax M3 (Ollama) Xhigh

Recommended counts:

- 2 agents: routine V1 Flutter expansion.
- 3 agents: risky or novel V1 tasks.
- 5 agents: V2, DeepSWE-grade, security, or cross-framework tasks.

Rules:

- Generate cheap task cards first.
- Reserve 3-5 agents for promoted drafts, not every raw idea.
- Fresh solver agents must not be the same agents that authored the task.
- A human writes the final `instruction.md`.

## Directory layout

```txt
tasks/<framework>/<task-id>/
  task.yaml
  instruction.md
  baseline/
  hidden_tests/
  solution/
  negative_cases/
    noop/
    api_breaking/
    overfit/
  qa/
    admission_report.json
```

Current official Flutter tasks use `tasks/flutter/<task-id>/`.

## `task.yaml`

Required metadata:

- `schemaVersion`
- stable `id` and integer `version`
- `category`, `track`, `difficulty`, and `tags`
- `platformRequirements`
- `timeoutSeconds`
- `release.corpus` and `release.status`
- `network`
- `resources`
- framework flags such as `isFlutter` where applicable
- `instructionPath`
- `workspace` file map
- `hiddenVerifiers`
- `reference`
- `requiredNegativeCaseKinds`
- `negativeCases`

Keep ids stable. Bump `version` when prompt, baseline behavior, hidden verifier behavior, or reference behavior changes meaningfully.

## `instruction.md`

The instruction is the only task-specific brief the agent should need.

Do:

- Write in a human developer voice.
- Describe user-visible behavior and constraints.
- Name public APIs that must be preserved.
- Include enough examples to remove ambiguity.
- Keep the task deterministic and offline.

Do not:

- Mention hidden test names, hidden paths, solution files, QA notes, or verifier implementation.
- Tell the agent to hardcode public examples.
- Require private credentials, live services, or non-deterministic timing.
- Hide critical acceptance behavior that is not implied by the prompt.

Prompt checklist:

- [ ] Each critical requirement has verifier coverage.
- [ ] Each hidden assertion maps back to the prompt.
- [ ] The prompt does not leak hidden or solution assets.
- [ ] The prompt is short enough for an agent to act on without test archaeology.

## `baseline/`

The baseline is copied into the agent workspace.

Rules:

- It contains only files the agent is allowed to inspect or edit.
- It should include public tests when those are part of the task experience.
- It must not include hidden tests, reference solutions, or author-only notes.
- It must fail the intended hidden behavior before the fix.
- Public tests should be useful smoke coverage without revealing hidden edge cases.

## `hidden_tests/`

Hidden tests grade the submitted patch.

Rules:

- Assert behavior and API contracts, not preferred implementation details.
- Cover edge cases beyond public examples.
- Preserve plausible alternative implementations.
- Do not reuse literal strings, fixtures, or expected values copied from `instruction.md` or public tests.
- Treat pass-to-pass (p2p) preservation as first-class V1+ evidence.
- Reject removed tests, broken public APIs, hardcoded public values, and cosmetic fixes.
- Avoid flaky sleeps, real network, wall-clock races, and host-specific assumptions.

For Flutter, prefer focused Dart/widget tests first. Add integration, golden, accessibility, or platform-channel checks only when they are stable and necessary.

## `solution/`

The reference solution proves the task is solvable.

Rules:

- It passes public tests, hidden tests, analyzer/build checks, and task QA.
- It is minimal enough to show the intended behavior, not a broad refactor.
- It preserves public APIs unless the prompt explicitly asks otherwise.
- Current official bundles use file replacement references.

## `negative_cases/`

Negative cases are known-bad implementations that QA must reject.

Required kinds:

| Kind | Purpose |
| --- | --- |
| `noop` | Proves the baseline or unchanged behavior cannot pass. |
| `api_breaking` | Proves public API or contract breakage is caught. |
| `overfit` | Proves hardcoded public examples or narrow fixes are caught. |

For V1+/V2 tasks, add this extra case when public tests are part of the baseline:

| Kind | Purpose |
| --- | --- |
| `deleted_or_weakened_public_test` | Proves deleted, skipped, or loosened public tests cannot pass admission. |

Add extra negative cases when the task has likely fake-fix paths, such as deleted assertions, ignored async ordering, invented dependencies, or platform stubs that always return success.

## QA and admission

Run task QA from `app/` and write reports to a scratch output first:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_task_qa \
  --task-bundle-root ../tasks/flutter \
  --task <task-id> \
  --out build/task_qa
```

Review the generated report before copying it to `tasks/<framework>/<task-id>/qa/admission_report.json`.

Admission gates:

- [ ] Structure resolves from `task.yaml`.
- [ ] Prompt is safe and has prompt-verifier bijection.
- [ ] Baseline fails hidden target behavior.
- [ ] Reference passes public and hidden verifiers.
- [ ] V1+ pass-to-pass (p2p) checks preserve existing behavior.
- [ ] Hidden fixtures do not copy literal public prompt or test values.
- [ ] Required negative cases fail.
- [ ] V1+/V2 `deleted_or_weakened_public_test` negative case fails when applicable.
- [ ] Hidden flake runs pass.
- [ ] Environment provenance is present.
- [ ] Release metadata matches the intended preset/corpus.

## Framework verifier notes

| Framework | Useful verifier tools |
| --- | --- |
| Flutter | `flutter test`, analyzer, widget tests, integration tests, golden tests, accessibility semantics, platform-channel mocks. |
| React Native Android | Jest, React Native Testing Library, Metro/DevTools endpoints, Android emulator checks. |
| Native Android | Gradle unit/instrumentation tests, ADB, logcat, screenshots, UIAutomator hierarchy. |
| Native iOS | XCTest, `xcodebuild`, `simctl`, simulator logs, accessibility tree checks. |
| Security | OWASP MASVS-inspired behavior checks plus reliable static/config checks where useful. |

Use the same admission standards across frameworks even when the verifier tools differ.

## Research anchors for task authors

Use these as context when designing new tasks; do not paste them into prompts.

| Source | Use it for |
| --- | --- |
| DeepSWE | Task rigor: human prompts, patch replay, hidden separation, f2p/p2p, flake checks, verifier audit evidence. |
| BridgeBench | Category inspiration: UI, debugging, refactoring, reasoning, security, speed, and fake-fix resistance. |
| Flutter testing/accessibility docs | Widget, integration, golden, semantics, localization, and accessibility verifier patterns. |
| React Native testing/DevTools/Metro docs | Jest/RNTL coverage, Metro logs/endpoints, React Native Android debugging and verifier ideas. |
| Android UIAutomator/ADB/logcat docs | Native Android hierarchy, screenshot, log, emulator, and instrumentation checks. |
| iOS XCTest/xcodebuild/simctl/accessibility docs | Native iOS simulator, UI test, screenshot, log, and accessibility checks. |
| OWASP MASVS | Mobile security categories for storage, auth, network, platform interaction, code quality, resilience, and privacy tasks. |

## Release readiness checklist

Before marking a task active for an official preset:

- [ ] `release.status` is intentional.
- [ ] `qa/admission_report.json` is current.
- [ ] Hidden tests are not present in `baseline/`.
- [ ] Hidden fixtures avoid copied prompt/public-test literals.
- [ ] Reference and negative cases match the current prompt.
- [ ] V1+ p2p preservation evidence is current.
- [ ] V1+/V2 deleted/weakened-public-test negative case is rejected when applicable.
- [ ] Difficulty and tags reflect actual task behavior.
- [ ] Timeout and resources are realistic.
- [ ] The task can run offline by default.
- [ ] Known limitations are documented in the task notes or spec update if needed.
