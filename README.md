<p align="center">
  <img src="app/assets/branding/pickarena-lockup-horizontal.svg" alt="PickArena" width="560">
</p>

# PickArena

PickArena is a CLI benchmark runner for AI coding models on Dart and Flutter task corpora. It runs codegen and agentic benchmarks, records reproducible evidence, exports leaderboard data, and publishes the static web leaderboard. There is no desktop app.

## What it does

- Runs codegen and agentic task matrices with repeated trials.
- Validates task bundles and hidden verifiers.
- Stores provenance, run results, artifact bundles, and CSV/Markdown/JSON exports.
- Publishes static leaderboard and release-report data for the Svelte website.

## Quickstart

Install Dart and a system SQLite runtime. Install Flutter too when running Flutter task bundles; PickArena itself is a pure Dart package.

```sh
cd app
dart pub get

dart run --verbosity=error dart_arena:dart_arena_headless --help
dart run --verbosity=error dart_arena:dart_arena_task_qa --help
dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --help
```

Run a benchmark with a JSON config:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_headless --config run.json
```

The config supplies task bundle roots, providers, models, evaluator settings, concurrency, trials, output paths, and timeouts. See the official script below for a complete agentic example.

## Task QA and exports

Use the task-QA CLI before admitting task changes, then export completed run data:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_task_qa --help
dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --help
dart run --verbosity=error dart_arena:dart_arena_release_report --help
```

Task authoring references live in [tasks/README.md](tasks/README.md) and [tasks/AUTHORING.md](tasks/AUTHORING.md).

## Official Bubblewrap run and web publishing

The official corpus flow needs Bubblewrap, Flutter for the Flutter task corpus, Dart, Bun, and Factory Droid.

```sh
RUN_ID=spark-sandboxed-official-$(date -u +%Y%m%dT%H%M%SZ) \
  bash scripts/run-official-bubblewrap-benchmark.sh

bash scripts/publish-benchmark-to-web.sh .factory/<run-id>
```

The publish command writes `web/static/data/leaderboard.v1.json` and `web/static/data/release_report.v1.json`, then validates the Svelte site. Use `COMMIT=1 PUSH=1` only after reviewing the generated data.

## Development

```sh
cd app
dart pub get
dart format --set-exit-if-changed lib test
dart analyze
dart test
```

The CLI needs only Dart and a system SQLite. The full test suite also needs Flutter installed: it compiles the Flutter task corpus fixtures.

```sh
cd ../web
bun install --frozen-lockfile
bun run check
bun run smoke
```

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <a href="https://pickforge.dev">
    <img src="app/assets/branding/pickforge-studio-footer.svg" alt="Pickforge Studio — local-first, open source, built for people who ship" width="560">
  </a>
</p>
