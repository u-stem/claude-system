#!/usr/bin/env bash
# tools/disable-guardrails.sh — emergency switch to neutralize hooks in
# ~/.claude/settings.json (Phase 10+). Pre-Phase 10 it operates on whatever
# settings.json is currently active.
#
# Strategy: read settings.json, blank out the `hooks` section to {}, write
# back to settings.json after taking a backup.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
disable-guardrails.sh — wipe the hooks section of ~/.claude/settings.json.

Usage:
  tools/disable-guardrails.sh
  tools/disable-guardrails.sh --help

A timestamped backup of the original settings.json is placed under
~/.claude-system-backups/. Re-enable with tools/enable-guardrails.sh.
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_macos
cs_ensure_backup_dir

SETTINGS="$HOME/.claude/settings.json"
if [[ ! -f "$SETTINGS" ]]; then
  cs_error "$SETTINGS not found. Nothing to disable."
  exit 1
fi
cs_require_cmd jq

bk="$(cs_backup_path_for "$SETTINGS")"
cp "$SETTINGS" "$bk"
cs_success "Backed up: $bk"

# Capture the timestamp into a variable and pass it to jq via --arg so that
# odd characters in the date output (none expected, but defence-in-depth)
# cannot break the jq filter, and so the quoting is one level deep instead
# of three.
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$(mktemp)"
jq --arg ts "$ts" \
  '.hooks = {} | ."// hooks-disabled-by" = ("tools/disable-guardrails.sh on " + $ts)' \
  "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"
cs_success "Hooks disabled. Restore with tools/enable-guardrails.sh"
