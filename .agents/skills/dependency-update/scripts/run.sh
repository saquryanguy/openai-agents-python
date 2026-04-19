#!/usr/bin/env bash
set -euo pipefail

# Dependency Update Skill
# Checks for outdated dependencies and creates a summary of available updates.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
OUTPUT_FILE="${REPO_ROOT}/dependency-update-report.md"

echo "==> Starting dependency update check"
echo "==> Repo root: ${REPO_ROOT}"

cd "${REPO_ROOT}"

# Ensure we have the necessary tools
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is required but not found" >&2
  exit 1
fi

if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
  echo "ERROR: pip is required but not found" >&2
  exit 1
fi

PIP_CMD="pip"
if command -v pip3 &>/dev/null; then
  PIP_CMD="pip3"
fi

# Install pip-outdated or use pip list --outdated
echo "==> Checking for outdated packages"
OUTDATED_JSON=$(${PIP_CMD} list --outdated --format=json 2>/dev/null || echo "[]")

if [ "${OUTDATED_JSON}" = "[]" ]; then
  echo "==> All dependencies are up to date!"
  cat > "${OUTPUT_FILE}" <<EOF
# Dependency Update Report

All dependencies are up to date. No updates required.
EOF
  exit 0
fi

# Parse and format the outdated packages
echo "==> Generating dependency update report"
python3 - <<PYEOF
import json, sys, datetime

outdated_json = '''${OUTDATED_JSON}'''
try:
    packages = json.loads(outdated_json)
except json.JSONDecodeError:
    packages = []

report_lines = [
    "# Dependency Update Report",
    "",
    f"Generated: {datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}",
    "",
    f"Found **{len(packages)}** outdated package(s).",
    "",
    "| Package | Current Version | Latest Version |",
    "|---------|----------------|----------------|",
]

for pkg in sorted(packages, key=lambda p: p.get("name", "").lower()):
    name = pkg.get("name", "unknown")
    current = pkg.get("version", "?")
    latest = pkg.get("latest_version", "?")
    report_lines.append(f"| {name} | {current} | {latest} |")

report_lines += [
    "",
    "## Recommended Actions",
    "",
    "Run the following command to update all packages:",
    "",
    "\`\`\`bash",
    "pip install --upgrade " + " ".join(p.get("name", "") for p in packages),
    "\`\`\`",
    "",
    "> **Note:** Review each update for breaking changes before applying.",
]

with open("${OUTPUT_FILE}", "w") as f:
    f.write("\n".join(report_lines) + "\n")

print(f"Report written to ${OUTPUT_FILE}")
PYEOF

echo "==> Dependency update report saved to: ${OUTPUT_FILE}"
echo "==> Done"
