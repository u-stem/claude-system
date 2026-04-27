#!/usr/bin/env bash
# log-failure.sh — append a failure entry to the project failure log.
# Helper hook (not bound to a Claude Code event directly); called by
# log-bash-failure.sh.
#
# Usage: echo "$error_output" | log-failure.sh <category>
#   category: check | check-types | test | subagent | unknown
# Log path: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/failure-log.jsonl
#
# Migrated from claude-settings/hooks/log-failure.sh; behavior preserved.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

category="${1:-unknown}"
log_file="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/failure-log.jsonl"

error_output="$(cat)"
if [[ -z "$error_output" ]]; then
  exit 0
fi

# Pick the first meaningful error line (skip noise).
first_error="$(printf '%s' "$error_output" | /usr/bin/grep -E '(error|Error|ERROR|FAIL|✗)' | head -1 | sed 's/^[[:space:]]*//')"
if [[ -z "$first_error" ]]; then
  first_error="$(printf '%s' "$error_output" | head -1 | sed 's/^[[:space:]]*//')"
fi

mkdir -p "$(dirname "$log_file")"

# JSON-encode the error string via jq so quotes / newlines are safe.
encoded_error="$(printf '%s' "$first_error" | jq -Rs .)"
printf '{"ts":"%s","category":"%s","error":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$category" "$encoded_error" >> "$log_file"
