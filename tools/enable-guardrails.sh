#!/usr/bin/env bash
# tools/enable-guardrails.sh — restore the most recent ~/.claude/settings.json
# backup taken by disable-guardrails.sh.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
enable-guardrails.sh — restore ~/.claude/settings.json from the most recent
backup taken by disable-guardrails.sh.

Usage:
  tools/enable-guardrails.sh
  tools/enable-guardrails.sh --help
EOF
}

cs_show_help_if_requested "${1:-}"

SETTINGS="$HOME/.claude/settings.json"

# shellcheck disable=SC2012
latest="$(ls -t "$CS_BACKUP_ROOT"/settings.json.backup-* 2>/dev/null | head -1 || true)"
if [[ -z "$latest" ]]; then
  cs_error "No settings.json backup found in $CS_BACKUP_ROOT"
  exit 1
fi

cs_info "Restore: $latest -> $SETTINGS"
if cs_confirm "Proceed?"; then
  if [[ -f "$SETTINGS" ]]; then
    bk="$(cs_backup_path_for "$SETTINGS")"
    cp "$SETTINGS" "$bk"
    cs_info "Pre-restore backup: $bk"
  fi
  cp "$latest" "$SETTINGS"
  cs_success "Restored. Run tools/doctor.sh to verify."
else
  cs_info "Cancelled."
fi
