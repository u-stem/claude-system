#!/usr/bin/env bash
# notify-stop-failure.sh — StopFailure — alert the operator when a turn ends
# abnormally (API error / unrecoverable tool-call parse failure).
#
# Why: the "tool call could not be parsed (retry also failed)" abort is an
# upstream model/serving bug (anthropics/claude-code #61133, #63875). It ends
# the turn as an API error, which fires StopFailure (NOT Stop). Claude cannot
# self-recover in-band, and StopFailure output is ignored by Claude Code, so we
# cannot inject a "continue". The only useful action here is a side effect:
# surface a desktop notification so the operator stops babysitting the session
# and can resume it immediately. See meta/decisions/0014-*.
#
# Contract reminder: StopFailure ignores stdout/exit code. Keep this fast
# (<1s), fail open, side-effects only.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"

# Best-effort context extraction (payload schema is not guaranteed stable).
cwd="$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)"
[[ -z "$cwd" ]] && cwd="${PROJECT_ROOT:-$PWD}"
proj="$(basename "$cwd" 2>/dev/null || echo session)"

hk_log notify-stop-failure "turn aborted (StopFailure) in $cwd"

# macOS desktop notification. Guard on osascript so non-macOS / headless runs
# (e.g. cron, CI) degrade to log-only instead of erroring.
if command -v osascript >/dev/null 2>&1; then
  title="Claude Code 停止"
  subtitle="$proj — ターン異常終了"
  body="parse error 等でターンが中断しました。「続けて」で再開してください。"
  # Escape double quotes for the AppleScript string literals.
  esc() { printf '%s' "$1" | sed 's/"/\\"/g'; }
  osascript \
    -e "display notification \"$(esc "$body")\" with title \"$(esc "$title")\" subtitle \"$(esc "$subtitle")\" sound name \"Basso\"" \
    >/dev/null 2>&1 || hk_log notify-stop-failure "osascript notification failed (non-fatal)"
fi

exit 0
