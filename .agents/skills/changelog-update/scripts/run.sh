#!/usr/bin/env bash
# Changelog Update Skill
# Automatically updates CHANGELOG.md based on merged PRs and commits
# since the last release tag.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
GITHUB_REPO="${GITHUB_REPO:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
DRY_RUN="${DRY_RUN:-false}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[changelog-update] $*"; }
err()  { echo "[changelog-update] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

require_cmd git
require_cmd sed
require_cmd awk

# ---------------------------------------------------------------------------
# Determine the last release tag
# ---------------------------------------------------------------------------
get_last_tag() {
  git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
}

LAST_TAG=$(get_last_tag)
if [[ -z "$LAST_TAG" ]]; then
  log "No previous release tag found; collecting all commits."
  COMMIT_RANGE="HEAD"
else
  log "Last release tag: $LAST_TAG"
  COMMIT_RANGE="${LAST_TAG}..HEAD"
fi

# ---------------------------------------------------------------------------
# Collect commits since last tag
# ---------------------------------------------------------------------------
# Format: <short-hash> <subject>
mapfile -t COMMITS < <(git log "$COMMIT_RANGE" --pretty=format:"%h %s" --no-merges 2>/dev/null || true)

if [[ ${#COMMITS[@]} -eq 0 ]]; then
  log "No new commits since $LAST_TAG — nothing to update."
  exit 0
fi

log "Found ${#COMMITS[@]} commit(s) to process."

# ---------------------------------------------------------------------------
# Categorise commits by conventional-commit prefix
# ---------------------------------------------------------------------------
declare -a FEAT_LINES BUG_LINES CHORE_LINES BREAK_LINES OTHER_LINES

for entry in "${COMMITS[@]}"; do
  hash="${entry%% *}"
  subject="${entry#* }"

  case "$subject" in
    feat!:*|fix!:*|refactor!:*)  BREAK_LINES+=("- ${subject} (${hash})") ;;
    feat:*)                       FEAT_LINES+=("- ${subject#feat: } (${hash})") ;;
    fix:*)                        BUG_LINES+=("- ${subject#fix: } (${hash})") ;;
    chore:*|ci:*|build:*|docs:*)  CHORE_LINES+=("- ${subject} (${hash})") ;;
    *)                            OTHER_LINES+=("- ${subject} (${hash})") ;;
  esac
done

# ---------------------------------------------------------------------------
# Build the new changelog section
# ---------------------------------------------------------------------------
TODAY=$(date +%Y-%m-%d)
NEW_VERSION="${NEW_VERSION:-Unreleased}"

build_section() {
  local header="$1"
  shift
  local -a lines=("$@")
  if [[ ${#lines[@]} -gt 0 ]]; then
    echo "### $header"
    for l in "${lines[@]}"; do echo "$l"; done
    echo
  fi
}

NEW_SECTION="## [$NEW_VERSION] - $TODAY\n"
if [[ ${#BREAK_LINES[@]} -gt 0 ]]; then
  NEW_SECTION+="$(build_section '⚠ Breaking Changes' "${BREAK_LINES[@]}")"
fi
if [[ ${#FEAT_LINES[@]} -gt 0 ]]; then
  NEW_SECTION+="$(build_section 'Features' "${FEAT_LINES[@]}")"
fi
if [[ ${#BUG_LINES[@]} -gt 0 ]]; then
  NEW_SECTION+="$(build_section 'Bug Fixes' "${BUG_LINES[@]}")"
fi
if [[ ${#CHORE_LINES[@]} -gt 0 ]]; then
  NEW_SECTION+="$(build_section 'Chores' "${CHORE_LINES[@]}")"
fi
if [[ ${#OTHER_LINES[@]} -gt 0 ]]; then
  NEW_SECTION+="$(build_section 'Other Changes' "${OTHER_LINES[@]}")"
fi

# ---------------------------------------------------------------------------
# Inject into CHANGELOG.md
# ---------------------------------------------------------------------------
if [[ ! -f "$CHANGELOG_FILE" ]]; then
  log "$CHANGELOG_FILE not found — creating a new one."
  printf '# Changelog\n\nAll notable changes to this project will be documented here.\n\n' > "$CHANGELOG_FILE"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry-run mode — proposed changelog section:"
  echo -e "$NEW_SECTION"
  exit 0
fi

# Insert after the first '# Changelog' heading
TMP_FILE=$(mktemp)
awk -v new_section="$NEW_SECTION" '
  /^# Changelog/ && !inserted {
    print
    print ""
    printf "%s", new_section
    inserted=1
    next
  }
  { print }
' "$CHANGELOG_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$CHANGELOG_FILE"
log "$CHANGELOG_FILE updated successfully."

# ---------------------------------------------------------------------------
# Commit the updated changelog (optional)
# ---------------------------------------------------------------------------
if git diff --quiet "$CHANGELOG_FILE"; then
  log "No effective changes to commit."
else
  git add "$CHANGELOG_FILE"
  git commit -m "chore: update changelog for $NEW_VERSION"
  log "Changelog committed."
fi
