#!/usr/bin/env bash
# log-failure.sh — append a failure entry to the project failure log.
# Helper hook (not bound to a Claude Code event directly); called by
# log-bash-failure.sh.
#
# Usage: echo "$error_output" | log-failure.sh <category> [exit_code] [cmd]
#   category:  check | check-types | test | subagent | unknown
#   exit_code: optional, numeric; omitted/non-numeric input is logged as null
#   cmd:       optional, already truncated by the caller
# Log path: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/failure-log.jsonl
#
# Migrated from claude-settings/hooks/log-failure.sh; behavior preserved.
# exit_code/cmd are additive fields (existing readers of .error/.category are
# unaffected: check-failure-patterns.sh and loop-report.sh only read those two).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

category="${1:-unknown}"
exit_code_arg="${2:-}"
cmd_arg="${3:-}"
log_file="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/failure-log.jsonl"

error_output="$(cat)"
if [[ -z "$error_output" ]]; then
  exit 0
fi

# Pick the first meaningful error line (skip noise).
first_error="$(printf '%s' "$error_output" | /usr/bin/grep -E '(error|Error|ERROR|FAIL|✗)' | head -1 | sed 's/^[[:space:]]*//' || true)"
if [[ -z "$first_error" ]]; then
  first_error="$(printf '%s' "$error_output" | head -1 | sed 's/^[[:space:]]*//')"
fi

mkdir -p "$(dirname "$log_file")"

# JSON-encode the error string via jq so quotes / newlines are safe.
encoded_error="$(printf '%s' "$first_error" | jq -Rs .)"

exit_code_json="null"
if [[ "$exit_code_arg" =~ ^-?[0-9]+$ ]]; then
  exit_code_json="$exit_code_arg"
fi

cmd_json="null"
if [[ -n "$cmd_arg" ]]; then
  cmd_json="$(printf '%s' "$cmd_arg" | jq -Rs .)"
fi

# intent separates a real failure from one a test caused on purpose. Negative
# tests assert that a guard rejects something, so they produce genuine non-zero
# exits; without this field the observation loop counts them as breakage. On
# 2026-08-09 the SessionStart notice surfaced three "test failures" of which one
# was a negative test proving the push guard works and two were a TDD red phase.
# Additive: readers that do not know the field see the same records as before,
# and records written before this change are treated as "real" (the default).
#
# Detected two ways because a hook runs in its own process: an env var set
# inside the agent's Bash command does not reach it. So the recorded command
# string is checked as well, which is what actually works in practice —
# `CS_EXPECTED_FAILURE=1 <command that must fail>`. The env check covers direct
# invocation of this script, as the tests do.
intent="real"
if [[ "${CS_EXPECTED_FAILURE:-0}" == "1" ]] || [[ "$cmd_arg" == *"CS_EXPECTED_FAILURE=1"* ]]; then
  intent="expected"
fi

printf '{"ts":"%s","category":"%s","error":%s,"exit_code":%s,"cmd":%s,"intent":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$category" "$encoded_error" "$exit_code_json" "$cmd_json" "$intent" >> "$log_file"
