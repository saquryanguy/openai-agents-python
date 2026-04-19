# PR Review Skill

Automatically reviews pull requests for code quality, consistency, and potential issues.

## What This Skill Does

- Analyzes changed files in a pull request
- Checks for code style and formatting issues
- Identifies potential bugs or anti-patterns
- Verifies test coverage for new code
- Ensures documentation is updated alongside code changes
- Posts a structured review comment summarizing findings

## Trigger

This skill runs automatically when a pull request is opened or updated.

## Inputs

| Input | Description |
|-------|-------------|
| `PR_NUMBER` | The pull request number to review |
| `GITHUB_TOKEN` | Token with read access to the repository |
| `REPO` | Repository in `owner/repo` format |

## Outputs

Posts a review comment to the pull request with:
- Summary of changes
- List of issues found (errors, warnings, suggestions)
- Checklist of quality gates (tests, docs, formatting)

## Configuration

Set the following environment variables to customize behavior:

```bash
# Minimum test coverage threshold (default: 80)
MIN_COVERAGE=80

# Whether to block merge on errors (default: true)
BLOCK_ON_ERROR=true

# Comma-separated list of file patterns to ignore
IGNORE_PATTERNS="*.md,*.txt"
```

## Example Review Output

```
## Agent PR Review

### Summary
3 files changed, 120 insertions, 45 deletions

### Issues Found
- ⚠️  `src/agents/runner.py:42` — Missing type annotation on return value
- 💡  `tests/test_runner.py` — Consider adding edge case for empty input

### Quality Gates
- [x] Tests present
- [x] Docs updated
- [ ] All functions typed
```

## Notes

- The skill uses static analysis and does not execute code
- Review comments are updated (not duplicated) on re-runs
