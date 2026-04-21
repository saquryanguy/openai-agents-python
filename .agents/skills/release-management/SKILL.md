# Release Management Skill

## Overview
Automates the release process for the openai-agents-python package, including version bumping, changelog finalization, PyPI publishing preparation, and GitHub release creation.

## Trigger
This skill is triggered when:
- A maintainer comments `/release <version>` on a pull request or issue
- A scheduled release workflow runs
- Manually invoked with a target version

## What This Skill Does

### 1. Version Validation
- Validates the requested version follows semantic versioning (MAJOR.MINOR.PATCH)
- Checks that the version is greater than the current published version
- Ensures no existing git tag conflicts

### 2. Version Bumping
- Updates `pyproject.toml` with the new version
- Updates `src/agents/__init__.py` version constant if present
- Creates a version bump commit

### 3. Changelog Finalization
- Moves entries from `[Unreleased]` to the new version section in `CHANGELOG.md`
- Adds release date to the version header
- Ensures changelog follows Keep a Changelog format

### 4. Release Artifact Preparation
- Runs `python -m build` to generate wheel and sdist
- Validates package metadata with `twine check`
- Generates SHA256 checksums for artifacts

### 5. GitHub Release
- Creates a git tag `v<version>`
- Drafts a GitHub release with changelog notes
- Attaches build artifacts to the release

### 6. Post-Release
- Opens a follow-up PR to bump to the next dev version
- Posts a summary comment with release details and PyPI upload instructions

## Inputs
| Parameter | Required | Description |
|-----------|----------|-------------|
| `version` | Yes | Target release version (e.g., `1.2.0`) |
| `dry_run` | No | If `true`, performs all checks without making changes (default: `false`) |
| `skip_build` | No | If `true`, skips artifact building (default: `false`) |

## Outputs
- Updated `pyproject.toml` with new version
- Finalized `CHANGELOG.md`
- Build artifacts in `dist/`
- Git tag pushed to remote
- GitHub draft release created

## Error Handling
- If version validation fails, the skill exits with a clear error message
- If the build fails, no git changes are committed
- All steps are logged for debugging

## Example Usage
```
/release 0.2.0
/release 0.2.0 dry_run=true
```

## Dependencies
- `python >= 3.9`
- `build` package (`pip install build`)
- `twine` package (`pip install twine`)
- `gh` CLI (GitHub CLI) for release creation
- `git` with push access to the repository
