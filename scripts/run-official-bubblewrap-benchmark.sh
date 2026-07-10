#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Run the official local agentic benchmark with Bubblewrap sandboxing.

Usage:
  bash scripts/run-official-bubblewrap-benchmark.sh

Environment overrides:
  RUN_ID             Run id and .factory subdirectory name.
  RUN_DIR            Output directory. Defaults to .factory/$RUN_ID.
  MODEL_ID           Droid model id. Defaults to the custom Spark model.
  TRIALS_PER_TASK    Defaults to 2.
  MAX_CONCURRENCY    Defaults to 1.
  TIMEOUT_SECONDS    Defaults to 7200.
  ALLOW_DIRTY_GIT=1  Allow scratch runs from a dirty worktree.
  FORCE=1            Replace an existing run.json in the run directory.

Default model:
  custom:gpt-5.3-codex-spark---Codex
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if ! command -v bwrap >/dev/null 2>&1; then
  echo "Bubblewrap is required but bwrap was not found on PATH." >&2
  exit 1
fi

if [[ "${ALLOW_DIRTY_GIT:-0}" != "1" ]]; then
  dirty_status="$(git -C "$repo_root" status --porcelain)"
  if [[ -n "$dirty_status" ]]; then
    echo "Refusing release-grade run from a dirty worktree." >&2
    echo "Commit/stash/remove local changes first, or set ALLOW_DIRTY_GIT=1 for scratch evidence." >&2
    echo "$dirty_status" >&2
    exit 1
  fi
fi

run_id="${RUN_ID:-spark-sandboxed-official-$(date -u +%Y%m%dT%H%M%SZ)}"
run_dir="${RUN_DIR:-$repo_root/.factory/$run_id}"
model_id="${MODEL_ID:-custom:gpt-5.3-codex-spark---Codex}"
trials_per_task="${TRIALS_PER_TASK:-2}"
max_concurrency="${MAX_CONCURRENCY:-1}"
timeout_seconds="${TIMEOUT_SECONDS:-7200}"
run_json="$run_dir/run.json"

if [[ -e "$run_json" && "${FORCE:-0}" != "1" ]]; then
  echo "Refusing to overwrite existing config: $run_json" >&2
  echo "Set FORCE=1 to replace it." >&2
  exit 1
fi

mkdir -p "$run_dir"

bash "$script_dir/warm-flutter-task-pub-cache.sh"

cat >"$run_json" <<JSON
{
  "runId": "$run_id",
  "name": "Spark sandboxed official repeated validation",
  "preset": "mvp",
  "taskBundleRoots": ["../../tasks/flutter"],
  "providers": [
    {
      "type": "droid",
      "models": ["$model_id"]
    }
  ],
  "evaluatorWeights": {
    "compile": 1.0,
    "analyze": 1.0,
    "test": 1.0,
    "diff_size": 0.2
  },
  "requireGeneratedCodeSandbox": true,
  "trialsPerTask": $trials_per_task,
  "maxConcurrency": $max_concurrency,
  "outputDir": "bundles",
  "databasePath": "dart_arena.sqlite",
  "workdirRoot": "workdirs",
  "timeoutSeconds": $timeout_seconds
}
JSON

echo "Wrote $run_json"
echo "Running official Bubblewrap benchmark..."

(
  cd "$repo_root/app"
  dart run --verbosity=error dart_arena:dart_arena_headless --config "$run_json"
)

echo "Benchmark run directory:"
echo "$run_dir"
