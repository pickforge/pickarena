#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Publish a completed benchmark run into the static web data files.

Usage:
  bash scripts/publish-benchmark-to-web.sh <run-dir-or-run-id> [options]

Options:
  --skip-release-report    Only write web/static/data/leaderboard.v1.json.
  --skip-web-validation    Skip bun web:check and web:smoke.
  -h, --help               Show this help text.

Environment overrides:
  RUN_ID                   Override run id if the run directory name differs.
  LEADERBOARD_OUT          Defaults to web/static/data/leaderboard.v1.json.
  RELEASE_REPORT_OUT       Defaults to web/static/data/release_report.v1.json.
  TASK_QA_REPORT_ROOT      Defaults to tasks/flutter.
  COMMIT=1                 Commit the generated static data files.
  COMMIT_MESSAGE           Defaults to "data: publish benchmark results".
  PUSH=1                   Push the current branch after committing.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -eq 0 ]]; then
  usage
  [[ $# -eq 0 ]] && exit 2
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

run_ref="$1"
shift

write_release_report=1
validate_web=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-release-report)
      write_release_report=0
      ;;
    --skip-web-validation)
      validate_web=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ -d "$run_ref" ]]; then
  run_dir="$(cd "$run_ref" && pwd)"
elif [[ -d "$repo_root/.factory/$run_ref" ]]; then
  run_dir="$(cd "$repo_root/.factory/$run_ref" && pwd)"
else
  echo "Run directory not found: $run_ref" >&2
  echo "Pass either a path or a run id under .factory/." >&2
  exit 1
fi

run_json="$run_dir/run.json"
database_path="$run_dir/dart_arena.sqlite"

if [[ ! -f "$run_json" ]]; then
  echo "Missing run config: $run_json" >&2
  exit 1
fi

if [[ ! -f "$database_path" ]]; then
  echo "Missing run database: $database_path" >&2
  exit 1
fi

read_json_string() {
  local file="$1"
  local key="$2"

  if command -v jq >/dev/null 2>&1; then
    jq -r ".$key // empty" "$file"
  else
    sed -n "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n 1
  fi
}

run_id="${RUN_ID:-$(read_json_string "$run_json" runId)}"
if [[ -z "$run_id" ]]; then
  run_id="$(basename "$run_dir")"
fi

leaderboard_out="${LEADERBOARD_OUT:-$repo_root/web/static/data/leaderboard.v1.json}"
release_report_out="${RELEASE_REPORT_OUT:-$repo_root/web/static/data/release_report.v1.json}"
task_qa_report_root="${TASK_QA_REPORT_ROOT:-$repo_root/tasks/flutter}"
artifact_bundle_root="$run_dir/bundles/dart_arena_run_$run_id"

if [[ ! -d "$artifact_bundle_root" ]]; then
  echo "Missing artifact bundle root: $artifact_bundle_root" >&2
  exit 1
fi

echo "Exporting leaderboard for run $run_id"
(
  cd "$repo_root/app"
  dart run --verbosity=error dart_arena:dart_arena_export_leaderboard \
    --database "$database_path" \
    --out "$leaderboard_out" \
    --track agentic \
    --strategy aggregate-compatible \
    --run-id "$run_id"
)

published_files=("$leaderboard_out")

if [[ "$write_release_report" == "1" ]]; then
  echo "Exporting release report for run $run_id"
  (
    cd "$repo_root/app"
    dart run --verbosity=error dart_arena:dart_arena_release_report \
      --leaderboard "$leaderboard_out" \
      --database "$database_path" \
      --artifact-bundle-root "$artifact_bundle_root" \
      --task-qa-report-root "$task_qa_report_root" \
      --release-id "$run_id" \
      --out "$release_report_out"
  )
  published_files+=("$release_report_out")
fi

if [[ "$validate_web" == "1" ]]; then
  echo "Validating static web build"
  (
    cd "$repo_root"
    bun run web:check
    bun run web:smoke
  )
fi

if [[ "${COMMIT:-0}" == "1" ]]; then
  git -C "$repo_root" add -- "${published_files[@]}"
  if git -C "$repo_root" diff --cached --quiet; then
    echo "No static data changes to commit."
  else
    git -C "$repo_root" commit -m "${COMMIT_MESSAGE:-data: publish benchmark results}"
  fi
fi

if [[ "${PUSH:-0}" == "1" ]]; then
  branch="$(git -C "$repo_root" branch --show-current)"
  git -C "$repo_root" push origin "$branch"
fi

echo "Published static data:"
for file in "${published_files[@]}"; do
  echo "- ${file#$repo_root/}"
done
