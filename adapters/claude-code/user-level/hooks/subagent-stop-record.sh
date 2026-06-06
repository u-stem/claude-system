#!/usr/bin/env bash
# subagent-stop-record.sh — SubagentStop — append a JSONL record per subagent
# completion. Project-local log so transcripts stay scoped to the project.
#
# Maps to ADR 0012 (token economy mechanization) §measurement-point.
# Output schema: {ts, agent_type, model, effort, agent_id, transcript_path, exit_code}
#
# Fields sourced from SubagentStop payload (2.x public schema):
#   .agent_type        — built-in name ("Explore"/"Plan") or custom agent name
#   .agent_id          — unique subagent run identifier
#   .transcript_path   — path to the subagent's JSONL transcript
#   .exit_code         — 0 on success; non-zero triggers failure-feedback loop
#   .effort.level      — effort level override if set in frontmatter (ADR 0013)
#
# model is not in the payload; it is backfilled from the transcript.
# Transcript absolute paths are kept only in the structured JSONL record;
# any stderr messages use basename only (output hygiene per ADR 0001).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

log_file="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/subagent-log.jsonl"
mkdir -p "$(dirname "$log_file")"

# Extract fields directly from the public SubagentStop schema.
agent_type="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"
agent_id="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
transcript_path="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
exit_code="$(printf '%s' "$INPUT" | jq -r '.exit_code // 0' 2>/dev/null || echo 0)"
# .effort.level is present when the subagent's frontmatter declares an effort override.
effort="$(printf '%s' "$INPUT" | jq -r '.effort.level // empty' 2>/dev/null || true)"

# Backfill model from transcript: the assistant turns carry a "model":"..." literal
# (verified: subagent model frontmatter is honored, e.g. sonnet -> claude-sonnet-4-6).
# Use the most-frequent model id across the transcript to handle mixed turns.
# If the transcript is absent or unreadable, model is left as empty string and
# we log a debug notice on stderr (basename only — no absolute paths).
model=""
if [[ -n "$transcript_path" ]]; then
  if [[ -f "$transcript_path" ]]; then
    model="$(grep -o '"model":"[^"]*"' "$transcript_path" 2>/dev/null \
      | sed 's/^"model":"//; s/"$//' | sort | uniq -c | sort -rn | head -1 \
      | awk '{print $2}')"
  else
    hk_warn "subagent-stop-record: transcript not found: $(basename "$transcript_path")"
  fi
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","agent_type":%s,"model":%s,"effort":%s,"agent_id":%s,"transcript_path":%s,"exit_code":%s}\n' \
  "$ts" \
  "$(printf '%s' "$agent_type" | jq -Rs .)" \
  "$(printf '%s' "$model"      | jq -Rs .)" \
  "$(printf '%s' "$effort"     | jq -Rs .)" \
  "$(printf '%s' "$agent_id"   | jq -Rs .)" \
  "$(printf '%s' "$transcript_path" | jq -Rs .)" \
  "${exit_code:-0}" >> "$log_file"

# Wire failure-feedback loop: a failing subagent feeds the same
# failure-log.jsonl that check-failure-patterns.sh inspects at SessionStart.
if [[ "$exit_code" != "0" && -n "$exit_code" && "$exit_code" != "null" ]]; then
  reason="$(printf '%s' "$INPUT" | jq -r '.error // empty' 2>/dev/null || true)"
  if [[ -z "$reason" ]]; then
    reason="subagent ${agent_type:-?} exited with $exit_code"
  fi
  printf '%s\n' "$reason" | "$HOOKS_LIB_DIR/log-failure.sh" subagent || true
fi

exit 0
