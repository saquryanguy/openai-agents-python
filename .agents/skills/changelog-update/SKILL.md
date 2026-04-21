# Changelog Update Skill

Automatically generates and updates the CHANGELOG.md file based on merged pull requests, commits, and semantic versioning conventions.

## Overview

This skill analyzes recent commits and pull requests since the last release tag, groups changes by type (feat, fix, chore, docs, etc.), and produces a well-formatted changelog entry following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

## Trigger

This skill is triggered:
- When a new release is being prepared
- On a scheduled basis (e.g., weekly)
- Manually via workflow dispatch
- When a PR is merged into the main branch with a `changelog` label

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `version` | The version to generate changelog for (e.g., `1.2.0`) | No | Auto-detected from latest tag |
| `since_tag` | Generate changelog since this git tag | No | Latest release tag |
| `dry_run` | Preview changes without writing to file | No | `false` |

## Outputs

- Updated `CHANGELOG.md` with a new version section
- Summary of changes grouped by category
- PR/commit references with authors

## Change Categories

Changes are grouped into the following sections:

- **Added** — New features (`feat:` commits)
- **Changed** — Changes to existing functionality (`refactor:`, `perf:`)
- **Deprecated** — Soon-to-be removed features
- **Removed** — Removed features
- **Fixed** — Bug fixes (`fix:` commits)
- **Security** — Security vulnerability fixes
- **Documentation** — Docs-only changes (`docs:` commits)
- **Maintenance** — Chores, dependency updates (`chore:`, `build:`, `ci:`)

## Behavior

1. Identifies the latest git tag as the baseline
2. Fetches all commits and merged PRs since that tag
3. Parses conventional commit messages to categorize changes
4. Falls back to PR title parsing if commit message is not conventional
5. Generates a new changelog section with today's date
6. Prepends the new section to `CHANGELOG.md`
7. Creates a commit with the updated changelog

## Example Output

```markdown
## [1.2.0] - 2024-01-15

### Added
- Add streaming support for agent responses (#142) @alice
- Add tool call retry mechanism (#138) @bob

### Fixed
- Fix race condition in async agent runner (#145) @alice
- Fix token counting for multi-modal inputs (#141) @carol

### Maintenance
- Update openai dependency to 1.12.0 (#143) @dependabot
```

## Configuration

The skill reads optional configuration from `.agents/skills/changelog-update/config.yaml` if present.
