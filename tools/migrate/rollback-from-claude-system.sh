#!/usr/bin/env bash
# Rollback ~/.claude/ from claude-system back to the previous state.
#
# Behavior:
#   - Finds the most recent migration-<TIMESTAMP>/ backup under
#     ~/.claude-system-backups/.
#   - Restores ~/.claude/ from that backup, replacing whatever is currently
#     there (after a final safety backup).
#   - Verifies via tools/doctor.sh.
#
# Usage:
#   tools/migrate/rollback-from-claude-system.sh [--dry-run] [--backup <path>]
#   tools/migrate/rollback-from-claude-system.sh --help
#
# By default the script picks the newest migration-* directory. Use --backup
# to specify an older one explicitly.

set -euo pipefail

# shellcheck source=../_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../_lib.sh"

cs_print_help() {
  cat <<'EOF'
rollback-from-claude-system.sh — restore ~/.claude/ from a migration backup.

Usage:
  tools/migrate/rollback-from-claude-system.sh
  tools/migrate/rollback-from-claude-system.sh --dry-run
  tools/migrate/rollback-from-claude-system.sh --backup <path-to-backup>
  tools/migrate/rollback-from-claude-system.sh --help

The script picks the newest migration-* directory under
~/.claude-system-backups/ unless --backup is provided.
EOF
}

cs_show_help_if_requested "${1:-}"

DRY_RUN=0
EXPLICIT_BACKUP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --backup)  EXPLICIT_BACKUP="${2:-}"; shift 2 ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

cs_require_macos
cs_require_root_dir

cs_acquire_lock migrate >/dev/null
trap 'cs_release_lock migrate' EXIT

cs_ensure_backup_dir

CLAUDE_HOME="$HOME/.claude"

# ---------------------------------------------------------------------------
# 1. Find backup
# ---------------------------------------------------------------------------
cs_step "Step 1: Locating backup..."
if [[ -n "$EXPLICIT_BACKUP" ]]; then
  BACKUP="$EXPLICIT_BACKUP"
  if [[ ! -d "$BACKUP" ]]; then
    cs_error "Specified backup not found: $BACKUP"
    exit 1
  fi
else
  # Find newest migration-* directory.
  BACKUP="$(find "$CS_BACKUP_ROOT" -maxdepth 1 -type d -name 'migration-*' 2>/dev/null \
            | sort | tail -1)"
  if [[ -z "$BACKUP" ]]; then
    cs_error "No migration-* backup found under $CS_BACKUP_ROOT"
    cs_error "Use --backup <path> to specify one explicitly."
    exit 1
  fi
fi

cs_info "  Backup: $BACKUP"

# Inspect kind
KIND_FILE="$BACKUP/_kind.txt"
if [[ ! -f "$KIND_FILE" ]]; then
  cs_error "Backup missing _kind.txt: $BACKUP (was it created by from-claude-settings.sh?)"
  exit 1
fi
KIND="$(head -1 "$KIND_FILE")"
cs_info "  Backup kind: $KIND"

# ---------------------------------------------------------------------------
# 2. Confirm with user
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "0" ]]; then
  cs_step "Step 2: Confirmation"
  cs_warn "This will:"
  cs_warn "  - Save current ~/.claude/ to a safety backup under $CS_BACKUP_ROOT"
  cs_warn "  - Remove current ~/.claude/"
  cs_warn "  - Restore from $BACKUP"
  if ! cs_confirm "Proceed with rollback"; then
    cs_info "Aborted by user. No changes made."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 3. Save current state
# ---------------------------------------------------------------------------
cs_step "Step 3: Saving current ~/.claude/ as safety backup..."
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SAFETY_DIR="$CS_BACKUP_ROOT/rollback-safety-${TIMESTAMP}"

if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would save current state to $SAFETY_DIR"
else
  mkdir -p "$SAFETY_DIR"
  if [[ -L "$CLAUDE_HOME" ]]; then
    cp -L -R "$CLAUDE_HOME" "$SAFETY_DIR/dot-claude-resolved"
    printf 'symlink\n%s\n' "$(readlink "$CLAUDE_HOME")" > "$SAFETY_DIR/_kind.txt"
  elif [[ -d "$CLAUDE_HOME" ]]; then
    cp -R "$CLAUDE_HOME" "$SAFETY_DIR/dot-claude-direct"
    printf 'directory\n' > "$SAFETY_DIR/_kind.txt"
  else
    printf 'missing\n' > "$SAFETY_DIR/_kind.txt"
  fi
  cs_success "  Safety backup: $SAFETY_DIR"
fi

# ---------------------------------------------------------------------------
# 4. Remove current ~/.claude/
# ---------------------------------------------------------------------------
cs_step "Step 4: Removing current ~/.claude/..."
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would remove $CLAUDE_HOME"
else
  if [[ -L "$CLAUDE_HOME" ]]; then
    rm "$CLAUDE_HOME"
  elif [[ -d "$CLAUDE_HOME" ]]; then
    rm -rf "$CLAUDE_HOME"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Restore from backup
# ---------------------------------------------------------------------------
cs_step "Step 5: Restoring from backup..."
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would restore $BACKUP into $CLAUDE_HOME (kind: $KIND)"
else
  case "$KIND" in
    symlink)
      # Recreate as a directory copy of the resolved target.
      # The original was a symlink; we restore the resolved contents as a
      # plain directory because we cannot reliably know the original target
      # still exists. Users who want to re-establish a symlink can do so
      # manually after rollback.
      if [[ -d "$BACKUP/dot-claude-resolved" ]]; then
        cp -R "$BACKUP/dot-claude-resolved" "$CLAUDE_HOME"
      else
        cs_error "Backup missing dot-claude-resolved/"
        exit 1
      fi
      ;;
    directory)
      if [[ -d "$BACKUP/dot-claude-direct" ]]; then
        cp -R "$BACKUP/dot-claude-direct" "$CLAUDE_HOME"
      else
        cs_error "Backup missing dot-claude-direct/"
        exit 1
      fi
      ;;
    missing)
      cs_warn "  Backup recorded ~/.claude/ as missing. Leaving it absent."
      ;;
    *)
      cs_error "Unknown backup kind: $KIND"
      exit 1
      ;;
  esac
  cs_success "  Restored from $BACKUP"
fi

# ---------------------------------------------------------------------------
# 6. Verification
# ---------------------------------------------------------------------------
cs_step "Step 6: Verification"
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would invoke tools/doctor.sh"
else
  if [[ -L "$CLAUDE_HOME" ]]; then
    cs_info "  ~/.claude is now a symlink: $(readlink "$CLAUDE_HOME")"
  elif [[ -d "$CLAUDE_HOME" ]]; then
    cs_info "  ~/.claude is now a directory"
  else
    cs_info "  ~/.claude does not exist"
  fi
  if "$CS_ROOT/tools/doctor.sh" >/dev/null 2>&1; then
    cs_success "  doctor.sh: clean"
  else
    cs_warn "  doctor.sh reported issues (expected if ~/.claude/ is back to old layout)"
  fi
fi

echo
if [[ "$DRY_RUN" == "1" ]]; then
  cs_step "Dry-run complete. No changes applied."
else
  cs_step "Rollback complete."
  cs_info "  Restored from: $BACKUP"
  cs_info "  Safety backup of pre-rollback state: $SAFETY_DIR"
fi
