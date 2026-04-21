#!/usr/bin/env bash
# PR Review Skill - Automated pull request review script
# Analyzes code changes, checks for common issues, and posts review comments

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Required environment variables
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

GITHUB_API="https://api.github.com"
REPO="$GITHUB_REPOSITORY"

# ─── Helpers ─────────────────────────────────────────────────────────────────
log()  { echo "[pr-review] $*" >&2; }
fail() { echo "[pr-review] ERROR: $*" >&2; exit 1; }

github_get() {
  local endpoint="$1"
  curl -fsSL \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${GITHUB_API}${endpoint}"
}

github_post() {
  local endpoint="$1"
  local body="$2"
  curl -fsSL -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${GITHUB_API}${endpoint}"
}

# ─── Fetch PR metadata ────────────────────────────────────────────────────────
log "Fetching PR #${PR_NUMBER} metadata from ${REPO}..."
PR_DATA=$(github_get "/repos/${REPO}/pulls/${PR_NUMBER}")

PR_TITLE=$(echo "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
PR_BODY=$(echo  "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('body') or '')")
BASE_SHA=$(echo "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['base']['sha'])")
HEAD_SHA=$(echo "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['head']['sha'])")
AUTHOR=$(echo   "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['user']['login'])")

log "PR title : $PR_TITLE"
log "Author   : $AUTHOR"
log "Base SHA : $BASE_SHA"
log "Head SHA : $HEAD_SHA"

# ─── Fetch changed files ──────────────────────────────────────────────────────
log "Fetching list of changed files..."
FILES_DATA=$(github_get "/repos/${REPO}/pulls/${PR_NUMBER}/files?per_page=100")

CHANGED_FILES=$(echo "$FILES_DATA" | python3 -c "
import sys, json
files = json.load(sys.stdin)
for f in files:
    print(f['filename'])
")

log "Changed files:"
echo "$CHANGED_FILES" | while read -r f; do log "  - $f"; done

# ─── Static checks ────────────────────────────────────────────────────────────
ISSUES=()

# Check: PR description is not empty
if [[ -z "$(echo "$PR_BODY" | tr -d '[:space:]')" ]]; then
  ISSUES+=("PR description is empty. Please describe the changes and motivation.")
fi

# Check: no direct commits to main/master
TARGET_BRANCH=$(echo "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['base']['ref'])")
if [[ "$TARGET_BRANCH" == "main" || "$TARGET_BRANCH" == "master" ]]; then
  log "Target branch is ${TARGET_BRANCH} — protected branch checks apply."
fi

# Check: large diff warning (>500 additions)
ADDITIONS=$(echo "$PR_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin).get('additions', 0))")
if (( ADDITIONS > 500 )); then
  ISSUES+=("This PR adds ${ADDITIONS} lines. Consider breaking it into smaller, focused PRs for easier review.")
fi

# Check: test files present when source files change
HAS_SRC=$(echo "$CHANGED_FILES" | grep -E '^src/' | head -1 || true)
HAS_TEST=$(echo "$CHANGED_FILES" | grep -E '(test_|_test\.py|tests/)' | head -1 || true)
if [[ -n "$HAS_SRC" && -z "$HAS_TEST" ]]; then
  ISSUES+=("Source files were modified but no test files were found in the diff. Please add or update tests.")
fi

# Check: changelog / release notes updated for non-trivial PRs
HAS_CHANGELOG=$(echo "$CHANGED_FILES" | grep -iE '(CHANGELOG|CHANGES|HISTORY|RELEASE)' | head -1 || true)
if (( ADDITIONS > 100 )) && [[ -z "$HAS_CHANGELOG" ]]; then
  ISSUES+=("Consider updating CHANGELOG.md or release notes to document this change.")
fi

# ─── Build review comment body ────────────────────────────────────────────────
build_review_body() {
  local status="$1"
  local body
  body="## Automated PR Review\n\n"
  body+="**Status:** ${status}\n\n"

  if (( ${#ISSUES[@]} > 0 )); then
    body+="### ⚠️ Issues Found\n\n"
    for issue in "${ISSUES[@]}"; do
      body+="- ${issue}\n"
    done
    body+="\n"
  else
    body+="### ✅ No Issues Found\n\nAll automated checks passed.\n\n"
  fi

  body+="### 📋 Summary\n\n"
  body+="| Metric | Value |\n"
  body+="|--------|-------|\n"
  body+="| Changed files | $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') |\n"
  body+="| Additions | ${ADDITIONS} |\n"
  body+="| Target branch | ${TARGET_BRANCH} |\n"
  body+="\n_Review generated automatically by the pr-review skill._"
  echo -e "$body"
}

# ─── Post review ──────────────────────────────────────────────────────────────
if (( ${#ISSUES[@]} > 0 )); then
  REVIEW_EVENT="REQUEST_CHANGES"
  STATUS_LABEL="❌ Changes Requested"
  log "Issues found (${#ISSUES[@]}). Requesting changes."
else
  REVIEW_EVENT="COMMENT"
  STATUS_LABEL="✅ Looks Good"
  log "No issues found. Posting approval comment."
fi

REVIEW_BODY=$(build_review_body "$STATUS_LABEL")

PAYLOAD=$(python3 -c "
import json, sys
body = sys.stdin.read()
print(json.dumps({'commit_id': '${HEAD_SHA}', 'body': body, 'event': '${REVIEW_EVENT}'}))
" <<< "$REVIEW_BODY")

log "Submitting review to PR #${PR_NUMBER}..."
github_post "/repos/${REPO}/pulls/${PR_NUMBER}/reviews" "$PAYLOAD" > /dev/null

log "Review submitted successfully."
