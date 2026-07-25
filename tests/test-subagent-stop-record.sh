#!/usr/bin/env bash
# tests/test-subagent-stop-record.sh — behavioral unit tests for the
# subagent-stop-record hook (adapters/claude-code/user-level/hooks/).
#
# Fixture layout mirrors the real Claude Code session directory shape:
#   <tmp>/session.jsonl                                  (main session transcript;
#                                                          this is what the SubagentStop
#                                                          payload's .transcript_path points at)
#   <tmp>/session/subagents/agent-<agent_id>.jsonl        (the subagent's own transcript)
#   <tmp>/session/subagents/agent-<agent_id>.meta.json    (sidecar metadata, .agentType etc.)
#
# Verifies:
#   - model is backfilled from the PER-AGENT transcript, not the main session
#     transcript (regression test for the misattribution bug: the main
#     session and the subagent can run different models)
#   - agent_type is backfilled from meta.json's .agentType when the payload's
#     .agent_type is empty
#   - when no per-agent transcript exists on disk (harness-internal helper
#     agent), agent_type falls back to "(internal)", model stays empty, and
#     the hook still exits 0
#   - the payload's official .agent_transcript_path field takes priority over
#     the on-disk fallback convention when both are present
#   - parent_agent_id / spawn_depth are backfilled from meta.json's
#     .parentAgentId / .spawnDepth when present (ADR 0022, nested delegation)
#   - parent_agent_id / spawn_depth default to empty / 0 when meta.json is
#     absent (internal agent, no parent/child data available)
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
# Test 1: model backfilled from the PER-AGENT transcript, not the main
# session transcript (regression test for misattribution)
# ---------------------------------------------------------------------------

AGENT_ID1="test-1"
SESSION1="$TMPDIR_TEST/session1"
mkdir -p "$SESSION1/subagents"

MAIN_TRANSCRIPT1="$TMPDIR_TEST/session1.jsonl"
# The main session runs a DIFFERENT model than the subagent. If the hook
# still reads this file, model would incorrectly come out as claude-opus-4-8.
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT1"

AGENT_TRANSCRIPT1="$SESSION1/subagents/agent-${AGENT_ID1}.jsonl"
printf '{"role":"assistant","model":"claude-sonnet-4-6","content":"hello"}\n' > "$AGENT_TRANSCRIPT1"
printf '{"role":"assistant","model":"claude-sonnet-4-6","content":"world"}\n' >> "$AGENT_TRANSCRIPT1"

PAYLOAD1="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT1" \
  --arg aid "$AGENT_ID1" \
  '{"agent_type":"explorer","agent_id":$aid,"transcript_path":$tp,"effort":{"level":"high"},"hook_event_name":"SubagentStop"}')"

LOG1="$TMPDIR_TEST/t1/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t1" bash "$HOOK" <<< "$PAYLOAD1"

if [[ ! -f "$LOG1" ]]; then
  err "Test 1: log file not created at $(basename "$LOG1")"
else
  RECORD1="$(tail -1 "$LOG1")"

  AGENT_TYPE1="$(printf '%s' "$RECORD1" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE1" == "explorer" ]] \
    || err "Test 1 [agent_type]: expected 'explorer', got '$AGENT_TYPE1'"

  # Regression: model must come from the per-agent transcript, not the main
  # session transcript.
  MODEL1="$(printf '%s' "$RECORD1" | jq -r '.model')"
  [[ "$MODEL1" == "claude-sonnet-4-6" ]] \
    || err "Test 1 [model, per-agent transcript]: expected 'claude-sonnet-4-6', got '$MODEL1'"

  EFFORT1="$(printf '%s' "$RECORD1" | jq -r '.effort')"
  [[ "$EFFORT1" == "high" ]] \
    || err "Test 1 [effort]: expected 'high', got '$EFFORT1'"

  RECORDED_TP1="$(printf '%s' "$RECORD1" | jq -r '.transcript_path')"
  [[ "$RECORDED_TP1" == "$AGENT_TRANSCRIPT1" ]] \
    || err "Test 1 [transcript_path]: expected the per-agent transcript path, got '$RECORDED_TP1'"
fi

# ---------------------------------------------------------------------------
# Test 2: agent_type backfilled from meta.json when payload's agent_type is empty
# ---------------------------------------------------------------------------

AGENT_ID2="test-2"
SESSION2="$TMPDIR_TEST/session2"
mkdir -p "$SESSION2/subagents"

MAIN_TRANSCRIPT2="$TMPDIR_TEST/session2.jsonl"
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT2"

AGENT_TRANSCRIPT2="$SESSION2/subagents/agent-${AGENT_ID2}.jsonl"
printf '{"role":"assistant","model":"claude-fable-5","content":"hello"}\n' > "$AGENT_TRANSCRIPT2"

META2="$SESSION2/subagents/agent-${AGENT_ID2}.meta.json"
printf '{"agentType":"Explore","description":"test"}\n' > "$META2"

PAYLOAD2="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT2" \
  --arg aid "$AGENT_ID2" \
  '{"agent_type":"","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

LOG2="$TMPDIR_TEST/t2/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t2" bash "$HOOK" <<< "$PAYLOAD2"

if [[ ! -f "$LOG2" ]]; then
  err "Test 2: log file not created at $(basename "$LOG2")"
else
  RECORD2="$(tail -1 "$LOG2")"

  AGENT_TYPE2="$(printf '%s' "$RECORD2" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE2" == "Explore" ]] \
    || err "Test 2 [agent_type from meta.json]: expected 'Explore', got '$AGENT_TYPE2'"

  MODEL2="$(printf '%s' "$RECORD2" | jq -r '.model')"
  [[ "$MODEL2" == "claude-fable-5" ]] \
    || err "Test 2 [model]: expected 'claude-fable-5', got '$MODEL2'"
fi

# ---------------------------------------------------------------------------
# Test 3: no per-agent transcript on disk (harness-internal helper agent) —
# agent_type falls back to "(internal)", model stays empty, hook exits 0
# ---------------------------------------------------------------------------

AGENT_ID3="test-3"
MAIN_TRANSCRIPT3="$TMPDIR_TEST/session3.jsonl"
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT3"
# Deliberately no session3/subagents/ directory created.

PAYLOAD3="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT3" \
  --arg aid "$AGENT_ID3" \
  '{"agent_type":"","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

LOG3="$TMPDIR_TEST/t3/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t3" bash "$HOOK" <<< "$PAYLOAD3"

if [[ ! -f "$LOG3" ]]; then
  err "Test 3: log file not created at $(basename "$LOG3")"
else
  RECORD3="$(tail -1 "$LOG3")"

  AGENT_TYPE3="$(printf '%s' "$RECORD3" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE3" == "(internal)" ]] \
    || err "Test 3 [agent_type internal fallback]: expected '(internal)', got '$AGENT_TYPE3'"

  MODEL3="$(printf '%s' "$RECORD3" | jq -r '.model')"
  # Must NOT be backfilled from the main session transcript.
  [[ -z "$MODEL3" || "$MODEL3" == "null" ]] \
    || err "Test 3 [model, no misattribution]: expected empty, got '$MODEL3'"
fi

# ---------------------------------------------------------------------------
# Test 4: payload's official .agent_transcript_path takes priority over the
# on-disk fallback convention (both are present but point at different files)
# ---------------------------------------------------------------------------

AGENT_ID4="test-4"
SESSION4="$TMPDIR_TEST/session4"
mkdir -p "$SESSION4/subagents"

MAIN_TRANSCRIPT4="$TMPDIR_TEST/session4.jsonl"
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT4"

# The on-disk fallback convention path — deliberately given a DIFFERENT model
# so the test fails loudly if the fallback is used instead of the official key.
FALLBACK_TRANSCRIPT4="$SESSION4/subagents/agent-${AGENT_ID4}.jsonl"
printf '{"role":"assistant","model":"claude-haiku-4-5-20251001","content":"fallback, should be ignored"}\n' > "$FALLBACK_TRANSCRIPT4"

# The official .agent_transcript_path — at an unrelated location, matching
# the public hooks schema field.
OFFICIAL_DIR4="$TMPDIR_TEST/official-location"
mkdir -p "$OFFICIAL_DIR4"
OFFICIAL_TRANSCRIPT4="$OFFICIAL_DIR4/agent-${AGENT_ID4}.jsonl"
printf '{"role":"assistant","model":"claude-sonnet-4-6","content":"official transcript"}\n' > "$OFFICIAL_TRANSCRIPT4"
printf '{"agentType":"code-reviewer"}\n' > "$OFFICIAL_DIR4/agent-${AGENT_ID4}.meta.json"

PAYLOAD4="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT4" \
  --arg atp "$OFFICIAL_TRANSCRIPT4" \
  --arg aid "$AGENT_ID4" \
  '{"agent_type":"","agent_id":$aid,"transcript_path":$tp,"agent_transcript_path":$atp,"hook_event_name":"SubagentStop"}')"

LOG4="$TMPDIR_TEST/t4/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t4" bash "$HOOK" <<< "$PAYLOAD4"

if [[ ! -f "$LOG4" ]]; then
  err "Test 4: log file not created at $(basename "$LOG4")"
else
  RECORD4="$(tail -1 "$LOG4")"

  MODEL4="$(printf '%s' "$RECORD4" | jq -r '.model')"
  [[ "$MODEL4" == "claude-sonnet-4-6" ]] \
    || err "Test 4 [agent_transcript_path priority]: expected model from official key 'claude-sonnet-4-6', got '$MODEL4'"

  AGENT_TYPE4="$(printf '%s' "$RECORD4" | jq -r '.agent_type')"
  [[ "$AGENT_TYPE4" == "code-reviewer" ]] \
    || err "Test 4 [meta.json alongside official key]: expected 'code-reviewer', got '$AGENT_TYPE4'"

  RECORDED_TP4="$(printf '%s' "$RECORD4" | jq -r '.transcript_path')"
  [[ "$RECORDED_TP4" == "$OFFICIAL_TRANSCRIPT4" ]] \
    || err "Test 4 [transcript_path]: expected the official agent_transcript_path, got '$RECORDED_TP4'"
fi

# ---------------------------------------------------------------------------
# Test 5: parent_agent_id / spawn_depth backfilled from meta.json when
# present (nested delegation, ADR 0022)
# ---------------------------------------------------------------------------

AGENT_ID5="test-5"
SESSION5="$TMPDIR_TEST/session5"
mkdir -p "$SESSION5/subagents"

MAIN_TRANSCRIPT5="$TMPDIR_TEST/session5.jsonl"
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT5"

AGENT_TRANSCRIPT5="$SESSION5/subagents/agent-${AGENT_ID5}.jsonl"
printf '{"role":"assistant","model":"claude-sonnet-5","content":"nested child"}\n' > "$AGENT_TRANSCRIPT5"

META5="$SESSION5/subagents/agent-${AGENT_ID5}.meta.json"
printf '{"agentType":"code-reviewer","description":"test","toolUseId":"tu-1","parentAgentId":"aea333761a3e07fde","spawnDepth":2}\n' > "$META5"

PAYLOAD5="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT5" \
  --arg aid "$AGENT_ID5" \
  '{"agent_type":"code-reviewer","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

LOG5="$TMPDIR_TEST/t5/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t5" bash "$HOOK" <<< "$PAYLOAD5"

if [[ ! -f "$LOG5" ]]; then
  err "Test 5: log file not created at $(basename "$LOG5")"
else
  RECORD5="$(tail -1 "$LOG5")"

  PARENT5="$(printf '%s' "$RECORD5" | jq -r '.parent_agent_id')"
  [[ "$PARENT5" == "aea333761a3e07fde" ]] \
    || err "Test 5 [parent_agent_id from meta.json]: expected 'aea333761a3e07fde', got '$PARENT5'"

  DEPTH5="$(printf '%s' "$RECORD5" | jq -r '.spawn_depth')"
  [[ "$DEPTH5" == "2" ]] \
    || err "Test 5 [spawn_depth from meta.json]: expected '2', got '$DEPTH5'"
fi

# ---------------------------------------------------------------------------
# Test 6: parent_agent_id / spawn_depth default to empty / 0 when no
# per-agent transcript (and thus no meta.json) exists (internal agent)
# ---------------------------------------------------------------------------

AGENT_ID6="test-6"
MAIN_TRANSCRIPT6="$TMPDIR_TEST/session6.jsonl"
printf '{"role":"assistant","model":"claude-opus-4-8","content":"main session turn"}\n' > "$MAIN_TRANSCRIPT6"
# Deliberately no session6/subagents/ directory created.

PAYLOAD6="$(jq -nc \
  --arg tp "$MAIN_TRANSCRIPT6" \
  --arg aid "$AGENT_ID6" \
  '{"agent_type":"","agent_id":$aid,"transcript_path":$tp,"hook_event_name":"SubagentStop"}')"

LOG6="$TMPDIR_TEST/t6/.claude/subagent-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t6" bash "$HOOK" <<< "$PAYLOAD6"

if [[ ! -f "$LOG6" ]]; then
  err "Test 6: log file not created at $(basename "$LOG6")"
else
  RECORD6="$(tail -1 "$LOG6")"

  PARENT6="$(printf '%s' "$RECORD6" | jq -r '.parent_agent_id')"
  [[ -z "$PARENT6" || "$PARENT6" == "null" ]] \
    || err "Test 6 [parent_agent_id, no meta.json]: expected empty, got '$PARENT6'"

  DEPTH6="$(printf '%s' "$RECORD6" | jq -r '.spawn_depth')"
  [[ "$DEPTH6" == "0" ]] \
    || err "Test 6 [spawn_depth, no meta.json]: expected '0', got '$DEPTH6'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-subagent-stop-record: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-subagent-stop-record: all tests pass"
