#!/usr/bin/env bash
# tests/test-subagent-stop-audit.sh — behavioral tests for the
# subagent-stop-audit hook (adapters/claude-code/user-level/hooks/).
#
# Fixture layout mirrors the real Claude Code session directory shape (same
# as tests/test-subagent-stop-record.sh):
#   <tmp>/session.jsonl                                  (main session transcript;
#                                                          what the payload's .transcript_path
#                                                          points at — deliberately left "dirty"
#                                                          in these tests to prove it is NOT audited)
#   <tmp>/session/subagents/agent-<agent_id>.jsonl        (the subagent's own transcript —
#                                                          the actual audit target)
#
# Verifies:
#   (a) a path-shaped claude-settings reference inside a Write/Edit tool_use's
#       tool_input, in the PER-AGENT transcript -> finding recorded, with
#       detail set to the per-agent transcript's basename
#   (b) no per-agent transcript on disk (harness-internal helper agent) ->
#       zero findings, hook exits 0 (main session transcript is never audited
#       as a fallback, even though it is readable and "dirty")
#   (f) an assistant TEXT block quoting the user-level CLAUDE.md's
#       "~/ws/claude-settings/ is read-only" instruction -> NOT a finding.
#       Every subagent reads that instruction, so a bare substring match on
#       "claude-settings" produced 74 identical false positives in a 2026-09
#       audit run; restricting the check to Write/Edit tool_input fixes it.
#   (g) the same path-shaped reference, but inside a Write tool_use's
#       .input.content (as opposed to .input.file_path in case (a)) ->
#       finding recorded. Confirms all three scanned tool_input fields work,
#       not just file_path.
#
# Test (a) and test (g) both use the real Claude Code transcript shape
# (.type/.message.content[]/.type=="tool_use") rather than the flattened
# fixture shape used elsewhere in this file, because the private-resource-
# link check now parses that structure specifically (see subagent-stop-
# audit.sh's rationale comment above its check #2).
#
# CS_BACKUP_ROOT is overridden per test to isolate audit logs from the real
# ~/.claude-system-backups directory (see hooks/_lib.sh HOOK_LOG_DIR).
#
# Fixture data is synthetic; email addresses are obvious dummies.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/subagent-stop-audit.sh"

if [[ ! -x "$HOOK" ]]; then
  cs_error "hook not found or not executable: $HOOK"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Test A: per-agent transcript contains a path-shaped private-resource-link
# ("~/ws/claude-settings/...") inside a Write tool_use's .input.file_path
# -> finding recorded, detail is the per-agent transcript's basename
# ---------------------------------------------------------------------------

AGENT_ID_A="test-a"
SESSION_A="$TMPDIR_TEST/session-a"
mkdir -p "$SESSION_A/subagents"

MAIN_TRANSCRIPT_A="$TMPDIR_TEST/session-a.jsonl"
# Main session transcript is deliberately "dirty" too, to prove it is never audited.
printf '{"role":"user","content":"see claude-settings for the archive"}\n' > "$MAIN_TRANSCRIPT_A"

AGENT_TRANSCRIPT_A="$SESSION_A/subagents/agent-${AGENT_ID_A}.jsonl"
jq -nc '{
  type: "assistant",
  message: {
    role: "assistant",
    content: [
      {type: "tool_use", name: "Write", input: {file_path: "~/ws/claude-settings/notes.md", content: "backup notes"}}
    ]
  }
}' > "$AGENT_TRANSCRIPT_A"

PAYLOAD_A="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_A" \
  --arg aid "$AGENT_ID_A" \
  '{"agent_type":"test-agent-noop","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-a" bash "$HOOK" <<< "$PAYLOAD_A"

AUDIT_A="$TMPDIR_TEST/backup-a/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_A" ]]; then
  err "Test A: audit log not created — private-resource-link was not detected"
else
  KIND_A="$(grep -o '"kind":"[^"]*"' "$AUDIT_A" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_A" == "private-resource-link" ]] \
    || err "Test A [kind]: expected 'private-resource-link', got '$KIND_A'"

  DETAIL_A="$(grep -o '"detail":"[^"]*"' "$AUDIT_A" | sed 's/"detail":"//;s/"//' | head -1)"
  EXPECTED_BASENAME_A="$(basename "$AGENT_TRANSCRIPT_A")"
  [[ "$DETAIL_A" == "$EXPECTED_BASENAME_A" ]] \
    || err "Test A [detail]: expected per-agent transcript basename '$EXPECTED_BASENAME_A', got '$DETAIL_A'"
fi

# ---------------------------------------------------------------------------
# Test B: no per-agent transcript on disk (harness-internal helper agent) ->
# zero findings, exit 0. The main session transcript is readable and "dirty"
# but must NOT be audited as a fallback.
# ---------------------------------------------------------------------------

AGENT_ID_B="test-b"
MAIN_TRANSCRIPT_B="$TMPDIR_TEST/session-b.jsonl"
printf '{"role":"user","content":"send result to test@gmail.com, see claude-settings"}\n' > "$MAIN_TRANSCRIPT_B"
# Deliberately no session-b/subagents/ directory created.

PAYLOAD_B="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_B" \
  --arg aid "$AGENT_ID_B" \
  '{"agent_type":"","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-b" bash "$HOOK" <<< "$PAYLOAD_B"

AUDIT_B="$TMPDIR_TEST/backup-b/hook-logs/subagent-audit.jsonl"
if [[ -f "$AUDIT_B" ]]; then
  FINDING_COUNT_B="$(wc -l < "$AUDIT_B" | tr -d ' ')"
  [[ "$FINDING_COUNT_B" -eq 0 ]] \
    || err "Test B: expected zero findings for internal agent (no per-agent transcript), got ${FINDING_COUNT_B} finding(s)"
fi

# ---------------------------------------------------------------------------
# Test C: personal-email-shape — gmail address in the PER-AGENT transcript
# ---------------------------------------------------------------------------

AGENT_ID_C="test-c"
SESSION_C="$TMPDIR_TEST/session-c"
mkdir -p "$SESSION_C/subagents"

MAIN_TRANSCRIPT_C="$TMPDIR_TEST/session-c.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_C"

AGENT_TRANSCRIPT_C="$SESSION_C/subagents/agent-${AGENT_ID_C}.jsonl"
# Dummy address clearly not real; format matches the regex in the hook.
printf '{"role":"user","content":"send result to test@gmail.com"}\n' > "$AGENT_TRANSCRIPT_C"

PAYLOAD_C="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_C" \
  --arg aid "$AGENT_ID_C" \
  '{"agent_type":"test-agent-noop","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-c" bash "$HOOK" <<< "$PAYLOAD_C"

AUDIT_C="$TMPDIR_TEST/backup-c/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_C" ]]; then
  err "Test C: audit log not created — personal-email-shape was not detected"
else
  KIND_C="$(grep -o '"kind":"[^"]*"' "$AUDIT_C" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_C" == "personal-email-shape" ]] \
    || err "Test C [kind]: expected 'personal-email-shape', got '$KIND_C'"
fi

# ---------------------------------------------------------------------------
# Test D: tool-overreach — devil-advocate uses Bash (not in [Read, Grep, Glob]),
# detected from the PER-AGENT transcript
# ---------------------------------------------------------------------------

AGENT_ID_D="test-d"
SESSION_D="$TMPDIR_TEST/session-d"
mkdir -p "$SESSION_D/subagents"

MAIN_TRANSCRIPT_D="$TMPDIR_TEST/session-d.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_D"

AGENT_TRANSCRIPT_D="$SESSION_D/subagents/agent-${AGENT_ID_D}.jsonl"
# "tool":"Bash" matches the grep pattern in the hook; devil-advocate does not declare Bash.
printf '{"role":"assistant","content":"running command","tool":"Bash"}\n' > "$AGENT_TRANSCRIPT_D"

PAYLOAD_D="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_D" \
  --arg aid "$AGENT_ID_D" \
  '{"agent_type":"devil-advocate","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-d" bash "$HOOK" <<< "$PAYLOAD_D"

AUDIT_D="$TMPDIR_TEST/backup-d/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_D" ]]; then
  err "Test D: audit log not created — tool-overreach was not detected"
else
  KIND_D="$(grep -o '"kind":"[^"]*"' "$AUDIT_D" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_D" == "tool-overreach" ]] \
    || err "Test D [kind]: expected 'tool-overreach', got '$KIND_D'"
fi

# ---------------------------------------------------------------------------
# Test E: clean per-agent transcript — no findings, exit 0
# ---------------------------------------------------------------------------

AGENT_ID_E="test-e"
SESSION_E="$TMPDIR_TEST/session-e"
mkdir -p "$SESSION_E/subagents"

MAIN_TRANSCRIPT_E="$TMPDIR_TEST/session-e.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_E"

AGENT_TRANSCRIPT_E="$SESSION_E/subagents/agent-${AGENT_ID_E}.jsonl"
# "tool":"Read" is in devil-advocate's declared [Read, Grep, Glob]. No email or private links.
printf '{"role":"assistant","content":"reading file","tool":"Read"}\n' > "$AGENT_TRANSCRIPT_E"

PAYLOAD_E="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_E" \
  --arg aid "$AGENT_ID_E" \
  '{"agent_type":"devil-advocate","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-e" bash "$HOOK" <<< "$PAYLOAD_E"

AUDIT_E="$TMPDIR_TEST/backup-e/hook-logs/subagent-audit.jsonl"
if [[ -f "$AUDIT_E" ]]; then
  FINDING_COUNT_E="$(wc -l < "$AUDIT_E" | tr -d ' ')"
  [[ "$FINDING_COUNT_E" -eq 0 ]] \
    || err "Test E: expected zero findings for clean transcript, got ${FINDING_COUNT_E} finding(s)"
fi

# ---------------------------------------------------------------------------
# Test F: assistant TEXT block quoting the CLAUDE.md instruction
# ("~/ws/claude-settings/ is Read-only") -> NOT a finding. This is prose the
# subagent read/said, not something it wrote into a Write/Edit tool_input.
# ---------------------------------------------------------------------------

AGENT_ID_F="test-f"
SESSION_F="$TMPDIR_TEST/session-f"
mkdir -p "$SESSION_F/subagents"

MAIN_TRANSCRIPT_F="$TMPDIR_TEST/session-f.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_F"

AGENT_TRANSCRIPT_F="$SESSION_F/subagents/agent-${AGENT_ID_F}.jsonl"
jq -nc '{
  type: "assistant",
  message: {
    role: "assistant",
    content: [
      {type: "text", text: "Per the user-level CLAUDE.md, ~/ws/claude-settings/ is Read-only; I will not write there."}
    ]
  }
}' > "$AGENT_TRANSCRIPT_F"

PAYLOAD_F="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_F" \
  --arg aid "$AGENT_ID_F" \
  '{"agent_type":"test-agent-noop","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-f" bash "$HOOK" <<< "$PAYLOAD_F"

AUDIT_F="$TMPDIR_TEST/backup-f/hook-logs/subagent-audit.jsonl"
if [[ -f "$AUDIT_F" ]]; then
  FINDING_COUNT_F="$(wc -l < "$AUDIT_F" | tr -d ' ')"
  [[ "$FINDING_COUNT_F" -eq 0 ]] \
    || err "Test F: expected zero findings for a CLAUDE.md quote in assistant text, got ${FINDING_COUNT_F} finding(s)"
fi

# ---------------------------------------------------------------------------
# Test G: path-shaped private link inside a Write tool_use's .input.content
# (as opposed to .input.file_path in Test A) -> finding recorded
# ---------------------------------------------------------------------------

AGENT_ID_G="test-g"
SESSION_G="$TMPDIR_TEST/session-g"
mkdir -p "$SESSION_G/subagents"

MAIN_TRANSCRIPT_G="$TMPDIR_TEST/session-g.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_G"

AGENT_TRANSCRIPT_G="$SESSION_G/subagents/agent-${AGENT_ID_G}.jsonl"
jq -nc '{
  type: "assistant",
  message: {
    role: "assistant",
    content: [
      {type: "tool_use", name: "Write", input: {file_path: "/tmp/summary.md", content: "See ~/ws/claude-settings/settings.json for the original."}}
    ]
  }
}' > "$AGENT_TRANSCRIPT_G"

PAYLOAD_G="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_G" \
  --arg aid "$AGENT_ID_G" \
  '{"agent_type":"test-agent-noop","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-g" bash "$HOOK" <<< "$PAYLOAD_G"

AUDIT_G="$TMPDIR_TEST/backup-g/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_G" ]]; then
  err "Test G: audit log not created — private-resource-link inside Write .input.content was not detected"
else
  KIND_G="$(grep -o '"kind":"[^"]*"' "$AUDIT_G" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_G" == "private-resource-link" ]] \
    || err "Test G [kind]: expected 'private-resource-link', got '$KIND_G'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-subagent-stop-audit: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-subagent-stop-audit: all tests pass"
