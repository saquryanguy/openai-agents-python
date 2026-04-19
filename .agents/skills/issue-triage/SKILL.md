# Issue Triage Skill

Automatically triages new GitHub issues by analyzing content, applying labels, assigning priority, and routing to appropriate team members.

## What This Skill Does

- Reads newly opened or updated GitHub issues
- Classifies issues by type (bug, feature request, question, documentation)
- Applies appropriate labels based on content analysis
- Assigns priority labels (P0-P3) based on severity indicators
- Identifies affected components (e.g., tracing, tools, models, streaming)
- Posts a structured triage comment summarizing findings
- Requests additional information when issue is incomplete

## Triggers

- New issue opened
- Issue reopened
- Manual trigger via workflow dispatch

## Inputs

| Input | Description |
|-------|-------------|
| `issue_number` | GitHub issue number to triage |
| `repo` | Repository in `owner/repo` format |

## Outputs

- Labels applied to the issue
- Triage comment posted on the issue
- Summary written to `triage_result.md`

## Labels Applied

### Type Labels
- `bug` — Something is broken or not working as expected
- `enhancement` — New feature or improvement request
- `question` — General question or usage help
- `documentation` — Docs missing, incorrect, or unclear
- `performance` — Performance-related concern

### Priority Labels
- `P0` — Critical: data loss, security issue, complete breakage
- `P1` — High: major feature broken, significant user impact
- `P2` — Medium: partial breakage, workaround available
- `P3` — Low: minor issue, cosmetic, or nice-to-have

### Component Labels
- `component:tracing`
- `component:tools`
- `component:models`
- `component:streaming`
- `component:memory`
- `component:handoffs`

## Configuration

Set the following environment variables or GitHub Actions secrets:

```
GITHUB_TOKEN   — Token with issues read/write permission
OPENAI_API_KEY — API key for issue content analysis
```

## Example Usage

```yaml
- uses: .agents/skills/issue-triage
  with:
    issue_number: ${{ github.event.issue.number }}
    repo: ${{ github.repository }}
```
