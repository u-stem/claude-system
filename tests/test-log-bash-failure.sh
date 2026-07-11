#!/usr/bin/env bash
# tests/test-log-bash-failure.sh — behavioral unit tests for the
# log-bash-failure hook (adapters/claude-code/user-level/hooks/), rebound
# from PostToolUse to PostToolUseFailure (see ADR / CHANGELOG for context:
# Claude Code does not fire PostToolUse for a failed Bash command).
#
# Verifies:
#   1. PostToolUseFailure + .tool_output.exit_code=1 + stderr -> recorded,
#      with exit_code and cmd captured in the log entry
#   2. PostToolUseFailure + .tool_response shape (no exit-code key) + FAIL
#      only in stdout -> recorded via the stdout fallback
#   3. PostToolUse + no exit-code key (the real-world success-only payload
#      shape) -> NOT recorded
#   4. .interrupted == true (nested under a result object) -> NOT recorded,
#      even with a failing event/exit code
#   5. "bun test ..." command -> category is "test"
#   6. the REAL v2.1.206 PostToolUseFailure shape (top-level .error =
#      "Exit code N\n<stderr>", .is_interrupt=false, no tool_output/
#      tool_response/tool_result at all) -> recorded, exit_code parsed out
#      of the .error string
#   7. same real shape with .is_interrupt=true -> NOT recorded
#   8. real-shape stderr containing NO error keyword (e.g. "bash: cmd:
#      command not found") -> recorded via log-failure.sh's first-line
#      fallback, not lost to a grep-induced `set -e` abort (regression guard)
#   9. PostToolUse + a result object WITH a non-zero exit_code -> recorded
#      (pins down the defensive PostToolUse branch's happy path)
#  10. cmd containing an inline secret (e.g. "API_KEY=sk-abc123 ...") ->
#      the recorded cmd does NOT contain the secret value and instead
#      contains [REDACTED]; error/category classification is unaffected
#      (redaction is applied to cmd only, after categorization)
#
# Fixture: synthetic JSON payloads piped to the hook over stdin.
# CLAUDE_PROJECT_DIR is redirected into a mktemp dir per test so the real
# project's failure-log.jsonl is never touched.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/log-bash-failure.sh"

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
# Test 1: PostToolUseFailure, docs-shape .tool_output with exit_code + stderr
# ---------------------------------------------------------------------------

PAYLOAD1="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_input": {"command": "npm run lint"},
  "tool_output": {
    "exit_code": 1,
    "stdout": "",
    "stderr": "Error: 3 problems (3 errors, 0 warnings)"
  }
}')"

LOG1="$TMPDIR_TEST/t1/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t1" bash "$HOOK" <<< "$PAYLOAD1"

if [[ ! -f "$LOG1" ]]; then
  err "Test 1: log file not created at $(basename "$LOG1")"
else
  RECORD1="$(tail -1 "$LOG1")"

  CATEGORY1="$(printf '%s' "$RECORD1" | jq -r '.category')"
  [[ "$CATEGORY1" == "check" ]] \
    || err "Test 1 [category]: expected 'check', got '$CATEGORY1'"

  ERROR1="$(printf '%s' "$RECORD1" | jq -r '.error')"
  [[ "$ERROR1" == *"3 problems"* ]] \
    || err "Test 1 [error]: expected stderr content, got '$ERROR1'"

  EXIT_CODE1="$(printf '%s' "$RECORD1" | jq -r '.exit_code')"
  [[ "$EXIT_CODE1" == "1" ]] \
    || err "Test 1 [exit_code]: expected 1, got '$EXIT_CODE1'"

  CMD1="$(printf '%s' "$RECORD1" | jq -r '.cmd')"
  [[ "$CMD1" == "npm run lint" ]] \
    || err "Test 1 [cmd]: expected 'npm run lint', got '$CMD1'"
fi

# ---------------------------------------------------------------------------
# Test 2: PostToolUseFailure, empirical .tool_response shape (no exit-code
# key), stderr empty, FAIL only present in stdout
# ---------------------------------------------------------------------------

PAYLOAD2="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_input": {"command": "vitest run"},
  "tool_response": {
    "stdout": "RUN  v1.2.3\nFAIL src/foo.test.ts > adds numbers",
    "stderr": ""
  }
}')"

LOG2="$TMPDIR_TEST/t2/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t2" bash "$HOOK" <<< "$PAYLOAD2"

if [[ ! -f "$LOG2" ]]; then
  err "Test 2: log file not created at $(basename "$LOG2") — stdout fallback did not fire"
else
  RECORD2="$(tail -1 "$LOG2")"

  ERROR2="$(printf '%s' "$RECORD2" | jq -r '.error')"
  [[ "$ERROR2" == *"FAIL"* ]] \
    || err "Test 2 [error, stdout fallback]: expected FAIL line from stdout, got '$ERROR2'"

  EXIT_CODE2="$(printf '%s' "$RECORD2" | jq -r '.exit_code')"
  [[ "$EXIT_CODE2" == "null" ]] \
    || err "Test 2 [exit_code]: expected null (no exit-code key in payload), got '$EXIT_CODE2'"
fi

# ---------------------------------------------------------------------------
# Test 3: PostToolUse (real-world success-only payload shape observed for
# Bash), no exit-code key at all -> must NOT be recorded
# ---------------------------------------------------------------------------

PAYLOAD3="$(jq -nc '{
  "hook_event_name": "PostToolUse",
  "tool_input": {"command": "ls -la"},
  "tool_response": {
    "stdout": "total 0",
    "stderr": "",
    "interrupted": false,
    "isImage": false,
    "noOutputExpected": false
  }
}')"

LOG3="$TMPDIR_TEST/t3/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t3" bash "$HOOK" <<< "$PAYLOAD3"

[[ ! -f "$LOG3" ]] \
  || err "Test 3: log file was created for a successful PostToolUse payload (should be a no-op)"

# ---------------------------------------------------------------------------
# Test 4: interrupted == true -> must NOT be recorded, even for a failure event
# ---------------------------------------------------------------------------

PAYLOAD4="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_input": {"command": "long-running-build"},
  "tool_output": {
    "exit_code": 130,
    "stdout": "",
    "stderr": "user interrupted",
    "interrupted": true
  }
}')"

LOG4="$TMPDIR_TEST/t4/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t4" bash "$HOOK" <<< "$PAYLOAD4"

[[ ! -f "$LOG4" ]] \
  || err "Test 4: log file was created for an interrupted command (should be a no-op)"

# ---------------------------------------------------------------------------
# Test 5: "bun test ..." command -> category is "test"
# ---------------------------------------------------------------------------

PAYLOAD5="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_input": {"command": "bun test ./src"},
  "tool_output": {
    "exit_code": 1,
    "stdout": "",
    "stderr": "FAIL src/index.test.ts"
  }
}')"

LOG5="$TMPDIR_TEST/t5/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t5" bash "$HOOK" <<< "$PAYLOAD5"

if [[ ! -f "$LOG5" ]]; then
  err "Test 5: log file not created at $(basename "$LOG5")"
else
  RECORD5="$(tail -1 "$LOG5")"
  CATEGORY5="$(printf '%s' "$RECORD5" | jq -r '.category')"
  [[ "$CATEGORY5" == "test" ]] \
    || err "Test 5 [category]: expected 'test', got '$CATEGORY5'"
fi

# ---------------------------------------------------------------------------
# Test 6: the REAL v2.1.206 PostToolUseFailure shape — top-level .error
# ("Exit code N\n<stderr>") + .is_interrupt, no tool_output/tool_response/
# tool_result at all -> recorded, exit_code parsed out of .error
# ---------------------------------------------------------------------------

PAYLOAD6="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "vitest run", "description": "run tests"},
  "error": "Exit code 1\nerror: synthetic vitest failure",
  "is_interrupt": false,
  "duration_ms": 282
}')"

LOG6="$TMPDIR_TEST/t6/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t6" bash "$HOOK" <<< "$PAYLOAD6"

if [[ ! -f "$LOG6" ]]; then
  err "Test 6: log file not created at $(basename "$LOG6") — real v2.1.206 shape not handled"
else
  RECORD6="$(tail -1 "$LOG6")"

  ERROR6="$(printf '%s' "$RECORD6" | jq -r '.error')"
  [[ "$ERROR6" == *"synthetic vitest failure"* ]] \
    || err "Test 6 [error]: expected payload .error content, got '$ERROR6'"

  EXIT_CODE6="$(printf '%s' "$RECORD6" | jq -r '.exit_code')"
  [[ "$EXIT_CODE6" == "1" ]] \
    || err "Test 6 [exit_code, parsed from 'Exit code N']: expected 1, got '$EXIT_CODE6'"

  CATEGORY6="$(printf '%s' "$RECORD6" | jq -r '.category')"
  [[ "$CATEGORY6" == "test" ]] \
    || err "Test 6 [category]: expected 'test', got '$CATEGORY6'"
fi

# ---------------------------------------------------------------------------
# Test 7: same real shape with .is_interrupt=true -> must NOT be recorded
# ---------------------------------------------------------------------------

PAYLOAD7="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "long-running-build", "description": "build"},
  "error": "Exit code 130\nerror: interrupted",
  "is_interrupt": true,
  "duration_ms": 50
}')"

LOG7="$TMPDIR_TEST/t7/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t7" bash "$HOOK" <<< "$PAYLOAD7"

[[ ! -f "$LOG7" ]] \
  || err "Test 7: log file was created for is_interrupt=true (should be a no-op)"

# ---------------------------------------------------------------------------
# Test 8: real-shape stderr with NO error keyword -> must NOT abort under
# set -e (regression guard for log-failure.sh's grep exiting non-zero on no
# match) and must still be recorded via the first-line fallback
# ---------------------------------------------------------------------------

PAYLOAD8="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_name": "Bash",
  "tool_input": {"command": "some-typo-cmd", "description": "typo"},
  "error": "Exit code 127\nbash: some-typo-cmd: command not found",
  "is_interrupt": false,
  "duration_ms": 12
}')"

LOG8="$TMPDIR_TEST/t8/.claude/failure-log.jsonl"
exit_8=0
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t8" bash "$HOOK" <<< "$PAYLOAD8" || exit_8=$?

[[ $exit_8 -eq 0 ]] \
  || err "Test 8: hook aborted (exit $exit_8) instead of recording via first-line fallback"

if [[ ! -f "$LOG8" ]]; then
  err "Test 8: log file not created at $(basename "$LOG8")"
else
  RECORD8="$(tail -1 "$LOG8")"

  # No line matches the error-keyword regex, so log-failure.sh's fallback
  # picks the literal first line of the blob ("Exit code 127"), not the
  # "command not found" line below it. The regression this guards against is
  # the grep-induced set -e abort, not which line wins.
  ERROR8="$(printf '%s' "$RECORD8" | jq -r '.error')"
  [[ "$ERROR8" == "Exit code 127" ]] \
    || err "Test 8 [error, first-line fallback]: expected 'Exit code 127', got '$ERROR8'"

  EXIT_CODE8="$(printf '%s' "$RECORD8" | jq -r '.exit_code')"
  [[ "$EXIT_CODE8" == "127" ]] \
    || err "Test 8 [exit_code, parsed from 'Exit code N']: expected 127, got '$EXIT_CODE8'"
fi

# ---------------------------------------------------------------------------
# Test 9: PostToolUse + result object WITH a non-zero exit_code -> recorded
# ---------------------------------------------------------------------------

PAYLOAD9="$(jq -nc '{
  "hook_event_name": "PostToolUse",
  "tool_input": {"command": "tsc --noEmit"},
  "tool_output": {
    "exit_code": 1,
    "stdout": "",
    "stderr": "error TS2322: Type mismatch"
  }
}')"

LOG9="$TMPDIR_TEST/t9/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t9" bash "$HOOK" <<< "$PAYLOAD9"

if [[ ! -f "$LOG9" ]]; then
  err "Test 9: log file not created at $(basename "$LOG9") — PostToolUse defensive branch did not fire"
else
  RECORD9="$(tail -1 "$LOG9")"

  EXIT_CODE9="$(printf '%s' "$RECORD9" | jq -r '.exit_code')"
  [[ "$EXIT_CODE9" == "1" ]] \
    || err "Test 9 [exit_code]: expected 1, got '$EXIT_CODE9'"

  CATEGORY9="$(printf '%s' "$RECORD9" | jq -r '.category')"
  [[ "$CATEGORY9" == "check-types" ]] \
    || err "Test 9 [category]: expected 'check-types', got '$CATEGORY9'"
fi

# ---------------------------------------------------------------------------
# Test 10: cmd with an inline secret -> recorded cmd is redacted, error/
# category classification unaffected
# ---------------------------------------------------------------------------

PAYLOAD10="$(jq -nc '{
  "hook_event_name": "PostToolUseFailure",
  "tool_input": {"command": "API_KEY=sk-abc123 bun run deploy"},
  "tool_output": {
    "exit_code": 1,
    "stdout": "",
    "stderr": "error: deploy failed"
  }
}')"

LOG10="$TMPDIR_TEST/t10/.claude/failure-log.jsonl"
CLAUDE_PROJECT_DIR="$TMPDIR_TEST/t10" bash "$HOOK" <<< "$PAYLOAD10"

if [[ ! -f "$LOG10" ]]; then
  err "Test 10: log file not created at $(basename "$LOG10")"
else
  RECORD10="$(tail -1 "$LOG10")"

  CMD10="$(printf '%s' "$RECORD10" | jq -r '.cmd')"
  [[ "$CMD10" != *"sk-abc123"* ]] \
    || err "Test 10 [redaction]: secret value leaked into cmd: '$CMD10'"
  [[ "$CMD10" == *"[REDACTED]"* ]] \
    || err "Test 10 [redaction]: expected '[REDACTED]' placeholder, got '$CMD10'"

  ERROR10="$(printf '%s' "$RECORD10" | jq -r '.error')"
  [[ "$ERROR10" == *"deploy failed"* ]] \
    || err "Test 10 [error, unaffected]: expected stderr content, got '$ERROR10'"

  CATEGORY10="$(printf '%s' "$RECORD10" | jq -r '.category')"
  [[ "$CATEGORY10" == "unknown" ]] \
    || err "Test 10 [category, unaffected]: expected 'unknown', got '$CATEGORY10'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-log-bash-failure: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-log-bash-failure: all tests pass"
