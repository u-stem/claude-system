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

# Only recent failures count. Replaying months-old lines reads as current
# breakage: on 2026-08-09 this hook reported three "test failures" that were a
# TDD red phase from four weeks earlier plus one negative test, and they were
# taken for live defects. Entries marked intent="expected" are excluded for the
# same reason — a negative test proving a guard rejects something is not a
# regression. Records predating the intent field default to "real".
WINDOW_DAYS="${CS_FAILURE_WINDOW_DAYS:-14}"
cutoff="$(date -u -v-"${WINDOW_DAYS}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
if [[ -z "$cutoff" ]]; then
  exit 0
fi

recurring=""
for category in check check-types test subagent; do
  # jq -R + fromjson? tolerates a malformed line instead of aborting; grep -c
  # could not tell a corrupt log from a genuinely empty category.
  entries="$(jq -R -c --arg cutoff "$cutoff" --arg cat "$category" \
    'fromjson? | select(.category == $cat and .ts >= $cutoff and ((.intent // "real") == "real"))' \
    "$log_file" 2>/dev/null || true)"
  [[ -n "$entries" ]] || continue

  count="$(printf '%s' "$entries" | /usr/bin/grep -c . || true)"
  count="${count:-0}"
  [[ "$count" -ge 3 ]] || continue

  oldest="$(printf '%s' "$entries" | jq -rs 'map(.ts) | min // empty' 2>/dev/null || true)"
  newest="$(printf '%s' "$entries" | jq -rs 'map(.ts) | max // empty' 2>/dev/null || true)"
  recent="$(printf '%s' "$entries" | tail -3 | jq -r '.error // empty' 2>/dev/null || true)"

  recurring="${recurring}\n[${category}] ${count} failures (${oldest%%T*} .. ${newest%%T*}):\n${recent}\n"
done

if [[ -n "$recurring" ]]; then
  echo "[Harness Feedback] Recurring failures in the last ${WINDOW_DAYS} days (deliberate test failures excluded)."
  echo "Consider adding rules (.claude/rules/) or skills (.claude/skills/) to prevent these patterns:"
  # Use printf %b for portable backslash interpretation. /bin/echo on macOS
  # does not honour -e, and even bash builtin behaviour can vary depending on
  # `shopt -s xpg_echo`. printf is the only spec-stable answer.
  printf '%b\n' "$recurring"
  echo "After addressing, archive the log to keep measurement continuity:"
  echo "  tools/archive-failure-log.sh --project ${log_file%/.claude/failure-log.jsonl}"
  echo "Aggregate anytime with: tools/loop-report.sh"
fi
