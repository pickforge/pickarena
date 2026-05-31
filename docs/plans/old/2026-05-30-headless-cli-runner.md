# Headless CLI Runner Implementation Plan

> **Status:** Draft plan after plan-review blocker.
> **Approach chosen:** true `dart run` CLI with JSON config only.

## Goal

Add a real headless command-line runner for reproducible Dart Arena benchmark jobs on CI/server shells, without launching the Flutter UI.

## Success criteria

- A user can run a benchmark from JSON config with `dart run --verbosity=error dart_arena:dart_arena_headless --config run.json` from the repo/package.
- The command does not import Flutter-only libraries along the CLI execution path.
- The command validates config, resolves tasks/providers/models, runs codegen benchmark combos, exports the existing Phase 6 bundle, and prints compact JSON to stdout.
- Exit code is `0` for completed runs and non-zero for config, task/provider, timeout, database, run, or export failures.
- Secrets are read from environment variables and never echoed in stdout/stderr, persisted config, or bundle summaries.
- MVP supports codegen tasks only; agentic tasks fail fast with a clear unsupported-track error.
- Existing app/UI behavior, package name, storage defaults, and benchmark scoring remain unchanged.

## Current context

- Existing headless service: `lib/headless/headless_benchmark_runner.dart`, currently implemented through `RunBloc` and therefore not usable by true `dart run`.
- Existing runner core: `RunBloc`, `StartRun`, `WorkdirManager`, `RunDao`, `AppDatabase`, `exportRunBundle`.
- Existing blockers for true Dart CLI:
  - `RunBloc` imports Flutter and Flutter BLoC;
  - `FixtureLoader` and `PlanLoader` import Flutter `rootBundle`;
  - `database.dart` and `artifact_bundle.dart` import `path_provider` for default paths;
  - settings/provider factory imports secure storage and should not be used by CLI.
- Existing Phase 7 tests cover `HeadlessBenchmarkRunner` with fakes but also assert no standalone CLI exists.

## Proposed changes

### 1. Pure-Dart compatibility seams

- Make task/plan loading compatible with both Flutter app assets and Dart CLI files:
  - split `FixtureLoader` behind conditional imports;
  - use a Flutter-specific conditional import condition (`if (dart.library.ui)`) for the `rootBundle` implementation and a Dart VM/file fallback otherwise; do not select the CLI fallback with `dart.library.io`, because Flutter desktop also has `dart:io`;
  - Flutter implementation keeps `rootBundle` behavior;
  - Dart implementation reads from `Directory.current` or a configurable repo root, preserving the same asset-relative paths;
  - apply the same pattern to `PlanLoader`.
- Move `path_provider` usage out of files imported by CLI:
  - keep `AppDatabase([QueryExecutor?])` unchanged for callers;
  - put the default app-support database opener behind a conditional helper so `database.dart` itself is Dart-VM importable;
  - do the same for `artifact_bundle.dart` default allowed trajectory roots/environment helpers, or isolate path-provider-only defaults behind conditional imports.
- Keep Flutter UI defaults behavior-equivalent.

### 2. Pure codegen execution core

- Extract codegen combo execution from `RunBloc` into a pure-Dart service, e.g. `lib/runner/codegen_task_executor.dart`.
- The service should own only codegen concerns:
  - prompt construction with optional reference plan;
  - streaming and non-streaming model generation;
  - Dart code extraction;
  - workdir creation/prepare;
  - evaluator execution;
  - aggregate score/result primitive calculation;
  - `TaskRunResult` construction.
- Update `RunBloc` codegen path to call the new service with a progress callback, preserving existing UI behavior and reducing divergence.
- Keep agentic execution in `RunBloc` unchanged and out of CLI MVP.

### 3. True headless runner

- Refactor `HeadlessBenchmarkRunner` so it no longer depends on `RunBloc`.
- It should:
  - validate/normalize model selections;
  - reject non-codegen tasks;
  - call `task.ensureLoaded()`;
  - optionally persist reference plans;
  - create deterministic combos across tasks/providers/models/trials;
  - call `runDao.startRun`, `buildRunProvenanceJson`, `runDao.updateRunProvenance`, `runDao.persistTaskRun`, and `runDao.finishRun`;
  - enforce timeout;
  - dispose providers and close stream subscriptions/resources;
  - export the existing Phase 6 bundle;
  - preserve current failure semantics: failed combo returns non-zero and does not export a misleading completed bundle.
- Keep `HeadlessBenchmarkConfig` as the in-process API used by tests and CLI.

### 4. CLI entrypoint and JSON config

- Add `bin/dart_arena_headless.dart` and expose it in `pubspec.yaml` `executables`.
- Parse arguments:
  - `--config <path>` required;
  - `--help` prints one JSON help object to stdout and exits `0`; advertised invocations use `dart run --verbosity=error dart_arena:dart_arena_headless ...` so Dart native-assets build-hook messages do not prefix JSON.
- Add `lib/headless/headless_cli_config.dart` for JSON parsing/validation.
- Add `lib/headless/headless_cli_runner.dart` for runtime wiring.
- Supported config:

```json
{
  "runId": "nightly-2026-05-30",
  "name": "Nightly benchmark",
  "tasks": ["bug.off_by_one_pagination"],
  "providers": [
    {
      "type": "openai",
      "models": ["gpt-5.5"],
      "apiKeyEnv": "OPENAI_API_KEY"
    },
    {
      "type": "openai_compatible",
      "id": "local",
      "displayName": "Local gateway",
      "baseUrl": "http://127.0.0.1:11434/v1",
      "models": ["local-model"],
      "apiKeyEnv": "LOCAL_GATEWAY_API_KEY",
      "defaultEfforts": ["low", "medium", "high"],
      "extraHeaders": {"X-Source": "dart-arena"}
    }
  ],
  "judge": {
    "providerId": "openai",
    "model": "gpt-5.5"
  },
  "evaluatorWeights": {},
  "maxConcurrency": 2,
  "trialsPerTask": 1,
  "useReferencePlan": false,
  "workdirRoot": ".dart_arena/workdirs",
  "outputDir": ".dart_arena/bundles",
  "databasePath": ".dart_arena/dart_arena.sqlite",
  "timeoutSeconds": 600
}
```

- On success, print one JSON object to stdout:

```json
{
  "status": "completed",
  "runId": "nightly-2026-05-30",
  "bundlePath": "/abs/path/dart_arena_run_nightly-2026-05-30",
  "taskRunCount": 12,
  "evaluationCount": 48,
  "bundleWarningCount": 0
}
```

- On failure, print one JSON object to stderr:

```json
{
  "status": "failed",
  "error": "unknown task id: missing.task"
}
```

### 5. Config validation and path safety

- Required fields: `runId`, `tasks`, `providers`, `workdirRoot`, `outputDir`, `databasePath`.
- `tasks` and each provider `models` list must be non-empty.
- `maxConcurrency`, `trialsPerTask`, and `timeoutSeconds` must be positive integers.
- `evaluatorWeights` is optional; omitted or `{}` means `defaultEvaluatorWeights`, and provided keys are finite, non-negative numeric overrides merged over `defaultEvaluatorWeights`.
- `runId` and provider IDs must be strict safe path segments:
  - unique;
  - no `/`, `\\`, `..`, empty strings, absolute paths, or reserved provider ID collisions;
  - use a conservative regex such as `^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$`.
- Model IDs remain provider-native strings for API calls/provenance, but every filesystem path segment derived from a model ID must use a robust safe segment encoding/digest that never emits `.`, `..`, path separators, backslashes, absolute-like paths, or empty strings; do not rely on `Uri.encodeComponent` for this.
- `workdirRoot`, `outputDir`, and `databasePath` are interpreted relative to the config file directory unless absolute.
- `outputDir` must not be inside `workdirRoot/runs`.
- malformed field types fail with actionable messages.
- env var values are read at runtime and never included in thrown/printed errors.

### 6. Provider config behavior

- Built-in API providers require `apiKeyEnv`; missing or empty env vars fail with `missing environment variable: NAME`.
- Supported provider types:
  - `openai`, `openrouter`, `deepseek`, `anthropic`, `opencode_go`;
  - `ollama_local`, `ollama_cloud`;
  - `openai_compatible`;
  - `droid` as direct `DroidExecProvider.generate` codegen mode only, not agentic harness execution.
- Ollama local may omit `apiKeyEnv`; default base URL remains `http://localhost:11434`.
- OpenAI-compatible providers require `id`, `displayName`, `baseUrl`, and `models`; `apiKeyEnv` is optional.
- `modelsByProvider` is derived from provider config IDs and model lists.
- Judge `providerId` must match a configured provider ID, and judge `model` must be non-empty.
- Add a small environment-reader and provider-factory seam so tests can inject fake env/providers without network or process calls.

### 7. Tests

- Update Phase 7 “no standalone CLI” test to expect the new entrypoint.
- Add tests under `test/headless/`:
  - config parser accepts valid JSON and rejects malformed/required-field/type errors;
  - path-safe validation rejects malicious `runId` and provider IDs, and model-derived workdir segments are safe for `.`, `..`, slashes, backslashes, and absolute-like inputs;
  - `evaluatorWeights` omitted/empty configs use defaults, and malformed/non-finite values fail validation;
  - missing env secret reports only the env var name, not any value;
  - unknown task/provider/judge provider errors are clear;
  - agentic task selection fails fast as unsupported in MVP;
  - pure Dart imports work by running `dart run --verbosity=error dart_arena:dart_arena_headless --help`;
  - conditional fixture/plan loader tests cover both Flutter `rootBundle` behavior and Dart VM file-system fallback;
  - CLI `--help`, success stdout, and failure stderr each emit exactly one parseable JSON object with no prefix or suffix;
  - deterministic fake-provider run creates a Phase 6 bundle and stdout JSON summary;
  - failed provider/run exits non-zero and does not create a misleading completed bundle;
  - existing UI `RunBloc` codegen behavior remains covered after extracting the codegen executor.
- Use existing `DeterministicFakeProvider`, `FailingFakeProvider`, and `NoOpPrepareWorkdirManager` where possible; add test seams rather than real network calls.

### 8. CI and validation

- Update `.github/workflows/ci.yml` format/test paths to include `bin/` and new headless CLI tests.
- Run:

```sh
flutter pub get
dart format --set-exit-if-changed bin lib test
dart run --verbosity=error dart_arena:dart_arena_headless --help
flutter analyze
flutter test test/headless
flutter test
```

## Files touched

- `bin/dart_arena_headless.dart` — new true Dart CLI entrypoint.
- `pubspec.yaml` — expose executable.
- `lib/core/fixture_loader.dart` plus conditional implementations — CLI-safe fixture loading.
- `lib/core/plan_loader.dart` plus conditional implementations — CLI-safe reference plan loading.
- `lib/storage/database.dart` plus conditional default connection helper — remove path-provider import from CLI path.
- `lib/export/artifact_bundle.dart` plus conditional default helper if needed — remove path-provider import from CLI path.
- `lib/runner/codegen_task_executor.dart` — extracted pure codegen combo executor.
- `lib/runner/run_bloc.dart` — delegate codegen combo execution to pure executor.
- `lib/headless/headless_benchmark_runner.dart` — remove `RunBloc` dependency and use pure headless scheduler.
- `lib/headless/headless_cli_config.dart` — config types/parser/validation.
- `lib/headless/headless_cli_runner.dart` — CLI runtime wiring around the headless runner.
- `test/headless/headless_benchmark_runner_test.dart` — update no-CLI assertion and preserve runner behavior.
- `test/headless/headless_cli_config_test.dart` — parser/path safety tests.
- `test/headless/headless_cli_runner_test.dart` — CLI wiring/output behavior tests.
- `test/support/headless_fakes.dart` — only if extra fakes/seams are needed.
- `.github/workflows/ci.yml` — include new CLI paths/tests.

## Out of scope

- YAML config.
- Agentic harness execution from CLI.
- Interactive prompts.
- Release packaging, installers, or shell completions.
- Storing provider secret values in config files.

## Risks and mitigations

- **Refactor risk around RunBloc:** extract only codegen combo execution and keep agentic/UI scheduling unchanged; rely on existing run bloc tests plus full suite.
- **Task asset loading divergence:** use conditional loaders with identical asset-relative paths and tests for Dart CLI and Flutter test paths.
- **Path traversal:** strict segment validation for IDs and explicit tests for malicious config.
- **Secrets leakage:** error messages mention env var names only; stdout summary excludes provider config and provenance redacts secrets.
- **Network flakiness:** tests use injected fake providers or local deterministic test servers only.
- **Output collisions:** preserve `exportRunBundle` no-overwrite behavior and surface its error clearly.
