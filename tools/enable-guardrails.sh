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
  tools/enable-guardrails.sh --dry-run     Print what would be restored, touch nothing
  tools/enable-guardrails.sh --help
EOF
}

cs_show_help_if_requested "${1:-}"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

SETTINGS="$HOME/.claude/settings.json"

# shellcheck disable=SC2012
latest="$(ls -t "$CS_BACKUP_ROOT"/settings.json.backup-* 2>/dev/null | head -1 || true)"
if [[ -z "$latest" ]]; then
  cs_error "No settings.json backup found in $CS_BACKUP_ROOT"
  exit 1
fi

# Reported before the confirmation prompt so --dry-run stays non-interactive:
# cs_confirm returns "no" on a non-tty, which would otherwise make a dry run
# indistinguishable from a declined one.
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "would restore: $latest -> $SETTINGS"
  if [[ -f "$SETTINGS" ]]; then
    cs_info "would back up the current file first: $(cs_backup_path_for "$SETTINGS")"
  else
    cs_info "no current $SETTINGS to back up"
  fi
  exit 0
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
