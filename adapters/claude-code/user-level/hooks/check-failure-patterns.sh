#!/usr/bin/env bash
# check-failure-patterns.sh — SessionStart — surface recurring failure
# patterns from the project failure log so the agent can promote them
# into rules/skills.
# Migrated from claude-settings/hooks/check-failure-patterns.sh; behavior preserved.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

log_file="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/failure-log.jsonl"

if [[ ! -f "$log_file" ]]; then
  exit 0
fi

total="$(wc -l < "$log_file" | tr -d ' ')"
if [[ "$total" -lt 3 ]]; then
  exit 0
fi

recurring=""
for category in check check-types test subagent; do
  count="$(/usr/bin/grep -c "\"category\":\"$category\"" "$log_file" 2>/dev/null || true)"
  count="${count:-0}"
  if [[ "$count" -ge 3 ]]; then
    # `jq -r '.error // empty'` skips malformed jsonl lines silently. The
    # outer `|| true` keeps the SessionStart hook alive even when jq fails.
    recent="$(/usr/bin/grep "\"category\":\"$category\"" "$log_file" | tail -3 | jq -r '.error // empty' 2>/dev/null || true)"
    recurring="${recurring}\n[${category}] ${count} failures:\n${recent}\n"
  fi
done

if [[ -n "$recurring" ]]; then
  echo "[Harness Feedback] Recurring failures detected in this project."
  echo "Consider adding rules (.claude/rules/) or skills (.claude/skills/) to prevent these patterns:"
  # Use printf %b for portable backslash interpretation. /bin/echo on macOS
  # does not honour -e, and even bash builtin behaviour can vary depending on
  # `shopt -s xpg_echo`. printf is the only spec-stable answer.
  printf '%b\n' "$recurring"
  echo "After addressing, clear the log: rm ${log_file}"
fi
