#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required to warm Flutter task dependencies." >&2
  exit 1
fi

scratch_root="$(mktemp -d "${TMPDIR:-/tmp}/pickarena-flutter-pub-cache.XXXXXX")"
cleanup() {
  rm -rf "$scratch_root"
}
trap cleanup EXIT

task_count=0
while IFS= read -r -d '' task_dir; do
  baseline_dir="$task_dir/baseline"
  if [[ ! -f "$baseline_dir/pubspec.yaml" ]]; then
    continue
  fi

  task_name="$(basename "$task_dir")"
  work_dir="$scratch_root/$task_name"
  mkdir -p "$work_dir"
  cp -R "$baseline_dir/." "$work_dir"
  echo "Warming Flutter task dependencies: $task_name"
  (
    cd "$work_dir"
    flutter pub get
  )
  task_count=$((task_count + 1))
done < <(find "$repo_root/tasks/flutter" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

if [[ "$task_count" -eq 0 ]]; then
  echo "No Flutter task baselines found." >&2
  exit 1
fi

echo "Warmed Flutter task dependencies for $task_count task bundles."
