# PickArena Mobile Agent Benchmark

Status: active consolidated master spec
Created: 2026-06-15
Updated: 2026-06-15
Supersedes: `docs/specs/old/2026-05-31-pickarena-by-pickforge-studio-master.md`

## Goal

Make PickArena the source-of-truth benchmark for mobile/app developer agents. The benchmark starts with Flutter because the current runner, task corpus, and PickForge product surface are Flutter-first, then expands to React Native Android, native Android, and native iOS while keeping the same reproducibility and grading standards.

PickArena should answer one question clearly: **which coding agents can take realistic mobile developer prompts, edit an app workspace, and produce behavior that passes clean hidden verification without fake fixes, overfitting, or verifier leakage?**

## Scope

In scope:

- Agentic mobile coding tasks that require workspace inspection, edits, and test execution.
- Direct codegen tasks where the runner can safely isolate generated code.
- Flutter first/deepest coverage, followed by React Native Android, native Android, and native iOS.
- Hidden behavioral verification, negative cases, QA admission reports, reproducible exports, release reports, and public leaderboard data.
- DeepSWE-style task rigor: original human-style prompts, clean grading environments, patch capture, separate verifier context, flake checks, f2p/p2p evidence, and pass/duration/cost/token/error metrics.

Out of scope for this spec:

- Provider credential management beyond existing runner support.
- Public website redesigns not needed to publish benchmark evidence.
- Changing task fixtures, hidden tests, solutions, QA reports, scripts, web data, or runner code from this documentation pass.

## Research anchors

Internal:

- [Spec entry point](README.md) — short path through MVP, V1, and V2.
- This spec — active benchmark source of truth.
- [Task overview](../../tasks/README.md) and [task authoring reference](../../tasks/AUTHORING.md) — task corpus and authoring rules.
- [Bubblewrap sandbox contract](2026-06-05-bubblewrap-public-run-sandbox.md) — release sandbox and provenance constraints.
- [Archived PickArena master spec](old/2026-05-31-pickarena-by-pickforge-studio-master.md) — historical context only.

External:

- DeepSWE — clean grading, patch replay, hidden separation, f2p/p2p, flake, provenance, and public evidence.
- BridgeBench — UI, debugging, refactoring, reasoning, security, speed, and fake-fix category breadth.
- [Flutter testing](https://docs.flutter.dev/testing/overview) / [accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility).
- [React Native testing](https://reactnative.dev/docs/testing-overview) / [React Native DevTools](https://reactnative.dev/docs/react-native-devtools) / [Metro](https://metrobundler.dev/docs/configuration).
- [Android UIAutomator](https://developer.android.com/training/testing/other-components/ui-automator), [ADB](https://developer.android.com/tools/adb), [logcat](https://developer.android.com/tools/logcat).
- [iOS XCTest](https://developer.apple.com/documentation/xctest), `xcodebuild`, `simctl`, [accessibility](https://developer.apple.com/accessibility/).
- [OWASP MASVS](https://mas.owasp.org/MASVS/).

## Product direction

PickArena is part of the PickForge mobile/app developer brand:

- **PickForge** is the mobile/app developer tool brand.
- **PickForge workbench tools** help agents see, run, inspect, and test apps.
- **PickArena** measures agent results with reproducible evidence.

Positioning:

- Mobile/app benchmark first, not a generic coding benchmark clone.
- Flutter is the flagship and deepest track.
- React Native Android, native Android, and native iOS become first-class once verifier and environment strategy are mature.
- Public claims must be tied to release reports, task QA evidence, exported artifacts, and clean run provenance.

## Current baseline

### Official Flutter corpus

The current official Flutter tasks live under `tasks/flutter`:

| Task id | Current focus |
| --- | --- |
| `accessibility.quantity_stepper_semantics` | Quantity stepper semantics labels/actions and disabled-at-limit accessibility state. |
| `async.refresh_deduplicator` | Async refresh deduplication, stale result protection, retry state. |
| `forms.email_validation` | Form validation, normalization, stale error clearing. |
| `lists.contact_search` | List filtering/search behavior. |
| `navigation.auth_redirect_race` | Navigation/auth redirect race behavior. |
| `persistence.offline_feed_preferences` | Offline feed preferences persistence and corrupt stored-value fallback. |
| `platform.channel_mock` | Platform channel mocking and service behavior. |
| `refactor.price_label_formatter` | Price label formatter extraction with behavior-preserving widget routing. |
| `state.selection_controller` | Selection state logic and controller behavior. |
| `ui.action_bar_overflow` | Responsive action bar overflow behavior, action priority, and accessibility. |

### Bundle shape

Current task bundles use this shape:

```txt
task.yaml
instruction.md
baseline/
hidden_tests/
solution/
negative_cases/
qa/admission_report.json
```

Meaning:

| Path | Purpose |
| --- | --- |
| `task.yaml` | Stable task metadata, workspace map, hidden verifier map, reference map, negative case map, resource and release metadata. |
| `instruction.md` | Human-style prompt shown to the model/agent. It must not reveal hidden paths, verifier names, solution details, or author notes. |
| `baseline/` | Starting workspace copied into the agent run. It should fail the intended hidden behavior before the fix. |
| `hidden_tests/` | Hidden behavioral verifier assets kept out of the prompt and agent workspace. |
| `solution/` | Reference passing implementation used for QA and admission. |
| `negative_cases/` | Known-bad implementations such as noop, API-breaking, and overfit fixes that must be rejected. |
| `qa/admission_report.json` | Admission evidence proving the task passed QA gates at a point in time. |

### Runner capabilities already present

The current runner baseline includes:

- Headless CLI execution through `dart_arena_headless`.
- Droid-backed agentic harness for local Factory Droid execution.
- Official Bubblewrap script for sandboxed official runs.
- Hidden tests and public/hidden pass split reporting.
- Negative case QA.
- Task admission QA reports.
- Leaderboard exports and release reports.
- Artifact bundles that support reproducibility and public audit.

This baseline is enough for the MVP Flutter official run. V1 and V2 extend the task corpus, framework breadth, and grading rigor without weakening these invariants.

## Benchmark invariants

These rules are mandatory for every admitted benchmark task and release run.

| Invariant | Requirement |
| --- | --- |
| Human prompt | `instruction.md` reads like a real mobile developer request, not a test-spec dump. |
| Prompt-verifier bijection | Every hidden assertion maps to a behavior requested or implied by the prompt; every critical prompt requirement has verifier coverage. |
| Hidden separation | Hidden tests, verifier names, reference solutions, QA notes, and author-only rationale are never copied into agent workspaces or prompts. |
| Separate verifier env | Grading runs in a clean verifier context, not in the same mutable context the agent used to reason. |
| Patch capture | Agent changes are captured as a patch or equivalent file diff so scoring can replay and audit the result. |
| Clean grading env | The submitted patch is replayed into a clean baseline before final grading. |
| Behavior over snapshots | Hidden checks assert user-observable behavior and API contracts, not brittle implementation details. |
| f2p/p2p evidence | Fail-to-pass checks prove the baseline fails the target behavior; pass-to-pass checks prove existing expected behavior stays passing. |
| Flake resistance | Tasks must pass repeated QA runs or document why a non-repeated gate is acceptable before admission. |
| Negative rejection | Noop, API-breaking, and overfit cases must fail the hidden/admission gates. |
| Environment cleanliness | Runs record SDK/tool versions, platform, resource limits, network policy, git state, and relevant dependency snapshots. |
| No fake fixes | Tasks should include enough hidden breadth to reject hardcoded values, prompt-only compliance, removed tests, broken APIs, or cosmetic edits. |
| Bounded execution | Tasks must be deterministic, offline by default, and sized to finish inside the declared timeout and resource limits. |

## Tracks and categories

### Tracks

| Track | Status | Description |
| --- | --- | --- |
| Agentic mobile patch | MVP | Agent receives a workspace and prompt, edits files, runs tools, and submits a patch for hidden grading. |
| Direct codegen | Existing runner capability | Model emits code for controlled generated-code paths; used where the task can be isolated safely. |
| Full app integration | V1/V2 | Agent works inside larger app contexts with UI, navigation, platform, or state interactions. |
| Security-focused mobile | V2 | Tasks based on OWASP MASVS-style findings and secure mobile implementation behavior. |
| Cross-framework mobile | V2 | Comparable task families across Flutter, React Native Android, native Android, and native iOS. |

### Category taxonomy

BridgeBench inspires the broad challenge categories. PickArena applies them to mobile app work:

| Category | Mobile examples |
| --- | --- |
| UI | Widget behavior, layout state, golden/accessibility expectations, navigation flows. |
| Debugging | Fix failing behavior, async races, flaky state, platform mocking mistakes. |
| Refactoring | Preserve behavior while improving structure, APIs, or testability. |
| Reasoning | Multi-step state machines, data filtering, auth redirects, offline behavior. |
| Security | Input handling, storage misuse, transport assumptions, OWASP MASVS-aligned issues. |
| Hallucination/fake-fix resistance | Reject hardcoded answers, removed tests, broken public APIs, invented dependencies, or prompt-only edits. |
| Speed | Measure time-to-pass, duration under resource limits, and agent/tool overhead. |

Current Flutter tasks mainly cover debugging, reasoning, UI-adjacent state, platform mocking, and fake-fix resistance. V1 should broaden UI and refactoring coverage. V2 should add security and cross-framework parity.

## Run presets

Presets are the user-facing benchmark modes. They should eventually auto-select task suites from task metadata instead of requiring manual task picking.

| Preset | Target | Auto-selection rule | Default evidence |
| --- | --- | --- | --- |
| MVP | Current official Flutter agentic benchmark. | Select active `private_official` Flutter tasks under `tasks/flutter` with `track: agentic` and admitted QA reports. | Hidden/public pass split, negative-case QA, artifact bundle, release report, duration/error summaries. |
| V1 | Broader Flutter mobile app benchmark. | Select active admitted Flutter tasks across bug fix, UI, state, platform, navigation, refactoring, and reasoning families. | MVP evidence plus repeated flake checks, richer category summaries, pass-to-pass preservation, and task-family coverage reports. |
| V2 | DeepSWE-grade cross-framework mobile benchmark. | Select active admitted task families tagged for Flutter, React Native Android, native Android, and native iOS where verifier environments are isolated and replayable. | V1 evidence plus patch replay in clean grading envs, f2p/p2p dashboards, cost/token metrics, framework parity reports, and security coverage summaries. |

Preset behavior expectations:

- The preset chooses tasks by metadata, not by hardcoded task ids, once the runner supports it.
- Presets may expose trial count, concurrency, timeout, provider/model, and release/run id options.
- A preset must refuse release labeling if required QA reports or clean provenance are missing.
- Public releases should identify the preset used and the exact task ids selected.

## Framework verifier strategies

| Framework | MVP/V1/V2 role | Verifier strategy |
| --- | --- | --- |
| Flutter | MVP flagship; V1 deepest coverage | `flutter test`, analyzer checks, widget tests, integration tests where needed, golden tests for stable visuals, accessibility semantics checks, hidden behavioral tests, and platform-channel mocks. |
| React Native Android | V2 expansion | Jest, React Native Testing Library, Metro/DevTools endpoint checks where useful, Android emulator verification, and hidden tests that avoid snapshot-only assertions. |
| Native Android | V2 expansion | Gradle unit and instrumentation tests, ADB install/run flows, logcat capture, screenshot evidence, UIAutomator hierarchy checks, and emulator resource isolation. |
| Native iOS | V2 expansion | XCTest, `xcodebuild`, `simctl`, simulator log capture, accessibility tree checks, and deterministic simulator state reset. |
| Mobile security | V2 category across frameworks | OWASP MASVS-inspired tasks with behavioral proof, static checks where reliable, and verifiers that reject superficial string or config-only fixes. |

Verifier principles:

- Prefer stable behavioral checks over implementation or screenshot brittleness.
- Use golden tests only when rendering is deterministic and tolerances are documented.
- Reset emulator/simulator/device state between attempts.
- Capture logs, screenshots, and accessibility/UI hierarchy when they help explain failures.
- Keep framework-specific tooling behind a common task admission and result schema.

## Task admission gates

A task is not part of an official preset until all applicable gates pass and the result is stored in `qa/admission_report.json`.

| Gate | Required proof |
| --- | --- |
| Structure | Required files exist; paths in `task.yaml` resolve; no hidden or solution files are copied into `baseline/`. |
| Metadata | Stable `id`, `version`, `category`, `track`, `difficulty`, `tags`, `timeoutSeconds`, platform requirements, release status, resource limits, and network policy. |
| Prompt | Original human-style prompt; no hidden paths, verifier names, author notes, or solution hints; scope is bounded and realistic. |
| Baseline f2p | Baseline fails intended hidden behavior for the intended reason. |
| Existing behavior p2p | Public/pass-to-pass checks prove existing behavior remains valid after the reference solution. |
| Reference solution | Reference passes public tests, hidden tests, analyzer/build checks, and framework-specific verifiers. |
| Negative cases | Required noop, API-breaking, and overfit cases are present and rejected. |
| Hidden breadth | Hidden tests cover edge cases, not just the public examples; they accept plausible alternative implementations. |
| Flake | Repeated local QA passes or an explicit documented exception before release admission. |
| Environment | QA report records SDK/tool versions, host platform, dependency snapshot, resource policy, network policy, and git state. |
| Release readiness | Active task is included only when `release.status` and QA evidence match the preset requirements. |

Admission checklist for authors:

- [ ] Write the prompt before writing hidden tests.
- [ ] Map each prompt requirement to public and/or hidden verifier coverage.
- [ ] Confirm the baseline fails the intended hidden behavior.
- [ ] Confirm the reference solution passes all verifiers.
- [ ] Add noop, API-breaking, and overfit negative cases.
- [ ] Run task QA and store `qa/admission_report.json`.
- [ ] Review the report for dirty environment, missing dependency snapshot, flake, or resource warnings.

## Metrics and reporting

Leaderboards and release reports should preserve enough detail to compare quality, reliability, and efficiency.

| Metric group | Examples |
| --- | --- |
| Quality | Overall pass, public pass, hidden pass, category score, task-family score, f2p success, p2p preservation, negative-case resistance. |
| Reliability | Trial variance, flake rate, retry count, tool failure count, timeout count, sandbox failure count, invalid patch count. |
| Speed | Wall duration, model response latency where available, tool/runtime duration, time-to-first-valid-patch, time-to-pass. |
| Cost/tokens | Prompt tokens, completion tokens, total tokens, provider-reported cost, estimated cost, unknown-cost counts, cost per pass. |
| Errors | Analyzer/build/test failures, verifier failures, agent harness failures, environment failures, malformed output, missing files. |
| Provenance | Run id, preset, task ids, model/provider ids, runner version, git commit/dirty state, SDK versions, OS, resource limits, network policy, artifact bundle path. |

Public summaries should make unknown telemetry explicit instead of treating it as zero. If a provider or harness does not report token/cost data, the release report should label the fields as unknown.

## Roadmap checklist

### MVP: official Flutter agentic baseline

- [x] Keep Flutter as the flagship framework.
- [x] Use file-backed task bundles under `tasks/flutter`.
- [x] Maintain the current official Flutter tasks under `tasks/flutter`, including the V1 async refresh vertical slice.
- [x] Preserve bundle shape: `task.yaml`, `instruction.md`, `baseline/`, `hidden_tests/`, `solution/`, `negative_cases/`, `qa/admission_report.json`.
- [x] Run agentic tasks through the headless CLI and Droid harness.
- [x] Support official Bubblewrap sandboxed runs.
- [x] Keep hidden tests, negative cases, task QA, exports, and release reports in the baseline.
- [ ] Add preset metadata/API for `MVP` so the runner can auto-select active admitted Flutter agentic tasks.
- [ ] Make MVP release reports name the preset and selected task ids explicitly.
- [ ] Keep task author docs current with admitted corpus expectations.

MVP completion definition: a clean official Flutter run can be reproduced from task metadata, scored with hidden tests, exported with release evidence, and published without manual task selection mistakes.

### V1: broader Flutter mobile benchmark

- [ ] Expand Flutter corpus across UI, debugging, refactoring, reasoning, platform, state, navigation, and fake-fix resistance.
- [ ] Add task families that cover real app workflows rather than only small controller files.
- [ ] Add stable Flutter widget, integration, golden, and accessibility verifier patterns.
- [ ] Add repeated flake checks to admission and release readiness.
- [ ] Track f2p and p2p evidence directly in reports.
- [ ] Add richer category and task-family leaderboard slices.
- [ ] Add `V1` preset auto-selection for active admitted Flutter tasks across approved categories.
- [ ] Improve author feedback when prompt-verifier bijection or negative-case coverage is weak.
- [ ] Document expected task budgets by difficulty and framework feature.

V1 completion definition: Flutter tasks cover enough app developer scenarios to compare agent strengths by category, with flake-resistant admission and preset-driven release runs.

### V2 / DeepSWE-grade: cross-framework mobile benchmark

- [ ] Capture and replay agent patches in clean grading environments for every official task.
- [ ] Separate agent workspace, verifier workspace, and release grading workspace.
- [ ] Add first-class f2p/p2p dashboards and acceptance gates.
- [ ] Require repeated flake checks for all official release tasks.
- [ ] Add prompt-verifier bijection review as an explicit admission artifact.
- [ ] Expand benchmark frameworks to React Native Android, native Android, and native iOS.
- [ ] Build framework-specific verifier harnesses for Jest/RNTL/Metro, ADB/logcat/screenshot/UIAutomator, XCTest/xcodebuild/simctl/accessibility, and OWASP MASVS-style security checks.
- [ ] Add cross-framework task families where the same mobile behavior is implemented in multiple stacks.
- [ ] Report pass, duration, cost, token, and error metrics consistently across providers and frameworks.
- [ ] Add environment cleanliness checks that block releases on hidden leakage, dirty baselines, missing dependency snapshots, or unreplayable patches.
- [ ] Add public release notes that describe task-family breadth, acceptance breadth, flake status, and known telemetry gaps.

V2 completion definition: PickArena can publish DeepSWE-grade mobile leaderboards where every official result is replayable from clean baselines, hidden verifiers are isolated, and framework breadth does not weaken grading rigor.

## Release policy

A run may be called an official benchmark result only when:

- It uses an explicit preset or an exported manifest listing all task ids.
- Every selected task is active, admitted, and has a current QA report.
- The run records environment provenance and task artifact provenance.
- Hidden verifiers are not exposed to the agent workspace or prompt.
- Generated patches/artifacts are retained long enough for audit.
- Release reports identify blockers, warnings, unknown telemetry, and dirty-worktree status.
- Public website data is generated from the release report/export path, not hand-edited.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Hidden verifier leakage | Keep hidden tests outside workspaces, validate bundle maps, and inspect exported artifacts before public sharing. |
| Prompt/test mismatch | Require prompt-verifier bijection review and hidden breadth checks before admission. |
| Flaky mobile environments | Use repeated QA, emulator/simulator reset, bounded resources, and explicit flake reporting. |
| Overfitting or fake fixes | Require negative cases, behavioral hidden tests, API preservation checks, and no hardcoded public examples. |
| Framework drift | Record SDK/dependency snapshots and version verifier harnesses with admission reports. |
| Cost/token gaps | Report unknown telemetry explicitly and separate provider-reported from estimated cost. |
| Cross-framework unfairness | Use per-framework leaderboards first, then compare task families only when verifier depth and difficulty are comparable. |
| Security task superficiality | Use OWASP MASVS as category guidance but grade observable secure behavior, not keyword presence. |
| Public claim overreach | Tie every claim to preset, task ids, release report, artifact bundle, and known limitations. |

## Living-document rules

- This file is the active single source of truth for PickArena benchmark direction.
- Task author entry points live in `tasks/README.md` and `tasks/AUTHORING.md`.
- Superseded specs stay under `docs/specs/old/` with a note instead of being deleted.
- Large implementation plans may live in `docs/plans/` while active and move to `docs/plans/old/` when complete or superseded.
- Keep this spec concise enough to maintain, but update it when presets, admission gates, task shape, framework strategy, or release policy changes.
