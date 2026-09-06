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
#   (a) claude-settings reference in the PER-AGENT transcript -> finding
#       recorded, with detail set to the per-agent transcript's basename
#   (b) no per-agent transcript on disk (harness-internal helper agent) ->
#       zero findings, hook exits 0 (main session transcript is never audited
#       as a fallback, even though it is readable and "dirty")
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
# Test A: per-agent transcript contains a private-resource-link ("claude-settings")
# -> finding recorded, detail is the per-agent transcript's basename
# ---------------------------------------------------------------------------

AGENT_ID_A="test-a"
SESSION_A="$TMPDIR_TEST/session-a"
mkdir -p "$SESSION_A/subagents"

MAIN_TRANSCRIPT_A="$TMPDIR_TEST/session-a.jsonl"
# Main session transcript is deliberately "dirty" too, to prove it is never audited.
printf '{"role":"user","content":"see claude-settings for the archive"}\n' > "$MAIN_TRANSCRIPT_A"

AGENT_TRANSCRIPT_A="$SESSION_A/subagents/agent-${AGENT_ID_A}.jsonl"
printf '{"role":"assistant","content":"reading claude-settings backup"}\n' > "$AGENT_TRANSCRIPT_A"

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
# Test D: tool-overreach — refactor-planner uses Bash (not in [Read, Grep, Glob]),
# detected from the PER-AGENT transcript
# ---------------------------------------------------------------------------

AGENT_ID_D="test-d"
SESSION_D="$TMPDIR_TEST/session-d"
mkdir -p "$SESSION_D/subagents"

MAIN_TRANSCRIPT_D="$TMPDIR_TEST/session-d.jsonl"
printf '{"role":"user","content":"main session, unrelated"}\n' > "$MAIN_TRANSCRIPT_D"

AGENT_TRANSCRIPT_D="$SESSION_D/subagents/agent-${AGENT_ID_D}.jsonl"
# "tool":"Bash" matches the grep pattern in the hook; refactor-planner does not declare Bash.
printf '{"role":"assistant","content":"running command","tool":"Bash"}\n' > "$AGENT_TRANSCRIPT_D"

PAYLOAD_D="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_D" \
  --arg aid "$AGENT_ID_D" \
  '{"agent_type":"refactor-planner","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

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
# "tool":"Read" is in refactor-planner's declared [Read, Grep, Glob]. No email or private links.
printf '{"role":"assistant","content":"reading file","tool":"Read"}\n' > "$AGENT_TRANSCRIPT_E"

PAYLOAD_E="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT_E" \
  --arg aid "$AGENT_ID_E" \
  '{"agent_type":"refactor-planner","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/backup-e" bash "$HOOK" <<< "$PAYLOAD_E"

AUDIT_E="$TMPDIR_TEST/backup-e/hook-logs/subagent-audit.jsonl"
if [[ -f "$AUDIT_E" ]]; then
  FINDING_COUNT_E="$(wc -l < "$AUDIT_E" | tr -d ' ')"
  [[ "$FINDING_COUNT_E" -eq 0 ]] \
    || err "Test E: expected zero findings for clean transcript, got ${FINDING_COUNT_E} finding(s)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-subagent-stop-audit: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-subagent-stop-audit: all tests pass"
