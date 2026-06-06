#!/usr/bin/env bash
# tests/test-subagent-stop-record.sh — behavioral unit tests for the
# subagent-stop-record hook (adapters/claude-code/user-level/hooks/).
#
# Verifies:
#   - agent_type extracted from payload .agent_type
#   - model backfilled from transcript JSONL (most-frequent "model":"..." literal)
#   - effort extracted from payload .effort.level
#   - graceful handling when transcript is absent (model="", exit 0)
#
# Fixture: synthetic JSONL transcripts in a mktemp directory.
# No real transcripts are used (personal data risk).

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/subagent-stop-record.sh"

if [[ ! -x "$HOOK" ]]; then
  cs_error "hook not found or not executable: $HOOK"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

# ---------------------------------------------------------------------------
# Fixture: isolated temp dir per test run
# ---------------------------------------------------------------------------

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Test 1: full payload — agent_type, model (from transcript), effort populated
# ---------------------------------------------------------------------------

TRANSCRIPT1="$TMPDIR_TEST/t1-transcript.jsonl"
printf '{"role":"assistant","model":"claude-sonnet-4-6","content":"hello"}\n' > "$TRANSCRIPT1"
printf '{"role":"assistant","model":"claude-sonnet-4-6","content":"world"}\n' >> "$TRANSCRIPT1"

# Use jq to safely construct JSON with the dynamic transcript path
PAYLOAD1="$(jq -nc \
  --arg tp "$TRANSCRIPT1" \
  '{"agent_type":"explorer","agent_id":"test-1","transcript_path":$tp,"effort":{"level":"high"},"hook_event_name":"SubagentStop"}')"

LOG1="$TMPDIR_TEST/t1/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t1" bash "$HOOK" <<< "$PAYLOAD1"

if [[ ! -f "$LOG1" ]]; then
  err "Test 1: log file not created at $(basename "$LOG1")"
else
  RECORD1="$(tail -1 "$LOG1")"

  # Arrange-Act-Assert: agent_type
  AGENT_TYPE1="$(printf '%s' "$RECORD1" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE1" == "explorer" ]] \
    || err "Test 1 [agent_type]: expected 'explorer', got '$AGENT_TYPE1'"

  # Arrange-Act-Assert: model (backfilled from transcript)
  MODEL1="$(printf '%s' "$RECORD1" | jq -r '.model')"
  [[ "$MODEL1" == "claude-sonnet-4-6" ]] \
    || err "Test 1 [model]: expected 'claude-sonnet-4-6', got '$MODEL1'"

  # Arrange-Act-Assert: effort
  EFFORT1="$(printf '%s' "$RECORD1" | jq -r '.effort')"
  [[ "$EFFORT1" == "high" ]] \
    || err "Test 1 [effort]: expected 'high', got '$EFFORT1'"
fi

# ---------------------------------------------------------------------------
# Test 2: transcript absent — model is empty string, script exits 0
# ---------------------------------------------------------------------------

MISSING_TRANSCRIPT="$TMPDIR_TEST/nonexistent.jsonl"
PAYLOAD2="$(jq -nc \
  --arg tp "$MISSING_TRANSCRIPT" \
  '{"agent_type":"implementer","agent_id":"test-2","transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

LOG2="$TMPDIR_TEST/t2/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t2" bash "$HOOK" <<< "$PAYLOAD2"

if [[ ! -f "$LOG2" ]]; then
  err "Test 2: log file not created at $(basename "$LOG2")"
else
  RECORD2="$(tail -1 "$LOG2")"

  # model should be empty string (not an error)
  MODEL2="$(printf '%s' "$RECORD2" | jq -r '.model')"
  [[ -z "$MODEL2" || "$MODEL2" == "null" ]] \
    || err "Test 2 [model]: expected empty when transcript absent, got '$MODEL2'"

  # agent_type should still be populated from payload
  AGENT_TYPE2="$(printf '%s' "$RECORD2" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE2" == "implementer" ]] \
    || err "Test 2 [agent_type]: expected 'implementer', got '$AGENT_TYPE2'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-subagent-stop-record: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-subagent-stop-record: all tests pass"
