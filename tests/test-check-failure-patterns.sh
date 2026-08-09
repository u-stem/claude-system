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

# Fixtures must be dated relative to now. The hook only counts failures inside a
# recent window, so the fixed 2026-07 timestamps these tests used originally
# would silently stop matching as real time moved past the window — the test
# would go green by measuring nothing.
ago() { date -u -v-"${1}"d +%Y-%m-%dT%H:%M:%SZ; }

# ---------------------------------------------------------------------------
# Test 1: fewer than 3 lines total -> silent (no output)
# ---------------------------------------------------------------------------

PROJ1="$TMPDIR_TEST/t1"
mkdir -p "$PROJ1/.claude"
LOG1="$PROJ1/.claude/failure-log.jsonl"
printf '{"ts":"%s","category":"check","error":"e1"}\n' "$(ago 1)" > "$LOG1"
printf '{"ts":"%s","category":"check","error":"e2"}\n' "$(ago 1)" >> "$LOG1"

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
  printf '{"ts":"%s","category":"check","error":"e1"}\n' "$(ago 3)"
  printf '{"ts":"%s","category":"check","error":"e2"}\n' "$(ago 2)"
  printf '{"ts":"%s","category":"check","error":"e3"}\n' "$(ago 1)"
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
# Test 3b: the notice states the age of what it is reporting
# ---------------------------------------------------------------------------
# On 2026-08-09 this hook surfaced three "test failures" that were all stale:
# two from a TDD red phase on 2026-07-11 and one from a negative test proving
# the push guard works. Nothing in the output distinguished a replay of old log
# lines from current breakage, and it was read as current breakage. Printing the
# span makes that misreading impossible.

printf '%s' "$OUT2" | grep -qE '\[check\] 3 failures \([0-9]{4}-[0-9]{2}-[0-9]{2}' \
  || err "Test 3b [age shown]: expected the date span alongside the count, got: $OUT2"

# ---------------------------------------------------------------------------
# Test 5: entries older than the window are not counted
# ---------------------------------------------------------------------------

PROJ5="$TMPDIR_TEST/t5"
mkdir -p "$PROJ5/.claude"
LOG5="$PROJ5/.claude/failure-log.jsonl"
{
  printf '{"ts":"%s","category":"test","error":"stale1"}\n' "$(ago 40)"
  printf '{"ts":"%s","category":"test","error":"stale2"}\n' "$(ago 39)"
  printf '{"ts":"%s","category":"test","error":"stale3"}\n' "$(ago 38)"
} > "$LOG5"

OUT5="$(CLAUDE_PROJECT_DIR="$PROJ5" bash "$HOOK")"
[[ -z "$OUT5" ]] \
  || err "Test 5 [window excludes stale]: expected no output for 38-40 day old entries, got: $OUT5"

# The same fixture must fire once the window is widened, proving the entries are
# well-formed and it is genuinely the age that excluded them.
OUT5B="$(CLAUDE_PROJECT_DIR="$PROJ5" CS_FAILURE_WINDOW_DAYS=90 bash "$HOOK")"
printf '%s' "$OUT5B" | grep -q '\[test\] 3 failures' \
  || err "Test 5 [window is the reason]: expected a notice with a 90-day window, got: $OUT5B"

# ---------------------------------------------------------------------------
# Test 6: deliberately caused failures are not counted
# ---------------------------------------------------------------------------
# Negative tests assert that a guard rejects something, which means they produce
# real non-zero exits. Counting those as recurring breakage pollutes the signal
# the loop is supposed to measure.

PROJ6="$TMPDIR_TEST/t6"
mkdir -p "$PROJ6/.claude"
LOG6="$PROJ6/.claude/failure-log.jsonl"
{
  printf '{"ts":"%s","category":"test","error":"neg1","intent":"expected"}\n' "$(ago 3)"
  printf '{"ts":"%s","category":"test","error":"neg2","intent":"expected"}\n' "$(ago 2)"
  printf '{"ts":"%s","category":"test","error":"neg3","intent":"expected"}\n' "$(ago 1)"
} > "$LOG6"

OUT6="$(CLAUDE_PROJECT_DIR="$PROJ6" bash "$HOOK")"
[[ -z "$OUT6" ]] \
  || err "Test 6 [expected failures excluded]: expected no output, got: $OUT6"

# Records without an intent field predate this change and must still count.
PROJ6B="$TMPDIR_TEST/t6b"
mkdir -p "$PROJ6B/.claude"
LOG6B="$PROJ6B/.claude/failure-log.jsonl"
{
  printf '{"ts":"%s","category":"test","error":"legacy1"}\n' "$(ago 3)"
  printf '{"ts":"%s","category":"test","error":"legacy2"}\n' "$(ago 2)"
  printf '{"ts":"%s","category":"test","error":"legacy3"}\n' "$(ago 1)"
} > "$LOG6B"

OUT6B="$(CLAUDE_PROJECT_DIR="$PROJ6B" bash "$HOOK")"
printf '%s' "$OUT6B" | grep -q '\[test\] 3 failures' \
  || err "Test 6b [legacy records still count]: expected a notice, got: $OUT6B"

# ---------------------------------------------------------------------------
# Test 6c: log-failure.sh marks intent from the env and from the command string
# ---------------------------------------------------------------------------
# Both paths are needed. A hook runs in its own process, so an env var the agent
# sets inside its Bash command never reaches it — the command string is the only
# signal available there. The env path covers direct invocation.

LOGGER="$CS_ROOT/adapters/claude-code/user-level/hooks/log-failure.sh"
PROJ6C="$TMPDIR_TEST/t6c"
mkdir -p "$PROJ6C/.claude"

printf 'boom\n' | CLAUDE_PROJECT_DIR="$PROJ6C" bash "$LOGGER" test 1 "bun test" >/dev/null 2>&1
printf 'boom\n' | CLAUDE_PROJECT_DIR="$PROJ6C" CS_EXPECTED_FAILURE=1 bash "$LOGGER" test 1 "bun test" >/dev/null 2>&1
printf 'boom\n' | CLAUDE_PROJECT_DIR="$PROJ6C" bash "$LOGGER" test 1 "CS_EXPECTED_FAILURE=1 bash tests/negative.sh" >/dev/null 2>&1

LOG6C="$PROJ6C/.claude/failure-log.jsonl"
[[ "$(jq -rs 'map(select(.intent == "real")) | length' "$LOG6C")" == "1" ]] \
  || err "Test 6c [default intent]: expected exactly 1 real record, got: $(cat "$LOG6C")"
[[ "$(jq -rs 'map(select(.intent == "expected")) | length' "$LOG6C")" == "2" ]] \
  || err "Test 6c [expected intent]: expected 2 expected records (env + cmd), got: $(cat "$LOG6C")"

# ---------------------------------------------------------------------------
# Test 7: malformed lines do not abort the hook
# ---------------------------------------------------------------------------

PROJ7="$TMPDIR_TEST/t7"
mkdir -p "$PROJ7/.claude"
LOG7="$PROJ7/.claude/failure-log.jsonl"
{
  printf '{"ts":"%s","category":"test","error":"ok1"}\n' "$(ago 3)"
  printf 'not json at all\n'
  printf '{"ts":"%s","category":"test","error":"ok2"}\n' "$(ago 2)"
  printf '{"ts":"%s","category":"test","error":"ok3"}\n' "$(ago 1)"
} > "$LOG7"

OUT7="$(CLAUDE_PROJECT_DIR="$PROJ7" bash "$HOOK" 2>/dev/null || true)"
printf '%s' "$OUT7" | grep -q '\[test\] 3 failures' \
  || err "Test 7 [malformed line tolerated]: expected the 3 valid records counted, got: $OUT7"

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
# One record of each kind the report must keep apart (ADR 0024 §3): a legacy
# record from before agent_type was populated, a harness-internal agent (whose
# empty model is deliberate — its transcript is the main session's), and a real
# delegated agent. Rates must describe only the last kind.
{
  printf '{"ts":"2026-06-15T00:00:00Z","agent_type":"","model":"x","exit_code":0}\n'
  printf '{"ts":"2026-06-20T00:00:00Z","agent_type":"(internal)","model":"","exit_code":0}\n'
  printf '{"ts":"2026-07-05T00:00:00Z","agent_type":"explorer","model":"","effort":"medium","exit_code":1}\n'
} > "$SUBLOG4"

REPORT4="$(bash "$LOOP_REPORT" --project "$PROJ4")"

# live (2) + archive (2) merged = 4 total failure-log records
printf '%s' "$REPORT4" | grep -q 'total: 4' \
  || err "Test 4 [live+archive merge count]: expected 'total: 4' in failure-log section"

# The three kinds are counted separately.
printf '%s' "$REPORT4" | grep -q 'delegated: 1 .*harness-internal: 1 .*legacy-empty: 1' \
  || err "Test 4 [kind split]: expected 'delegated: 1 harness-internal: 1 legacy-empty: 1', got: $REPORT4"

# Rates are computed over delegated records only: 1 of 1 has an empty model.
# Mixing the other two kinds in would report 2/3 and misdescribe the loop.
printf '%s' "$REPORT4" | grep -q 'empty model rate (delegated): 1/1' \
  || err "Test 4 [delegated model rate]: expected 'empty model rate (delegated): 1/1', got: $REPORT4"

# (internal) must not appear in the delegated breakdown.
printf '%s' "$REPORT4" | sed -n '/by agent_type (delegated only)/,/by model/p' | grep -q '(internal)' \
  && err "Test 4 [internal excluded]: '(internal)' leaked into the delegated agent_type breakdown"

# effort distribution is surfaced for delegated agents (ADR 0013 needs this axis)
printf '%s' "$REPORT4" | grep -q 'by effort (delegated only)' \
  || err "Test 4 [effort axis]: expected 'by effort (delegated only)' section, got: $REPORT4"

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
