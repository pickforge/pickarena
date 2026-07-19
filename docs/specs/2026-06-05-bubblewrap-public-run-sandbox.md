# Bubblewrap Public-Run Sandbox Contract

Status: active
Created: 2026-06-05

## Scope

This contract defines the first official Linux local/public-run sandbox mode for generated-code execution.

It applies to:

- Generated-code dependency preparation.
- Generated-code evaluator subprocesses for codegen and agentic grading paths.
- Headless runs where `requireGeneratedCodeSandbox` is set to `true`.

It does not apply to:

- Provider/model calls.
- Droid or other agent harness execution before generated code is written.
- Local exploratory runs that do not set `requireGeneratedCodeSandbox`.

Provider/model processes remain outside Bubblewrap so they can reach their configured APIs, but they still use the existing provider credential and subprocess-environment scrubbing rules.

## Required Activation

Public or untrusted benchmark runs must set:

```json
{
  "requireGeneratedCodeSandbox": true
}
```

When this flag is enabled, the headless runner builds a `bubblewrap` generated-code sandbox. The run must fail before benchmark execution if the host is not Linux or if `bwrap --version` cannot be started successfully.

Runs that omit `requireGeneratedCodeSandbox` may still be useful for local development, but release readiness must treat them as not sandbox-enforced. Such runs must not publish official public benchmark claims.

## Guaranteed Controls

The Bubblewrap backend currently enforces the following controls for generated-code prepare and evaluator subprocesses:

- Runs the generated-code process under the recorded `bubblewrap` backend.
- Records run provenance with `generatedCodeSandbox.required == true`, `generatedCodeSandbox.enforced == true`, and `generatedCodeSandbox.backend == "bubblewrap"` when required mode is active.
- Uses a tmpfs sandbox root.
- Binds required system roots such as `/usr`, `/bin`, `/lib`, `/lib64`, and `/etc` read-only when present.
- Binds the generated task workdir read-write and uses it as the sandbox working directory.
- Uses private `/tmp` and `/var/tmp` tmpfs mounts.
- Provides `/dev` and `/proc` inside the namespace.
- Uses `--die-with-parent`, `--unshare-pid`, `--unshare-ipc`, and `--new-session`.
- Uses `--unshare-net` unless the task explicitly allows internet access.
- Resolves Flutter/Dart tool roots and binds SDK/tool inputs read-only when they are outside the system roots.
- Overlays Flutter writable cache stamp files, `engine.realm`, and `bin/cache/lockfile` into workdir-private files when needed while keeping the Flutter SDK read-only.
- For network-disabled tasks, binds the host `PUB_CACHE` read-only and overlays only `active_roots` as a workdir-private writable path.
- For network-allowed tasks, replaces `PUB_CACHE` with a workdir-local cache.
- Resets the agentic patch baseline after initial dependency preparation, and ignores benchmark tool-state paths such as `.dart_arena/`, `.flutter`, and `.config/tool_state`, so dependency-prepare and sandbox bookkeeping are not exported as model patches.
- Scrubs generated-code environments, including proxy variables, credential-file pointers, package-registry pointers, Git helper variables, home/XDG roots, analyzer state roots, and unrelated secret-looking values unless explicitly allowlisted by provider code.
- Wraps generated-code prepare subprocesses with `CPUQuota=<cpus * 100>%` and evaluator subprocesses with `CPUQuota`, `MemoryMax=<memoryMb>M`, and `TasksMax=<maxProcesses>` in a `systemd-run --user --scope` cgroup.
- Applies evaluator wall-clock timeouts, process-tree termination, raw-byte-bounded stdout/stderr capture, and process-count/RSS polling as diagnostic fallback checks.
- Records a `resourceEnforcement` map next to task `resources`, so release audits distinguish declared limits from enforcement mechanisms.
- Records effective task network and resource policy in run provenance, task artifacts, task QA metadata, and leaderboard source provenance.

## Explicit Non-Guarantees

The current Bubblewrap backend does not claim:

- macOS or Windows support.
- A pinned or reproducible OS/container image.
- Seccomp filtering beyond Bubblewrap's namespace and mount controls.
- Isolation of provider/model API calls or Droid harness execution.
- Complete removal of read-only visibility into host system roots, SDKs, or pub cache content needed to run Flutter/Dart tools.

Today, task `cpus`, `memoryMb`, and `maxProcesses` are enforced through a user systemd cgroup when generated-code sandboxing is active. `maxOutputBytes` is enforced on raw process bytes before decoding, with process-tree cleanup on violation. Runs without the kernel-backed sandbox record CPU, memory, and process enforcement as false; release-report readiness blocks that evidence.

## Unsupported Fallback Behavior

For public or untrusted runs:

- Missing Linux support is an infrastructure failure.
- Missing or failing `bwrap` is an infrastructure failure.
- Missing or failing user `systemd-run --scope` cgroup support is an infrastructure failure for public runs with task CPU, memory, or process policy.
- A run must not silently downgrade to unsandboxed execution when `requireGeneratedCodeSandbox` is `true`.
- Release readiness must block if stored provenance does not show generated-code sandbox enforcement with a backend.

For local development runs:

- The flag may be omitted to run without Bubblewrap.
- Unsandboxed local runs may be used for debugging only.
- Unsandboxed local runs must not be promoted to official release evidence.

## Verification Evidence

Current focused coverage includes:

- Bubblewrap command construction tests for no-network and network-allowed pub-cache policy.
- Bubblewrap prepare integration through `WorkdirManager`.
- Bubblewrap evaluator integration proving host files outside the workdir are not visible and outside-workdir writes do not reach the host.
- Bubblewrap no-network integration proving a sandboxed evaluator cannot reach a host loopback server.
- Bubblewrap allowed-network integration proving a task that explicitly allows internet can reach a host loopback server.
- Bubblewrap mount integration proving `/tmp` is private and system-bind writes do not reach the host.
- Bubblewrap resource integration proving evaluator process-count enforcement still works when the process is started through Bubblewrap.
- Bubblewrap resource integration proving raw-byte output limits and memory limits still work when the process is started through Bubblewrap.
- Bubblewrap resource integration proving CPU, memory, and process limits map to `CPUQuota`, `MemoryMax`, and `TasksMax` in the `systemd-run --user --scope` cgroup wrapper.
- Bubblewrap hidden-verifier integration proving hidden verifier files are staged outside the generated workdir, mounted read-only into Bubblewrap, unavailable through the workspace `test/_hidden` path, protected from sandboxed tampering, and cleaned up after evaluation.
- Bubblewrap Flutter cache integration proving SDK cache `lockfile` is backed by a writable sandbox-local overlay even when absent from the host cache.
- Agentic patch-capture integration proving dependency-prepare and sandbox bookkeeping files are baselined or ignored before the harness runs.
- Existing adversarial evaluator tests for environment scrubbing, output flooding, process-count limits, RSS memory limits, timeout cleanup, and hidden-verifier cleanup.
- Custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-sandbox-20260605`, which recorded Bubblewrap enforcement with zero artifact warnings and no sandbox-enforcement release blocker.
- Custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-resource-policy-20260605`, which recorded Bubblewrap enforcement plus concrete task network/resource policy in manifest, leaderboard source provenance, and release-report evidence under the earlier resource-metadata gate.
- Custom GPT 5.3 Codex Spark smoke `spark-bubblewrap-hidden-safety-20260605`, which passed one codegen task with aggregate score `1.0`, emitted zero bundle warnings, recorded Bubblewrap enforcement and concrete task network/resource policy under the earlier resource-metadata gate, and produced no sensitive marker hits beyond expected public custom-model metadata.
- Custom GPT 5.3 Codex Spark smoke `spark-resource-enforcement-provenance-20260605`, which passed one codegen task with aggregate score `1.0` and zero bundle warnings while the pre-cgroup release-report execution gate correctly blocked the run with `manifestProvenanceTaskResourceLimitStatus == not_enforced` because Bubblewrap did not yet enforce the task CPU quota.
- Custom GPT 5.3 Codex Spark smoke `spark-cgroup-cpu-20260605`, which passed one codegen task with aggregate score `1.0`, emitted zero bundle warnings, recorded CPU enforcement as `systemdCpuQuota` with `kernelEnforced=true`, passed the release-report execution gate, and reported `manifestProvenanceTaskResourceLimitStatus == present`. The smoke release report remained blocked only by expected one-task/dirty-worktree/task-QA-scope blockers.
- Custom GPT 5.3 Codex Spark repeated run `spark-sandboxed-official-repeated-baseline-20260605`, which exercised all five active private-official Flutter tasks with two trials each under Bubblewrap after the Flutter lockfile and prepared-baseline fixes. The run recorded Bubblewrap enforcement and task resource enforcement for all tasks; it remained blocked by Droid harness failures before patch generation, producing `missing_patch_text: 10` and no publishable score.

The master sandbox-hardening checklist is complete for the current Linux Bubblewrap public-run threat model. Official release publication remains tracked separately by the master release/reporting pass.
