<p align="center">
  <img src="app/assets/branding/dart_arena_logo_horizontal_dark.png" alt="Dart Arena logo" height="250">
</p>

# Dart Arena

Dart Arena is a Flutter desktop app for benchmarking AI coding models on Dart and Flutter tasks. It helps compare model quality across code generation, agentic execution, hidden verification, repeated trials, and human preference review.

## What it measures

- **Codegen and agentic tracks:** run direct model responses as well as agent-style planning/execution workflows.
- **Task QA and hidden verifiers:** score tasks with compile checks, analyzer checks, visible tests, hidden/reference tests, diff-size signals, and LLM judges.
- **Reliable leaderboards:** repeat trials per task/model combo and aggregate results across quality, speed, reliability, and category dimensions.
- **Human review:** compare competing outputs in a review queue and fold preferences into rankings.
- **Provenance and exports:** save run manifests, environment details, summaries, CSV/Markdown/JSON reports, and reproducible artifact bundles.
- **Headless CI smoke:** exercise the headless benchmark runner in GitHub Actions for release confidence.

## Quick start

Install Flutter for your desktop platform, then run:

```sh
cd app
flutter pub get
flutter run -d linux
```

Use `windows` or `macos` instead of `linux` when running on those hosts.

## Provider setup

Open **Settings** in the app to configure model providers. Dart Arena currently supports:

- Ollama Local and Ollama Cloud
- OpenCode Go
- OpenAI
- OpenRouter
- DeepSeek
- Anthropic
- custom OpenAI-compatible local providers
- local Factory Droid execution

API keys and provider base URLs are stored through platform secure storage. Do not commit keys, exported credentials, local databases, or benchmark work directories.

## Running benchmarks

1. Configure at least one provider in **Settings**.
2. Select **New Run**.
3. Choose tasks, providers, models, evaluator settings, concurrency, and trial count.
4. Start the run and monitor progress.
5. Review the leaderboard, inspect task-run details, export run bundles, or compare outputs in the review queue.

## Official Bubblewrap run and website publishing

Use this flow when you want to run the private official agentic corpus, publish the result to the static Pickforge/Dart Arena web leaderboard, and keep the evidence reproducible.

Prerequisites:

- `bwrap` is installed and available on `PATH`.
- Flutter, Dart, and Bun are installed.
- Factory Droid can run the custom model from `~/.factory/settings.json`.
- The default model id is `custom:gpt-5.3-codex-spark---Codex`, which maps to **GPT 5.3 Codex Spark - Codex** in the local Factory settings.
- The git worktree is clean before the benchmark run. Release reports intentionally mark dirty-worktree runs as non-release evidence.

Run the official Bubblewrap benchmark:

```sh
RUN_ID=spark-sandboxed-official-$(date -u +%Y%m%dT%H%M%SZ) \
  bash scripts/run-official-bubblewrap-benchmark.sh
```

The script writes `.factory/$RUN_ID/run.json`, runs `dart_arena_headless`, enables `requireGeneratedCodeSandbox`, uses Bubblewrap for generated code, runs the five active official Flutter tasks, and stores the run database plus artifact bundle under `.factory/$RUN_ID/`.

Useful overrides:

```sh
TRIALS_PER_TASK=3 MAX_CONCURRENCY=1 TIMEOUT_SECONDS=7200 \
  RUN_ID=spark-sandboxed-official-20260606T120000Z \
  bash scripts/run-official-bubblewrap-benchmark.sh
```

Publish a completed run to the static website data:

```sh
bash scripts/publish-benchmark-to-web.sh .factory/<run-id>
```

That command:

- exports `web/static/data/leaderboard.v1.json` with `--strategy aggregate-compatible`;
- exports `web/static/data/release_report.v1.json` as a provenance sidecar;
- validates the Svelte static site with `bun run web:check` and `bun run web:smoke`.

To publish and push in one command after reviewing the run id:

```sh
COMMIT=1 PUSH=1 \
  COMMIT_MESSAGE="data: publish spark benchmark results" \
  bash scripts/publish-benchmark-to-web.sh .factory/<run-id>
```

The script stages only the generated static data files. It does not stage local databases, workdirs, screenshots, credentials, or `.factory/` contents.

Manual equivalent:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_export_leaderboard \
  --database ../.factory/<run-id>/dart_arena.sqlite \
  --out ../web/static/data/leaderboard.v1.json \
  --track agentic \
  --strategy aggregate-compatible \
  --run-id <run-id>

dart run --verbosity=error dart_arena:dart_arena_release_report \
  --leaderboard ../web/static/data/leaderboard.v1.json \
  --database ../.factory/<run-id>/dart_arena.sqlite \
  --artifact-bundle-root ../.factory/<run-id>/bundles/dart_arena_run_<run-id> \
  --task-qa-report-root ../tasks/flutter \
  --release-id <run-id> \
  --out ../web/static/data/release_report.v1.json

cd ..
bun run web:check
bun run web:smoke
git add web/static/data/leaderboard.v1.json web/static/data/release_report.v1.json
git commit -m "data: publish benchmark results"
git push origin main
```

`web/static/data/leaderboard.v1.json` is the file consumed by the public Svelte site. `web/static/data/release_report.v1.json` is published for auditability, but the current site UI does not require it to render the leaderboard.

Deploying the website:

- If Vercel, Netlify, or another static host is connected to `main`, pushing the data commit is enough for the host to rebuild.
- Otherwise, run `bun run web:smoke` and deploy the generated `web/build/` directory.
- For a non-root path such as GitHub Pages at `/dart_arena`, build with `PUBLIC_BASE_PATH=/dart_arena bun run web:smoke` and deploy `web/build/`.

## Validation

Use these commands before submitting changes:

```sh
cd app
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --debug
```

The CI smoke workflow also runs:

```sh
cd app
flutter test test/headless/headless_benchmark_runner_test.dart
```

## Desktop builds

Build debug desktop artifacts from the matching host OS:

```sh
cd app
flutter build linux --debug
flutter build windows --debug
flutter build macos --debug
```

Cross-building Windows or macOS from Linux is not supported by Flutter, so run those commands on native hosts.

## Privacy and security

- Provider credentials stay in platform secure storage.
- Benchmark tasks and generated work directories may contain model output and code diffs; inspect exported bundles before sharing them.
- Hidden verifier fixtures are part of the local benchmark corpus and should not be exposed to model prompts during a run.
- The app does not require committing local databases, caches, generated build outputs, or exported benchmark artifacts.

## Contributing

Contributions should keep the package/import name as `dart_arena`, preserve benchmark reproducibility, and include tests for scoring, task fixtures, or UI behavior when changed.

Before opening a pull request:

```sh
cd app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## License

Dart Arena is released under the MIT License. See [LICENSE](LICENSE).

---

<p align="center">
  <img src="app/assets/branding/pickforge_logo.png" alt="Pickforge" width="160">
</p>
