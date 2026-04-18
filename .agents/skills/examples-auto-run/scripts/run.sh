#!/bin/bash
# examples-auto-run skill script
# Automatically discovers and runs example files, reporting success/failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/examples"
RESULTS_DIR="$REPO_ROOT/.agents/results/examples-auto-run"
TIMEOUT=${EXAMPLE_TIMEOUT:-30}
FAILED=0
PASSED=0
SKIPPED=0

mkdir -p "$RESULTS_DIR"

log() {
  echo "[examples-auto-run] $*"
}

log "Starting examples auto-run from: $EXAMPLES_DIR"
log "Timeout per example: ${TIMEOUT}s"

if [ ! -d "$EXAMPLES_DIR" ]; then
  log "ERROR: Examples directory not found: $EXAMPLES_DIR"
  exit 1
fi

# Collect all example Python files
mapfile -t EXAMPLE_FILES < <(find "$EXAMPLES_DIR" -name "*.py" | sort)

if [ ${#EXAMPLE_FILES[@]} -eq 0 ]; then
  log "No example files found."
  exit 0
fi

log "Found ${#EXAMPLE_FILES[@]} example file(s)."

RESULT_FILE="$RESULTS_DIR/run_results.md"
{
  echo "# Examples Auto-Run Results"
  echo ""
  echo "| File | Status | Duration | Notes |"
  echo "|------|--------|----------|-------|"
} > "$RESULT_FILE"

for example in "${EXAMPLE_FILES[@]}"; do
  rel_path="${example#$REPO_ROOT/}"

  # Check for skip marker
  if grep -q '# agents:skip' "$example" 2>/dev/null; then
    log "SKIP: $rel_path (marked agents:skip)"
    echo "| $rel_path | ⏭ Skipped | - | Marked agents:skip |" >> "$RESULT_FILE"
    ((SKIPPED++)) || true
    continue
  fi

  log "RUN:  $rel_path"
  START_TIME=$(date +%s)

  set +e
  OUTPUT=$(cd "$REPO_ROOT" && timeout "$TIMEOUT" python "$example" 2>&1)
  EXIT_CODE=$?
  set -e

  END_TIME=$(date +%s)
  DURATION=$(( END_TIME - START_TIME ))s

  if [ $EXIT_CODE -eq 0 ]; then
    log "PASS: $rel_path (${DURATION})"
    echo "| $rel_path | ✅ Passed | $DURATION | |" >> "$RESULT_FILE"
    ((PASSED++)) || true
  elif [ $EXIT_CODE -eq 124 ]; then
    log "TIMEOUT: $rel_path"
    echo "| $rel_path | ⏱ Timeout | ${TIMEOUT}s | Exceeded timeout |" >> "$RESULT_FILE"
    ((FAILED++)) || true
  else
    FIRST_ERROR=$(echo "$OUTPUT" | tail -5 | head -1)
    log "FAIL: $rel_path (exit $EXIT_CODE) — $FIRST_ERROR"
    echo "| $rel_path | ❌ Failed | $DURATION | Exit $EXIT_CODE: $FIRST_ERROR |" >> "$RESULT_FILE"
    ((FAILED++)) || true
  fi
done

{
  echo ""
  echo "## Summary"
  echo ""
  echo "- ✅ Passed:  $PASSED"
  echo "- ❌ Failed:  $FAILED"
  echo "- ⏭ Skipped: $SKIPPED"
  echo "- Total:     ${#EXAMPLE_FILES[@]}"
} >> "$RESULT_FILE"

log "Done. Passed=$PASSED Failed=$FAILED Skipped=$SKIPPED"
log "Results written to: $RESULT_FILE"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
