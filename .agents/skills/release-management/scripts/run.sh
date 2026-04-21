#!/usr/bin/env bash
# Release Management Skill Script
# Automates the release process: version bumping, changelog generation,
# tagging, and publishing for openai-agents-python.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(git rev-parse --show-toplevel)"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
PYPROJECT_FILE="${REPO_ROOT}/pyproject.toml"
DRY_RUN="${DRY_RUN:-false}"
RELEASE_TYPE="${RELEASE_TYPE:-patch}"  # major | minor | patch

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[release] $*"; }
die()  { echo "[release] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
require_cmd git
require_cmd python3
require_cmd sed

# Ensure we are on the main branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
  die "Releases must be cut from 'main'. Current branch: ${CURRENT_BRANCH}"
fi

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  die "Working tree is dirty. Commit or stash changes before releasing."
fi

# ---------------------------------------------------------------------------
# Determine current version from pyproject.toml
# ---------------------------------------------------------------------------
get_current_version() {
  grep -E '^version\s*=' "${PYPROJECT_FILE}" \
    | head -1 \
    | sed 's/version\s*=\s*"//;s/"//'
}

# Bump semver component
bump_version() {
  local current="$1"
  local type="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "${current}"
  case "${type}" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) die "Unknown release type: ${type}" ;;
  esac
  echo "${major}.${minor}.${patch}"
}

CURRENT_VERSION="$(get_current_version)"
[[ -z "${CURRENT_VERSION}" ]] && die "Could not determine current version from ${PYPROJECT_FILE}"

NEW_VERSION="$(bump_version "${CURRENT_VERSION}" "${RELEASE_TYPE}")"
TAG_NAME="v${NEW_VERSION}"

log "Current version : ${CURRENT_VERSION}"
log "Release type    : ${RELEASE_TYPE}"
log "New version     : ${NEW_VERSION}"
log "Tag             : ${TAG_NAME}"
log "Dry run         : ${DRY_RUN}"

# ---------------------------------------------------------------------------
# Update pyproject.toml
# ---------------------------------------------------------------------------
update_pyproject() {
  log "Updating version in pyproject.toml ..."
  sed -i "s/^version = \"${CURRENT_VERSION}\"/version = \"${NEW_VERSION}\"/" \
    "${PYPROJECT_FILE}"
}

# ---------------------------------------------------------------------------
# Prepend a release section to CHANGELOG.md
# ---------------------------------------------------------------------------
update_changelog() {
  log "Updating CHANGELOG.md ..."
  local today
  today="$(date +%Y-%m-%d)"
  local header="## [${NEW_VERSION}] - ${today}"

  # Collect commits since last tag
  local last_tag
  last_tag="$(git describe --tags --abbrev=0 2>/dev/null || echo '')"
  local git_log
  if [[ -n "${last_tag}" ]]; then
    git_log="$(git log "${last_tag}"..HEAD --oneline --no-merges)"
  else
    git_log="$(git log --oneline --no-merges)"
  fi

  local entry
  entry="$(printf '%s\n\n### Changes\n\n%s\n\n' "${header}" "${git_log}")"

  # Prepend entry after the first line (title) of the changelog
  local tmp
  tmp="$(mktemp)"
  {
    head -1 "${CHANGELOG_FILE}"
    echo ""
    echo "${entry}"
    tail -n +2 "${CHANGELOG_FILE}"
  } > "${tmp}"
  mv "${tmp}" "${CHANGELOG_FILE}"
}

# ---------------------------------------------------------------------------
# Commit, tag, and (optionally) push
# ---------------------------------------------------------------------------
commit_and_tag() {
  log "Committing release changes ..."
  git add "${PYPROJECT_FILE}" "${CHANGELOG_FILE}"
  git commit -m "chore: release ${TAG_NAME}"
  git tag -a "${TAG_NAME}" -m "Release ${TAG_NAME}"
  log "Created commit and tag ${TAG_NAME}"
}

push_release() {
  log "Pushing branch and tag to origin ..."
  git push origin main
  git push origin "${TAG_NAME}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ "${DRY_RUN}" == "true" ]]; then
  log "[DRY RUN] Would bump version ${CURRENT_VERSION} -> ${NEW_VERSION}"
  log "[DRY RUN] Would create tag ${TAG_NAME}"
  log "[DRY RUN] No files modified, no commits created."
  exit 0
fi

update_pyproject
update_changelog
commit_and_tag
push_release

log "Release ${TAG_NAME} completed successfully."
