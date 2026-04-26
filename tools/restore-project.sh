#!/usr/bin/env bash
# tools/restore-project.sh — restore a project's CLAUDE.md from backup.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
restore-project.sh — restore CLAUDE.md from a specific backup.

Usage:
  tools/restore-project.sh <project-path>                  Latest backup
  tools/restore-project.sh <project-path> <timestamp>      Specific backup
  tools/restore-project.sh --help

Backup files live under ~/.claude-system-backups/CLAUDE.md.backup-<YYYYMMDD-HHMMSS>.
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  cs_error "Usage: tools/restore-project.sh <project-path> [<timestamp>]"
  exit 2
fi

PROJ_PATH="$(cd "$1" && pwd)"
TS="${2:-}"

if [[ -n "$TS" ]]; then
  candidate="$CS_BACKUP_ROOT/CLAUDE.md.backup-$TS"
  if [[ ! -f "$candidate" ]]; then
    cs_error "Backup not found: $candidate"
    cs_info "Available:"
    ls "$CS_BACKUP_ROOT"/CLAUDE.md.backup-* 2>/dev/null || cs_warn "  (none)"
    exit 2
  fi
else
  candidate="$(ls -t "$CS_BACKUP_ROOT"/CLAUDE.md.backup-* 2>/dev/null | head -1 || true)"
  if [[ -z "$candidate" ]]; then
    cs_error "No backups found in $CS_BACKUP_ROOT"
    exit 2
  fi
fi

cs_info "Restoring: $candidate -> $PROJ_PATH/CLAUDE.md"
if cs_confirm "Proceed?"; then
  if [[ -f "$PROJ_PATH/CLAUDE.md" ]]; then
    bk="$(cs_backup_path_for "$PROJ_PATH/CLAUDE.md")"
    cp "$PROJ_PATH/CLAUDE.md" "$bk"
    cs_info "Existing backed up to $bk"
  fi
  cp "$candidate" "$PROJ_PATH/CLAUDE.md"
  cs_success "Restored."
else
  cs_info "Cancelled."
fi
