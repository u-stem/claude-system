#!/usr/bin/env bash
# stop-session-doctor.sh — Stop — record session-end diagnostic.
# Does NOT run the full doctor.sh (too slow for the stop budget); only flags
# whether the most recent doctor run completed cleanly.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# Append a stop marker to the hook log.
hk_log stop-session-doctor "session stop ($(uname -n))"

# If the project has a doctor.sh shortcut, opportunistically run it but cap to
# 10 seconds so it never blocks the stop event meaningfully. Failures only log.
DOCTOR="$CS_ROOT/tools/doctor.sh"
if [[ -x "$DOCTOR" ]]; then
  out_file="$HOOK_LOG_DIR/last-doctor.log"
  mkdir -p "$HOOK_LOG_DIR"
  # Background the doctor run with a timeout so we don't slow down session stop.
  # --fast drops shellcheck and the delegated test suite (~85% of the runtime).
  # Those are pre-commit concerns that CI already gates; what belongs here is
  # live-machine drift (symlinks, settings sync, plugin parity, secrets). The
  # full run measured 6.10s against this 10s CPU ulimit — 61% of the cap, and an
  # overrun truncates $out_file silently. See tools/doctor.sh --help (ADR 0023).
  ( ulimit -t 10 2>/dev/null || true; "$DOCTOR" --fast >"$out_file" 2>&1 ) &
fi

exit 0
