# Sandbox Architecture Decision Plan

Status: active
Created: 2026-06-03

## Context

The master spec requires stronger public-run sandboxing before official benchmark claims. Current implementation already covers several controls but does not yet provide a full isolation boundary for untrusted generated code.

Current implemented controls:

- Generated-code subprocess environments scrub unrelated and secret-looking variables by default.
- Provider subprocesses can preserve only explicitly referenced Factory custom model credentials.
- File-backed tasks declare `allowInternet` and `resources` policy metadata.
- Network-disabled task preparation uses offline dependency resolution and does not fall back to online resolution.
- Evaluator subprocesses enforce wall-clock timeouts, process-tree cleanup, and bounded stdout/stderr capture.
- Task `maxOutputBytes` is enforced for public and hidden test evaluators.
- Hidden verifier tampering is detected and reported as an infrastructure failure.
- Headless config can set `requireGeneratedCodeSandbox: true` to require Bubblewrap enforcement for generated-code prepare/evaluator subprocesses.

Remaining isolation requirements:

- Complete filesystem escape coverage beyond the current Bubblewrap workdir/private-temp/read-only-bind model.
- CPU, memory, and process limits that apply to the benchmark process tree, not the whole host user.
- A documented official/public-run sandbox mode with clear guarantees and fallback behavior.
- Adversarial tests for filesystem escape, network access, process exhaustion, memory exhaustion, and hidden verifier protection under the selected sandbox.

## Local Capability Check

Available on this machine:

- `/usr/bin/bwrap`
- `/usr/bin/docker`
- `/usr/bin/podman`
- `/usr/bin/systemd-run`
- `/usr/bin/unshare`

Not found:

- `firejail`

## Candidate Backends

### Option A: Bubblewrap

Use `bwrap` for Linux public-run evaluator and prepare subprocesses.

Advantages:

- Rootless and does not require a container daemon.
- Supports read-only bind mounts, writable workdir binds, private `/tmp`, `/proc`, `/dev`, and `--unshare-net`.
- Fits the existing local-runner model better than Docker/Podman.

Risks:

- Linux-only; macOS/Windows need a documented unsupported/fallback mode.
- Flutter/Dart tests need careful read-only binds for SDKs, pub cache, system libraries, and generated workdir assets.
- CPU/memory/process limits likely still need a companion mechanism such as cgroups/systemd-run.

### Option B: Podman/Docker

Run generated-code evaluation inside a pinned container image.

Advantages:

- Stronger reproducibility for official release environments.
- Natural CPU, memory, process, network, and filesystem controls.
- Easier to document official benchmark environment once an image is pinned.

Risks:

- Requires a daemon or rootless container setup.
- Larger operational dependency for local app users.
- Need image build/pinning, SDK cache strategy, and artifact mount rules.

### Option C: systemd-run/unshare/ulimit Composition

Compose namespaces and cgroup limits using host tools.

Advantages:

- Can enforce cgroup resource limits without a full container image.
- Might integrate with existing host Flutter/Dart SDK installation.

Risks:

- More host-distribution-specific than Bubblewrap or containers.
- `ulimit` alone is insufficient: process limits are per user, not per benchmark tree.
- Harder to test portably.

## Proposed Decision Point

- [x] Choose one official Linux sandbox backend before implementing full sandbox hardening.

Decision: use Bubblewrap as the first official Linux local/public-run sandbox backend. Keep the runner abstraction open for a future Podman/Docker backend if reproducible pinned release images become a higher priority.

Options:

- Recommended implementation path: Bubblewrap for local/public-run isolation, with cgroup-backed resource limits added only if Bubblewrap alone cannot satisfy CPU/memory/process requirements.
- Alternative implementation path: Podman/Docker for official release runs if reproducible container images are more important than local desktop simplicity.

Until resource-limit provenance and the broader adversarial suite are complete, the master spec checkbox for full process/resource/network controls should remain unchecked.

## Implementation Progress

2026-06-05:

- Added a generated-code sandbox abstraction and Bubblewrap backend.
- Replaced the headless `requireGeneratedCodeSandbox` fail-fast guard with Bubblewrap enforcement.
- Wired Bubblewrap through generated-code `prepare` and shared evaluator subprocesses for codegen and agentic grading paths.
- Kept provider/model subprocesses outside the generated-code sandbox.
- Bound system/SDK/pub-cache inputs read-only, task workdirs read-write, and temp/cache/stamp writes to private workdir-backed paths.
- Disabled network with `--unshare-net` unless a task explicitly allows internet.
- Recorded run provenance as `generatedCodeSandbox.required=true`, `enforced=true`, `backend=bubblewrap`.
- Added Bubblewrap policy, evaluator-process, and prepare integration tests.
- Validated with custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-sandbox-20260605`: one task run, four evaluations, aggregate score `1.0`, zero bundle warnings, Bubblewrap backend recorded in manifest and leaderboard provenance, and no sandbox-enforcement release blocker.
- Added an effective default resource policy for generated-code tasks, filling missing task limits with 2 CPUs, 8192 MB, 64 processes, and 1 MiB output, and using that effective policy for evaluator enforcement, run provenance, task artifacts, and task QA metadata.
- Added Bubblewrap network isolation coverage proving a sandboxed evaluator cannot reach a host loopback server when task policy disables internet.
- Validated with custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-resource-policy-20260605`: one task run, four evaluations, aggregate score `1.0`, zero bundle warnings, Bubblewrap backend and concrete task resource policy recorded in manifest and leaderboard provenance under the earlier resource-metadata gate.
- Documented the public-run Bubblewrap guarantee and unsupported fallback behavior in `docs/specs/2026-06-05-bubblewrap-public-run-sandbox.md`, including the non-guarantees for cgroup memory/process limits, seccomp filtering, pinned OS images, and provider/model sandboxing.
- Added hidden-verifier tamper/cleanup coverage while hidden tests run through Bubblewrap and validated the slice with custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-hidden-safety-20260605`: one task run, four evaluations, aggregate score `1.0`, zero bundle warnings, Bubblewrap enforcement and concrete task network/resource policy recorded under the earlier resource-metadata gate, and no sensitive marker hits beyond expected public custom-model metadata.
- Added explicit task `resourceEnforcement` provenance. The pre-cgroup Bubblewrap implementation recorded output, process, and RSS memory limits as evaluator-enforced, but recorded CPU as not enforced because it was only bounded by wall-clock timeout. Release-report readiness blocked those runs as incomplete/unenforced task resource provenance instead of treating declared CPU metadata as an enforced quota.
- Validated that tightened pre-cgroup gate with custom GPT 5.3 Codex Spark smoke `spark-resource-enforcement-provenance-20260605`: one task run, four evaluations, aggregate score `1.0`, zero bundle warnings, Bubblewrap sandbox enforcement still recorded, and release-report execution readiness correctly blocked with `manifestProvenanceTaskResourceLimitStatus == not_enforced`.
- Added cgroup-backed task CPU enforcement by wrapping CPU-limited generated-code prepare/evaluator subprocesses in `systemd-run --user --scope --quiet --expand-environment=no -p CPUQuota=<cpus * 100>%` around the existing Bubblewrap command.
- Updated task resource enforcement provenance so `cpus` is recorded as `systemdCpuQuota` with `kernelEnforced=true`, while memory/process/output keep their existing evaluator-side mechanisms.
- Added Bubblewrap CPU policy command-shape coverage and an integration test proving a CPU-limited evaluator subprocess runs through the cgroup wrapper inside Bubblewrap with clean output capture.
- Validated with custom GPT 5.3 Codex Spark smoke `spark-cgroup-cpu-20260605`: one task run, four evaluations, aggregate score `1.0`, zero bundle warnings, CPU enforcement recorded as `systemdCpuQuota` with `kernelEnforced=true`, release-report execution gate passed, and `manifestProvenanceTaskResourceLimitStatus == present`.
- Added a writable sandbox-local overlay for Flutter's SDK cache lockfile, keeping the Flutter SDK read-only while allowing sandboxed `flutter pub get --offline` to acquire its cache lock.
- Reset agentic patch baselines after initial dependency preparation and ignore benchmark tool-state paths, preventing Bubblewrap/Flutter/pub-cache bookkeeping from being captured as model patches.
- Validated the final sandboxed official repeated evidence with custom GPT 5.3 Codex Spark run `spark-sandboxed-official-repeated-baseline-20260605`: five active private-official Flutter tasks, two trials each, Bubblewrap and task resource enforcement recorded for all tasks, corpus/execution/scoring release-report gates passing, and reporting blocked by real Droid harness failures before patch generation (`missing_patch_text: 10`) plus dirty git provenance.

## Implementation Steps After Decision

- [x] Add a sandbox runner abstraction around generated-code prepare/evaluator subprocesses.
- [x] Implement the selected backend behind an explicit public-run sandbox mode.
- [x] Replace the current `requireGeneratedCodeSandbox` fail-fast guard with the selected backend enforcement.
- [x] Keep provider/model subprocesses outside the generated-code sandbox, while preserving provider credential scrubbing rules.
- [x] Bind only required SDK/cache/system paths read-only, bind the task workdir read-write, and use private temp directories.
- [x] Disable network by default for generated-code evaluation unless the task policy explicitly allows it.
- [x] Enforce task resource policy or fail fast with an infrastructure error when a policy cannot be enforced.
  - Progress: evaluator subprocesses now receive effective max-output, max-process, and RSS memory limits from task policy defaults or explicit task overrides. Generated-code prepare/evaluator subprocesses now receive effective task CPU limits through a user systemd cgroup quota around the Bubblewrap command. Run provenance, Task QA reports, artifact manifests, and leaderboard source provenance record explicit resource-enforcement mechanisms.
- [x] Add adversarial sandbox tests for environment, filesystem, network, process, memory, output, and hidden verifier tampering.
  - Progress: Bubblewrap integration coverage now includes filesystem/host-file isolation, private workdir writes, private temp mounts, read-only system-bind write blocking, no-network loopback isolation, allowed-network loopback reachability, policy command construction, sandboxed prepare execution, Flutter SDK cache lockfile overlay, sandboxed CPU cgroup wrapping, sandboxed process-count enforcement, sandboxed output-limit enforcement, sandboxed RSS memory-limit enforcement, hidden-test read attempts against the generated workspace, hidden-verifier read-only staging, hidden-verifier tamper blocking while hidden tests run through Bubblewrap, and prepared-baseline patch capture, alongside existing adversarial process, memory, output, environment, hidden-verifier staged-file tamper detection, and hidden-verifier cleanup tests.
- [x] Document official/public-run sandbox guarantees and unsupported fallback behavior.
