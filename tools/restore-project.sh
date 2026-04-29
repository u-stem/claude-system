#!/usr/bin/env bash
# tools/restore-project.sh — restore a project's CLAUDE.md from backup.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
restore-project.sh — restore CLAUDE.md from a specific backup.

Usage:
  tools/restore-project.sh <project-path>                  Latest backup for this project
  tools/restore-project.sh <project-path> <timestamp>      Specific timestamp
  tools/restore-project.sh --help

Project-scoped backup naming (Phase 9+):
  ~/.claude-system-backups/<project>-CLAUDE.md.backup-<YYYYMMDD-HHMMSS>

Legacy basename-only naming is detected but only used when explicitly given a
timestamp (the script will not auto-pick a legacy backup since attribution to
the requested project cannot be verified).
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  cs_error "Usage: tools/restore-project.sh <project-path> [<timestamp>]"
  exit 2
fi

PROJ_PATH="$(cd "$1" && pwd)"
PROJ_NAME="$(basename "$PROJ_PATH")"
TS="${2:-}"

if [[ -n "$TS" ]]; then
  # Try project-scoped first, fall back to legacy basename-only.
  candidate="$CS_BACKUP_ROOT/${PROJ_NAME}-CLAUDE.md.backup-$TS"
  if [[ ! -f "$candidate" ]]; then
    legacy="$CS_BACKUP_ROOT/CLAUDE.md.backup-$TS"
    if [[ -f "$legacy" ]]; then
      cs_warn "Using legacy (un-attributed) backup: $legacy"
      candidate="$legacy"
    else
      cs_error "Backup not found: $candidate (also tried $legacy)"
      cs_info "Available project-scoped:"
      ls "$CS_BACKUP_ROOT/${PROJ_NAME}-CLAUDE.md.backup-"* 2>/dev/null || cs_warn "  (none)"
      cs_info "Available legacy (basename-only, un-attributed):"
      ls "$CS_BACKUP_ROOT/CLAUDE.md.backup-"* 2>/dev/null || cs_warn "  (none)"
      exit 2
    fi
  fi
else
  candidate="$(ls -t "$CS_BACKUP_ROOT/${PROJ_NAME}-CLAUDE.md.backup-"* 2>/dev/null | head -1 || true)"
  if [[ -z "$candidate" ]]; then
    cs_error "No project-scoped backups found for '$PROJ_NAME' in $CS_BACKUP_ROOT"
    cs_info "Pass an explicit <timestamp> to use a legacy un-attributed backup."
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
