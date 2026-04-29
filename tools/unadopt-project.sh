#!/usr/bin/env bash
# tools/unadopt-project.sh — undo adoption of a project.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
unadopt-project.sh — undo adoption.

Usage:
  tools/unadopt-project.sh <project-path>
  tools/unadopt-project.sh --help

Steps:
  1. Restore the most recent CLAUDE.md backup from ~/.claude-system-backups/.
  2. Remove $CS_ROOT/projects/<name>/.
  3. Append a one-line entry to meta/migration-inventory.md.
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -ne 1 ]]; then
  cs_error "Usage: tools/unadopt-project.sh <project-path>"
  exit 2
fi

cs_require_macos
cs_require_root_dir

PROJ_PATH="$(cd "$1" && pwd)"
PROJ_NAME="$(basename "$PROJ_PATH")"

cs_step "Unadopting: $PROJ_NAME"

# 1. Find latest backup scoped to *this* project.
# Look for the new project-prefixed naming first; fall back to the legacy
# basename-only naming for backups created before Phase 9.
latest="$(ls -t "$CS_BACKUP_ROOT/${PROJ_NAME}-CLAUDE.md.backup-"* 2>/dev/null | head -1 || true)"
if [[ -z "$latest" ]]; then
  cs_warn "No project-scoped CLAUDE.md backup found in $CS_BACKUP_ROOT"
  cs_info "Legacy basename-only backups exist in $CS_BACKUP_ROOT (CLAUDE.md.backup-*) but cannot be auto-attributed to this project."
  cs_info "Use restore-project.sh with an explicit timestamp if you have one, or pass the path manually."
else
  if cs_confirm "Restore CLAUDE.md from $latest?"; then
    cp "$latest" "$PROJ_PATH/CLAUDE.md"
    cs_success "Restored $PROJ_PATH/CLAUDE.md"
  else
    cs_info "Skipping CLAUDE.md restore."
  fi
fi

# 2. Remove projects/<name>/
PROJECTS_ENTRY="$CS_ROOT/projects/$PROJ_NAME"
if [[ -d "$PROJECTS_ENTRY" ]]; then
  if cs_confirm "Remove $PROJECTS_ENTRY?"; then
    rm -rf "$PROJECTS_ENTRY"
    cs_success "Removed $PROJECTS_ENTRY"
  fi
fi

# 3. Append to migration-inventory.md
INV="$CS_ROOT/meta/migration-inventory.md"
if [[ -f "$INV" ]]; then
  {
    echo
    echo "- $(date +%Y-%m-%d): unadopted \`$PROJ_NAME\` (path: $PROJ_PATH)"
  } >> "$INV"
  cs_info "Logged to $INV"
fi

cs_step "Done"
cs_success "Unadoption complete."
