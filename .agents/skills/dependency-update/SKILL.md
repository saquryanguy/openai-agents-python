# Dependency Update Skill

This skill automates the process of checking for outdated dependencies and creating pull requests to update them.

## What it does

1. Scans `pyproject.toml` and `requirements*.txt` files for dependencies
2. Checks for newer versions available on PyPI
3. Runs the test suite to verify compatibility
4. Creates a structured report of available updates
5. Optionally opens a PR with the proposed changes

## When to use

- Scheduled dependency maintenance (weekly/monthly)
- Security vulnerability response
- Before major releases to ensure up-to-date dependencies
- After a long development freeze

## Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `update_type` | No | `minor` | One of `patch`, `minor`, `major` — controls how aggressively to update |
| `dry_run` | No | `true` | If `true`, only report updates without applying them |
| `create_pr` | No | `false` | If `true`, open a GitHub PR with the changes |
| `exclude` | No | `""` | Comma-separated list of packages to skip |

## Outputs

- A markdown report listing current vs. latest versions
- Modified `pyproject.toml` / `requirements*.txt` (when `dry_run=false`)
- A GitHub PR (when `create_pr=true`)

## Usage

```yaml
- skill: dependency-update
  inputs:
    update_type: minor
    dry_run: false
    create_pr: true
    exclude: "numpy,torch"
```

## Notes

- The skill respects version constraints already specified in `pyproject.toml`.
- Major updates are flagged with a ⚠️ warning and require explicit `update_type: major`.
- Test failures block automatic updates; the report will note which packages caused failures.
- Uses `pip index versions` and the PyPI JSON API for version lookups.
