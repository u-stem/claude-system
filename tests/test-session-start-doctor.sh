#!/usr/bin/env bash
# tests/test-session-start-doctor.sh — behavioral unit tests for the
# session-start-doctor hook (SessionStart), which replaced
# stop-session-doctor.sh (ADR 0030).
#
# Verifies:
#   1. a previous last-doctor.log with WARN lines -> stdout carries a header
#      (count + mtime) followed by those lines
#   2. a previous last-doctor.log with no WARN/ERROR -> silent (no output)
#   3. no previous last-doctor.log at all -> silent, exit 0
#   4. the backgrounded doctor run completes: last-doctor.log is refreshed
#      and last-doctor.ok is stamped
#   5. session-start-doctor.log is capped to the last 500 lines
#
# Fixtures: synthetic hook-log directories under mktemp, addressed via
# CS_BACKUP_ROOT so the real ~/.claude-system-backups is never touched.
# SESSION_START_DOCTOR_BIN substitutes a stub (or a nonexistent path) for
# tools/doctor.sh so tests never run the real, slower doctor.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/session-start-doctor.sh"

if [[ ! -x "$HOOK" ]]; then
  cs_error "hook not found or not executable: $HOOK"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# A path that is guaranteed not to exist, so `[[ -x "$DOCTOR" ]]` is false and
# the hook's background block is skipped entirely. Used by every case that is
# not exercising the background run itself (tests 1, 2, 3, 5).
NO_DOCTOR="$TMPDIR_TEST/no-such-doctor"

# ---------------------------------------------------------------------------
# Test 1: previous log has WARN lines -> header + those lines on stdout
# ---------------------------------------------------------------------------

TMP1="$TMPDIR_TEST/t1"
HOOK_LOG_DIR1="$TMP1/hook-logs"
mkdir -p "$HOOK_LOG_DIR1"
cat > "$HOOK_LOG_DIR1/last-doctor.log" <<'EOF'
[OK] symlink state fine
[WARN] first warning
[OK] frontmatter fine
[WARN] second warning
EOF

OUT1="$(SESSION_START_DOCTOR_BIN="$NO_DOCTOR" CS_BACKUP_ROOT="$TMP1" bash "$HOOK")"

[[ -n "$OUT1" ]] \
  || err "Test 1 [notice fires]: expected output, got none"

printf '%s' "$OUT1" | grep -q '2 warn / 0 error' \
  || err "Test 1 [count]: expected '2 warn / 0 error' in output, got: $OUT1"

printf '%s' "$OUT1" | grep -q 'first warning' \
  || err "Test 1 [line 1 present]: expected 'first warning' in output, got: $OUT1"

printf '%s' "$OUT1" | grep -q 'second warning' \
  || err "Test 1 [line 2 present]: expected 'second warning' in output, got: $OUT1"

printf '%s' "$OUT1" | grep -q 'frontmatter fine' \
  && err "Test 1 [OK lines excluded]: expected OK lines to be filtered out, got: $OUT1"

# ---------------------------------------------------------------------------
# Test 2: previous log has no WARN/ERROR -> silent
# ---------------------------------------------------------------------------

TMP2="$TMPDIR_TEST/t2"
HOOK_LOG_DIR2="$TMP2/hook-logs"
mkdir -p "$HOOK_LOG_DIR2"
cat > "$HOOK_LOG_DIR2/last-doctor.log" <<'EOF'
[OK] all fine
[OK] still fine
EOF

OUT2="$(SESSION_START_DOCTOR_BIN="$NO_DOCTOR" CS_BACKUP_ROOT="$TMP2" bash "$HOOK")"
[[ -z "$OUT2" ]] \
  || err "Test 2 [silent when clean]: expected no output, got: $OUT2"

# ---------------------------------------------------------------------------
# Test 3: no previous log at all -> silent, exit 0
# ---------------------------------------------------------------------------

TMP3="$TMPDIR_TEST/t3"

set +e
OUT3="$(SESSION_START_DOCTOR_BIN="$NO_DOCTOR" CS_BACKUP_ROOT="$TMP3" bash "$HOOK")"
RC3=$?
set -e

[[ -z "$OUT3" ]] \
  || err "Test 3 [silent when no previous log]: expected no output, got: $OUT3"
[[ "$RC3" -eq 0 ]] \
  || err "Test 3 [exit 0]: expected exit 0, got: $RC3"

# ---------------------------------------------------------------------------
# Test 4: the backgrounded doctor run completes -> last-doctor.log refreshed,
# last-doctor.ok stamped
# ---------------------------------------------------------------------------
# The background job is started with `&` inside the hook, which itself exits
# almost immediately (it never waits on its own child) — by the time
# `bash "$HOOK"` below returns, the job is an orphan reparented away from this
# test script, not a direct child of it. bash's `wait` builtin only targets
# direct children, so it cannot observe this job; poll with a bounded timeout
# instead (the stub doctor below returns instantly, so this resolves in well
# under a second in practice).

STUB_DOCTOR="$TMPDIR_TEST/stub-doctor.sh"
cat > "$STUB_DOCTOR" <<'EOF'
#!/usr/bin/env bash
echo "[OK] stub doctor ran"
exit 0
EOF
chmod +x "$STUB_DOCTOR"

TMP4="$TMPDIR_TEST/t4"
HOOK_LOG_DIR4="$TMP4/hook-logs"

SESSION_START_DOCTOR_BIN="$STUB_DOCTOR" CS_BACKUP_ROOT="$TMP4" bash "$HOOK" >/dev/null

OK_FILE4="$HOOK_LOG_DIR4/last-doctor.ok"
waited=0
while [[ ! -f "$OK_FILE4" && "$waited" -lt 30 ]]; do
  sleep 0.1
  waited=$((waited + 1))
done

[[ -f "$OK_FILE4" ]] \
  || err "Test 4 [.ok stamp]: expected $OK_FILE4 to exist after the background run, timed out after 3s"
[[ -f "$HOOK_LOG_DIR4/last-doctor.log" ]] \
  || err "Test 4 [log refreshed]: expected last-doctor.log to exist"
grep -q 'stub doctor ran' "$HOOK_LOG_DIR4/last-doctor.log" 2>/dev/null \
  || err "Test 4 [log content]: expected the stub doctor's output in last-doctor.log"

# ---------------------------------------------------------------------------
# Test 5: session-start-doctor.log is capped to the last 500 lines
# ---------------------------------------------------------------------------

TMP5="$TMPDIR_TEST/t5"
HOOK_LOG_DIR5="$TMP5/hook-logs"
mkdir -p "$HOOK_LOG_DIR5"
SELF_LOG5="$HOOK_LOG_DIR5/session-start-doctor.log"
for i in $(seq 1 500); do
  printf '2020-01-01T00:00:00Z\tpre-existing-line-%d\n' "$i"
done > "$SELF_LOG5"

SESSION_START_DOCTOR_BIN="$NO_DOCTOR" CS_BACKUP_ROOT="$TMP5" bash "$HOOK" >/dev/null

LINES5="$(wc -l < "$SELF_LOG5" | tr -d '[:space:]')"
[[ "$LINES5" -eq 500 ]] \
  || err "Test 5 [capped at 500]: expected 500 lines, got $LINES5"

grep -q 'pre-existing-line-1$' "$SELF_LOG5" \
  && err "Test 5 [oldest dropped]: expected the oldest pre-existing line to have been dropped"

tail -1 "$SELF_LOG5" | grep -q 'session start' \
  || err "Test 5 [newest kept]: expected the hook's own new line to be the last line"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-session-start-doctor: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-session-start-doctor: all tests pass"
