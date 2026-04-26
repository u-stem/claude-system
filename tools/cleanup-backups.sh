#!/usr/bin/env bash
# tools/cleanup-backups.sh — remove old files from ~/.claude-system-backups/.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
cleanup-backups.sh — remove backup files older than N days.

Usage:
  tools/cleanup-backups.sh                  Delete files >30 days old
  tools/cleanup-backups.sh --keep <days>    Override threshold
  tools/cleanup-backups.sh --dry-run        Print targets, don't delete
  tools/cleanup-backups.sh --help
EOF
}

cs_show_help_if_requested "${1:-}"

KEEP_DAYS=30
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP_DAYS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ ! "$KEEP_DAYS" =~ ^[0-9]+$ ]]; then
  cs_error "--keep must be an integer: $KEEP_DAYS"
  exit 2
fi

if [[ ! -d "$CS_BACKUP_ROOT" ]]; then
  cs_info "Nothing to clean: $CS_BACKUP_ROOT does not exist."
  exit 0
fi

cs_step "Cleaning backups older than $KEEP_DAYS days under $CS_BACKUP_ROOT"

# BSD find: -mtime +N
# Use -print0/while for safety with spaces.
count=0
while IFS= read -r -d '' f; do
  count=$((count + 1))
  if [[ "$DRY_RUN" == "1" ]]; then
    cs_info "would delete: $f"
  else
    rm -f "$f"
    cs_success "deleted: $f"
  fi
done < <(find "$CS_BACKUP_ROOT" -type f -mtime +"$KEEP_DAYS" -print0 2>/dev/null)

if [[ $count -eq 0 ]]; then
  cs_info "Nothing to delete (all files are within $KEEP_DAYS days)."
fi
