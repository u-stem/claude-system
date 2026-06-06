#!/usr/bin/env bash
# tests/test-subagent-stop-audit.sh — behavioral tests for the
# subagent-stop-audit hook (adapters/claude-code/user-level/hooks/).
#
# Verifies:
#   (a) gmail address in transcript → personal-email-shape finding emitted
#   (b) explorer uses undeclared tool (Bash) → tool-overreach finding emitted
#   (c) clean transcript (only declared tool, no email/private-link) → zero findings
#
# Fixture: synthetic JSONL transcripts in mktemp directory.
# Email addresses are obvious dummies (test@gmail.com).
# No real transcripts or real personal data are used.
#
# CS_BACKUP_ROOT is overridden per test to isolate audit logs from the real
# ~/.claude-system-backups directory.

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

# ---------------------------------------------------------------------------
# Fixture: isolated temp dir, cleaned up on exit
# ---------------------------------------------------------------------------

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Test A: personal-email-shape — gmail address in transcript triggers finding
# ---------------------------------------------------------------------------

TRANSCRIPT_A="$TMPDIR_TEST/ta-transcript.jsonl"
# Dummy address clearly not real; format matches the regex in the hook.
printf '{"role":"user","content":"send result to test@gmail.com"}\n' > "$TRANSCRIPT_A"

PAYLOAD_A="$(jq -nc \
  --arg tp "$TRANSCRIPT_A" \
  '{"agent_type":"test-agent-noop","transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/ta" bash "$HOOK" <<< "$PAYLOAD_A"

AUDIT_A="$TMPDIR_TEST/ta/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_A" ]]; then
  err "Test A: audit log not created — personal-email-shape was not detected"
else
  KIND_A="$(grep -o '"kind":"[^"]*"' "$AUDIT_A" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_A" == "personal-email-shape" ]] \
    || err "Test A [kind]: expected 'personal-email-shape', got '$KIND_A'"
fi

# ---------------------------------------------------------------------------
# Test B: tool-overreach — explorer uses Bash (not in [Read, Grep, Glob])
# ---------------------------------------------------------------------------

TRANSCRIPT_B="$TMPDIR_TEST/tb-transcript.jsonl"
# "tool":"Bash" matches the grep pattern in the hook; explorer does not declare Bash.
printf '{"role":"assistant","content":"running command","tool":"Bash"}\n' > "$TRANSCRIPT_B"

PAYLOAD_B="$(jq -nc \
  --arg tp "$TRANSCRIPT_B" \
  '{"agent_type":"explorer","transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/tb" bash "$HOOK" <<< "$PAYLOAD_B"

AUDIT_B="$TMPDIR_TEST/tb/hook-logs/subagent-audit.jsonl"
if [[ ! -f "$AUDIT_B" ]]; then
  err "Test B: audit log not created — tool-overreach was not detected"
else
  KIND_B="$(grep -o '"kind":"[^"]*"' "$AUDIT_B" | sed 's/"kind":"//;s/"//' | head -1)"
  [[ "$KIND_B" == "tool-overreach" ]] \
    || err "Test B [kind]: expected 'tool-overreach', got '$KIND_B'"
fi

# ---------------------------------------------------------------------------
# Test C: clean transcript — no findings, exit 0
# ---------------------------------------------------------------------------

TRANSCRIPT_C="$TMPDIR_TEST/tc-transcript.jsonl"
# "tool":"Read" is in explorer's declared [Read, Grep, Glob]. No email or private links.
printf '{"role":"assistant","content":"reading file","tool":"Read"}\n' > "$TRANSCRIPT_C"

PAYLOAD_C="$(jq -nc \
  --arg tp "$TRANSCRIPT_C" \
  '{"agent_type":"explorer","transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

CS_BACKUP_ROOT="$TMPDIR_TEST/tc" bash "$HOOK" <<< "$PAYLOAD_C"

AUDIT_C="$TMPDIR_TEST/tc/hook-logs/subagent-audit.jsonl"
if [[ -f "$AUDIT_C" ]]; then
  FINDING_COUNT_C="$(wc -l < "$AUDIT_C" | tr -d ' ')"
  [[ "$FINDING_COUNT_C" -eq 0 ]] \
    || err "Test C: expected zero findings for clean transcript, got ${FINDING_COUNT_C} finding(s)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-subagent-stop-audit: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-subagent-stop-audit: all tests pass"
