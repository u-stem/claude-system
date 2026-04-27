#!/usr/bin/env bash
# subagent-stop-record.sh — SubagentStop — append a JSONL record per subagent
# completion. Project-local log so transcripts stay scoped to the project.
#
# Maps to TODO-for-phase-7b §4 (formerly proposed as `log-subagent.sh`).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

log_file="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/subagent-log.jsonl"
mkdir -p "$(dirname "$log_file")"

agent_type="$(printf '%s' "$INPUT" | jq -r '.subagent.type // .agent_type // empty' 2>/dev/null || true)"
agent_id="$(printf '%s' "$INPUT" | jq -r '.subagent.id // .agent_id // empty' 2>/dev/null || true)"
transcript_path="$(printf '%s' "$INPUT" | jq -r '.subagent.transcript_path // .agent_transcript_path // empty' 2>/dev/null || true)"
exit_code="$(printf '%s' "$INPUT" | jq -r '.subagent.exit_code // .exit_code // 0' 2>/dev/null || echo 0)"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","agent_type":%s,"agent_id":%s,"transcript_path":%s,"exit_code":%s}\n' \
  "$ts" \
  "$(printf '%s' "$agent_type" | jq -Rs .)" \
  "$(printf '%s' "$agent_id" | jq -Rs .)" \
  "$(printf '%s' "$transcript_path" | jq -Rs .)" \
  "${exit_code:-0}" >> "$log_file"

# Wire failure-feedback loop: a failing subagent feeds the same
# failure-log.jsonl that check-failure-patterns.sh inspects at SessionStart.
if [[ "$exit_code" != "0" && -n "$exit_code" && "$exit_code" != "null" ]]; then
  reason="$(printf '%s' "$INPUT" | jq -r '.subagent.error // .error // empty' 2>/dev/null || true)"
  if [[ -z "$reason" ]]; then
    reason="subagent ${agent_type:-?} exited with $exit_code"
  fi
  printf '%s\n' "$reason" | "$HOOKS_LIB_DIR/log-failure.sh" subagent || true
fi

exit 0
