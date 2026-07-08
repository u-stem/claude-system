#!/usr/bin/env bash
# subagent-stop-record.sh — SubagentStop — append a JSONL record per subagent
# completion. Project-local log so transcripts stay scoped to the project.
#
# Maps to ADR 0012 (token economy mechanization) §measurement-point.
# Output schema: {ts, agent_type, model, effort, agent_id, transcript_path, exit_code}
#
# Fields sourced from SubagentStop payload (2.x public schema):
#   .agent_type            — built-in name ("Explore"/"Plan") or custom agent name
#   .agent_id              — unique subagent run identifier
#   .agent_transcript_path — official field for the subagent's OWN transcript
#                            (code.claude.com/docs/en/hooks.md as of 2026-07).
#                            Preferred when present and readable.
#   .transcript_path       — path to the MAIN SESSION's JSONL transcript, not
#                            the subagent's own transcript (verified against
#                            real payloads). Used only as the basis for the
#                            on-disk fallback resolution (see
#                            hk_resolve_agent_transcript in _lib.sh) when
#                            .agent_transcript_path is absent or stale.
#   .exit_code             — 0 on success; non-zero triggers failure-feedback loop
#   .effort.level          — effort level override if set in frontmatter (ADR 0013)
#
# model is not in the payload; it is backfilled from the per-agent transcript
# when one exists on disk. Harness-internal helper agents (not spawned via the
# Agent tool, e.g. auto-generated plan/explore steps) have no per-agent
# transcript file; for those, agent_type is recorded as "(internal)" when the
# payload didn't supply one, and model is left empty rather than misattributed
# from the main session (which may run a different model than the subagent).
#
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
main_transcript_path="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
exit_code="$(printf '%s' "$INPUT" | jq -r '.exit_code // 0' 2>/dev/null || echo 0)"
# .effort.level is present when the subagent's frontmatter declares an effort override.
effort="$(printf '%s' "$INPUT" | jq -r '.effort.level // empty' 2>/dev/null || true)"

# Resolve the per-agent transcript (official .agent_transcript_path first,
# on-disk convention fallback — see hk_resolve_agent_transcript in _lib.sh).
# Empty when neither resolution applies, which is the graceful "internal
# agent" fallback below. meta.json is always the same basename with
# .jsonl swapped for .meta.json.
agent_transcript="$(hk_resolve_agent_transcript "$INPUT" "$main_transcript_path" "$agent_id")"
meta_path=""
[[ -n "$agent_transcript" ]] && meta_path="${agent_transcript%.jsonl}.meta.json"

# Backfill model from the per-agent transcript: assistant turns carry a
# "model":"..." literal (verified: subagent model frontmatter is honored; the
# alias resolves to the current generation, e.g. sonnet -> claude-sonnet-5 as
# of Claude Code 2.1.197 / ADR 0018). Use the most-frequent model id across
# the transcript to handle mixed turns. When agent_type is missing from the
# payload, backfill it from the sidecar meta.json's `.agentType`.
#
# When no per-agent transcript exists on disk, this is a harness-internal
# helper agent (not spawned via the Agent tool) rather than a missing-file
# error: model is left empty (never misattributed from the main session,
# which may be running a different model) and agent_type falls back to the
# literal "(internal)" marker so it is distinguishable from a genuine gap.
model=""
recorded_transcript_path="$main_transcript_path"
if [[ -n "$agent_transcript" && -f "$agent_transcript" ]]; then
  recorded_transcript_path="$agent_transcript"
  model="$(grep -o '"model":"[^"]*"' "$agent_transcript" 2>/dev/null \
    | sed 's/^"model":"//; s/"$//' | sort | uniq -c | sort -rn | head -1 \
    | awk '{print $2}')"
  if [[ -z "$agent_type" && -f "$meta_path" ]]; then
    agent_type="$(jq -r '.agentType // empty' "$meta_path" 2>/dev/null || true)"
  fi
else
  # A typed delegation without a per-agent transcript is anomalous — warn.
  # An untyped record is the normal internal-agent case (the majority of
  # SubagentStop events); stay silent to avoid per-event stderr noise.
  if [[ -n "$agent_transcript" && -n "$agent_type" ]]; then
    hk_warn "subagent-stop-record: per-agent transcript not found: $(basename "$agent_transcript")"
  fi
  [[ -z "$agent_type" ]] && agent_type="(internal)"
fi

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","agent_type":%s,"model":%s,"effort":%s,"agent_id":%s,"transcript_path":%s,"exit_code":%s}\n' \
  "$ts" \
  "$(printf '%s' "$agent_type" | jq -Rs .)" \
  "$(printf '%s' "$model"      | jq -Rs .)" \
  "$(printf '%s' "$effort"     | jq -Rs .)" \
  "$(printf '%s' "$agent_id"   | jq -Rs .)" \
  "$(printf '%s' "$recorded_transcript_path" | jq -Rs .)" \
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
