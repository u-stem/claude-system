#!/usr/bin/env bash
# session-start-doctor.sh — SessionStart — surface the previous doctor run's
# WARN/ERROR lines, then kick off a fresh doctor.sh --fast run in the
# background for the *next* session to read.
#
# Replaces stop-session-doctor.sh (ADR 0030). That hook ran doctor.sh --fast
# on every Stop event (~1s, ~150 forks per turn) and wrote last-doctor.log,
# but nothing ever read it — the cost was paid every turn for a result no one
# saw. Moving the run to SessionStart (once per session, not once per turn)
# and actually printing the previous result closes that gap.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

mkdir -p "$HOOK_LOG_DIR"

PREV_LOG="$HOOK_LOG_DIR/last-doctor.log"

# ---------------------------------------------------------------------------
# 1. Surface the previous run's WARN/ERROR lines (if any).
# ---------------------------------------------------------------------------
# SessionStart hook stdout is injected into the model's context, so a quiet
# previous run (or no previous run at all) must print nothing.
if [[ -f "$PREV_LOG" ]]; then
  hits="$(/usr/bin/grep -E '\[(WARN|ERROR)\]' "$PREV_LOG" 2>/dev/null | head -20 || true)"
  if [[ -n "$hits" ]]; then
    warn_count="$(printf '%s\n' "$hits" | /usr/bin/grep -c '\[WARN\]' || true)"
    error_count="$(printf '%s\n' "$hits" | /usr/bin/grep -c '\[ERROR\]' || true)"
    mtime="$(date -u -r "$PREV_LOG" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
    printf 'claude-system doctor (previous run, %s): %s warn / %s error\n' \
      "$mtime" "$warn_count" "$error_count"
    printf '%s\n' "$hits"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Kick off a fresh doctor.sh --fast run in the background.
# ---------------------------------------------------------------------------
# SESSION_START_DOCTOR_BIN lets tests substitute a stub; production uses the
# real tools/doctor.sh.
DOCTOR="${SESSION_START_DOCTOR_BIN:-$CS_ROOT/tools/doctor.sh}"
if [[ -x "$DOCTOR" ]]; then
  tmp="$(mktemp "$HOOK_LOG_DIR/last-doctor.log.tmp.XXXXXX")"
  # Write straight into $tmp: even if ulimit -t kills the run mid-flight, the
  # output already flushed to disk survives, so the next session sees a
  # partial run instead of nothing. Cap taken from stop-session-doctor.sh's
  # measurement (ADR 0023): the full run measured 6.10s against this 10s CPU
  # ulimit, --fast is well inside it.
  (
    ulimit -t 10 2>/dev/null || true
    if "$DOCTOR" --fast >"$tmp" 2>&1; then
      mv "$tmp" "$PREV_LOG"
      date -u +%Y-%m-%dT%H:%M:%SZ > "$HOOK_LOG_DIR/last-doctor.ok"
    else
      mv "$tmp" "$PREV_LOG"
    fi
  ) &
fi

# ---------------------------------------------------------------------------
# 3. Append a session-start marker, capped to the last 500 lines.
# ---------------------------------------------------------------------------
hk_log session-start-doctor "session start ($(uname -n))"

self_log="$HOOK_LOG_DIR/session-start-doctor.log"
if [[ -f "$self_log" ]]; then
  lines="$(wc -l < "$self_log" | tr -d '[:space:]')"
  if [[ "$lines" -gt 500 ]]; then
    tmp_log="$(mktemp)"
    tail -n 500 "$self_log" > "$tmp_log" && mv "$tmp_log" "$self_log"
  fi
fi

exit 0
