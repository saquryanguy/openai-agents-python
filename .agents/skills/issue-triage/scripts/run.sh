#!/bin/bash
# Issue Triage Skill - Automatically triages new GitHub issues
# by analyzing content, applying labels, and suggesting assignees.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"          # e.g. owner/repo
ISSUE_NUMBER="${ISSUE_NUMBER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"
MODEL="${MODEL:-gpt-4o-mini}"

# ── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$REPO" ]]; then
  echo "ERROR: REPO (or GITHUB_REPOSITORY) must be set." >&2
  exit 1
fi

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "ERROR: ISSUE_NUMBER must be set." >&2
  exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "ERROR: GITHUB_TOKEN must be set." >&2
  exit 1
fi

if [[ -z "$OPENAI_API_KEY" ]]; then
  echo "ERROR: OPENAI_API_KEY must be set." >&2
  exit 1
fi

GH_API="https://api.github.com/repos/${REPO}"
AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"

# ── Fetch issue details ───────────────────────────────────────────────────────
echo "Fetching issue #${ISSUE_NUMBER} from ${REPO}..."
ISSUE_JSON=$(curl -sSf -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
  "${GH_API}/issues/${ISSUE_NUMBER}")

ISSUE_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'])")
ISSUE_BODY=$(echo "$ISSUE_JSON"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body') or '')")
ISSUE_AUTHOR=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['user']['login'])")

echo "Title  : $ISSUE_TITLE"
echo "Author : $ISSUE_AUTHOR"

# ── Fetch available labels ────────────────────────────────────────────────────
AVAILABLE_LABELS=$(curl -sSf -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
  "${GH_API}/labels?per_page=100" \
  | python3 -c "import sys,json; print(', '.join(l['name'] for l in json.load(sys.stdin)))")

echo "Available labels: $AVAILABLE_LABELS"

# ── Ask OpenAI to triage the issue ───────────────────────────────────────────
SYSTEM_PROMPT="You are an expert open-source maintainer triaging GitHub issues for the openai-agents-python SDK.
Given an issue title and body, respond with a JSON object containing:
  \"labels\": an array of label names (choose only from the available labels provided),
  \"priority\": one of \"critical\", \"high\", \"medium\", \"low\",
  \"type\": one of \"bug\", \"feature\", \"question\", \"docs\", \"chore\",
  \"summary\": a one-sentence summary of the issue,
  \"comment\": a friendly, concise triage comment to post on the issue (mention priority and next steps).
Respond ONLY with valid JSON — no markdown fences."

USER_PROMPT="Available labels: ${AVAILABLE_LABELS}

Issue title: ${ISSUE_TITLE}

Issue body:
${ISSUE_BODY}"

AI_RESPONSE=$(python3 - <<'PYEOF'
import os, json, urllib.request, urllib.error

system = os.environ["_SYSTEM_PROMPT"]
user   = os.environ["_USER_PROMPT"]
key    = os.environ["OPENAI_API_KEY"]
model  = os.environ["MODEL"]

payload = json.dumps({
    "model": model,
    "response_format": {"type": "json_object"},
    "messages": [
        {"role": "system", "content": system},
        {"role": "user",   "content": user},
    ],
}).encode()

req = urllib.request.Request(
    "https://api.openai.com/v1/chat/completions",
    data=payload,
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
)
try:
    with urllib.request.urlopen(req) as resp:
        data = json.load(resp)
    print(data["choices"][0]["message"]["content"])
except urllib.error.HTTPError as e:
    print(f"OpenAI API error {e.code}: {e.read().decode()}", file=__import__('sys').stderr)
    raise SystemExit(1)
PYEOF
)
export _SYSTEM_PROMPT="$SYSTEM_PROMPT"
export _USER_PROMPT="$USER_PROMPT"

echo "AI triage response: $AI_RESPONSE"

# ── Parse AI response ─────────────────────────────────────────────────────────
LABELS_JSON=$(echo "$AI_RESPONSE" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['labels']))")
TRIAGE_COMMENT=$(echo "$AI_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['comment'])")
PRIORITY=$(echo "$AI_RESPONSE"       | python3 -c "import sys,json; print(json.load(sys.stdin)['priority'])")

# ── Apply labels ──────────────────────────────────────────────────────────────
echo "Applying labels: $LABELS_JSON"
curl -sSf -X POST -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
  "${GH_API}/issues/${ISSUE_NUMBER}/labels" \
  -d "{\"labels\": ${LABELS_JSON}}" > /dev/null

# ── Post triage comment ───────────────────────────────────────────────────────
echo "Posting triage comment..."
COMMENT_BODY=$(python3 -c "import json, os; print(json.dumps({'body': os.environ['_COMMENT']}))")
export _COMMENT="$TRIAGE_COMMENT"
curl -sSf -X POST -H "$AUTH_HEADER" -H "Accept: application/vnd.github+json" \
  "${GH_API}/issues/${ISSUE_NUMBER}/comments" \
  -d "$COMMENT_BODY" > /dev/null

echo "✅ Issue #${ISSUE_NUMBER} triaged successfully (priority: ${PRIORITY})."
