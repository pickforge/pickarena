#!/bin/bash
# Regenerate all official admission reports with clean provenance.
#
# Rules this script exists to enforce:
# - Run from a CLEAN committed worktree (the admission gate rejects gitDirty).
# - Nothing may touch the worktree while QA runs (incremental copies would
#   dirty the tree and poison the remaining runs' provenance), so all QA runs
#   finish before any report is copied back.
# - The QA CLI exits 0 even when a task is rejected; parse the JSON status.
set -euo pipefail
cd "$(dirname "$0")/../app"

if [ -n "$(git status --porcelain)" ]; then
  echo "worktree is dirty; commit or stash first" >&2
  exit 1
fi

OUT=build/task_qa_regen
rm -rf "$OUT"
TASKS=$(ls -d ../tasks/flutter/*/ | xargs -n1 basename)
fail=0

for t in $TASKS; do
  echo "=== QA $t"
  qa_exit=0
  result=$(dart run --verbosity=error dart_arena:dart_arena_task_qa \
    --task-bundle-root ../tasks/flutter \
    --task "$t" \
    --require-generated-code-sandbox \
    --out "$OUT" | tail -1) || qa_exit=$?
  echo "$result"
  if [ "$qa_exit" -ne 0 ]; then
    echo "=== $t QA COMMAND FAILED (exit $qa_exit)" >&2
    fail=1
  fi
  if ! echo "$result" | grep -q '"rejectedTaskCount":0'; then
    echo "=== $t REJECTED" >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "one or more tasks rejected; reports NOT copied — inspect $OUT" >&2
  exit 1
fi

echo "=== copying reports"
for t in $TASKS; do
  report=$(ls -d "$OUT"/tasks/task_"${t}"_*/admission_report.json | head -1)
  cp "$report" "../tasks/flutter/$t/qa/admission_report.json"
done
echo "=== done; review git diff, then commit the reports"
