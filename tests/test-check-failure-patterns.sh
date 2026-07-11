#!/usr/bin/env bash
# tests/test-check-failure-patterns.sh — behavioral unit tests for the
# check-failure-patterns hook (SessionStart) and a smoke test of
# tools/loop-report.sh over the same fixture shape.
#
# Verifies:
#   - fewer than 3 failure-log lines total -> no output (silent)
#   - a category with >=3 occurrences -> notification with category + count
#   - notification points at archiving (failure-log.archive) + loop-report.sh,
#     and no longer suggests `rm`-ing the log
#   - loop-report.sh smoke test: live + archive merge, and --since filtering
#
# Fixture: synthetic JSONL logs in a mktemp directory. No real logs are used.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/check-failure-patterns.sh"
LOOP_REPORT="$CS_ROOT/tools/loop-report.sh"

if [[ ! -x "$HOOK" ]]; then
  cs_error "hook not found or not executable: $HOOK"
  exit 1
fi

if [[ ! -x "$LOOP_REPORT" ]]; then
  cs_error "loop-report.sh not found or not executable: $LOOP_REPORT"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Test 1: fewer than 3 lines total -> silent (no output)
# ---------------------------------------------------------------------------

PROJ1="$TMPDIR_TEST/t1"
mkdir -p "$PROJ1/.claude"
LOG1="$PROJ1/.claude/failure-log.jsonl"
printf '{"ts":"2026-07-01T00:00:00Z","category":"check","error":"e1"}\n' > "$LOG1"
printf '{"ts":"2026-07-01T00:00:01Z","category":"check","error":"e2"}\n' >> "$LOG1"

OUT1="$(CLAUDE_PROJECT_DIR="$PROJ1" bash "$HOOK")"
[[ -z "$OUT1" ]] \
  || err "Test 1 [silent below threshold]: expected no output, got: $OUT1"

# ---------------------------------------------------------------------------
# Test 2: a category with >=3 occurrences -> notification with category + count
# ---------------------------------------------------------------------------

PROJ2="$TMPDIR_TEST/t2"
mkdir -p "$PROJ2/.claude"
LOG2="$PROJ2/.claude/failure-log.jsonl"
{
  printf '{"ts":"2026-07-01T00:00:00Z","category":"check","error":"e1"}\n'
  printf '{"ts":"2026-07-01T00:00:01Z","category":"check","error":"e2"}\n'
  printf '{"ts":"2026-07-01T00:00:02Z","category":"check","error":"e3"}\n'
} > "$LOG2"

OUT2="$(CLAUDE_PROJECT_DIR="$PROJ2" bash "$HOOK")"

[[ -n "$OUT2" ]] \
  || err "Test 2 [notification fires]: expected output, got none"

printf '%s' "$OUT2" | grep -q '\[check\] 3 failures' \
  || err "Test 2 [category+count]: expected '[check] 3 failures' in output, got: $OUT2"

# ---------------------------------------------------------------------------
# Test 3: notification text points at archive-failure-log.sh + loop-report.sh,
# not a raw mkdir+mv/rm one-liner
# ---------------------------------------------------------------------------

printf '%s' "$OUT2" | grep -q 'tools/archive-failure-log.sh' \
  || err "Test 3 [archive hint]: expected 'tools/archive-failure-log.sh' mentioned, got: $OUT2"

printf '%s' "$OUT2" | grep -q 'loop-report.sh' \
  || err "Test 3 [loop-report hint]: expected 'loop-report.sh' mentioned, got: $OUT2"

printf '%s' "$OUT2" | grep -q '^rm ' \
  && err "Test 3 [no rm]: expected no bare 'rm' advice, got: $OUT2"

printf '%s' "$OUT2" | grep -q 'mkdir -p' \
  && err "Test 3 [no raw mkdir+mv]: expected no raw 'mkdir -p ... && mv' advice, got: $OUT2"

# ---------------------------------------------------------------------------
# Test 4: loop-report.sh smoke test — live + archive merge, --since filtering
# ---------------------------------------------------------------------------

PROJ4="$TMPDIR_TEST/t4"
mkdir -p "$PROJ4/.claude/failure-log.archive"

LOG4="$PROJ4/.claude/failure-log.jsonl"
{
  printf '{"ts":"2026-07-05T00:00:00Z","category":"check","error":"live e1"}\n'
  printf '{"ts":"2026-07-06T00:00:00Z","category":"check","error":"live e2"}\n'
} > "$LOG4"

ARCHIVE4="$PROJ4/.claude/failure-log.archive/2026-06.jsonl"
{
  printf '{"ts":"2026-06-01T00:00:00Z","category":"test","error":"old e1"}\n'
  printf '{"ts":"2026-06-02T00:00:00Z","category":"check","error":"old e2"}\n'
} > "$ARCHIVE4"

SUBLOG4="$PROJ4/.claude/subagent-log.jsonl"
{
  printf '{"ts":"2026-06-15T00:00:00Z","agent_type":"","model":"x","exit_code":0}\n'
  printf '{"ts":"2026-07-05T00:00:00Z","agent_type":"explorer","model":"","exit_code":1}\n'
} > "$SUBLOG4"

REPORT4="$(bash "$LOOP_REPORT" --project "$PROJ4")"

# live (2) + archive (2) merged = 4 total failure-log records
printf '%s' "$REPORT4" | grep -q 'total: 4' \
  || err "Test 4 [live+archive merge count]: expected 'total: 4' in failure-log section"

# empty agent_type / model rate is surfaced (1 of 2 each in this fixture)
printf '%s' "$REPORT4" | grep -q 'empty agent_type rate: 1/2' \
  || err "Test 4 [empty agent_type rate]: expected 'empty agent_type rate: 1/2' in output"

printf '%s' "$REPORT4" | grep -q 'empty model rate: 1/2' \
  || err "Test 4 [empty model rate]: expected 'empty model rate: 1/2' in output"

REPORT4_SINCE="$(bash "$LOOP_REPORT" --project "$PROJ4" --since 2026-07-01)"

# --since excludes the two 2026-06 records, leaving only the 2 live records
printf '%s' "$REPORT4_SINCE" | grep -q 'total: 2' \
  || err "Test 4 [--since excludes older records]: expected 'total: 2' in failure-log section"

printf '%s' "$REPORT4_SINCE" | grep -q 'old e1' \
  && err "Test 4 [--since excludes older records]: unexpectedly found archived record 'old e1'"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-check-failure-patterns: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-check-failure-patterns: all tests pass"
