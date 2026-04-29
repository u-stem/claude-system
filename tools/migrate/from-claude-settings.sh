#!/usr/bin/env bash
# WARNING: This script switches ~/.claude/ from claude-settings to claude-system.
# Run only after Phase 9 verification is complete (Phase 10 execution).
#
# Behavior:
#   - Backs up current ~/.claude/ to ~/.claude-system-backups/migration-<TIMESTAMP>/
#     (preserved permanently — not removed by cleanup-backups.sh).
#   - Removes ~/.claude/.
#   - Recreates ~/.claude/ as a directory with symlinks to claude-system:
#       CLAUDE.md / skills / hooks / commands / agents
#   - Leaves ~/.claude/settings.json for manual placement (template is at
#     adapters/claude-code/user-level/settings.json.template).
#   - Verifies via tools/doctor.sh.
#
# Usage:
#   tools/migrate/from-claude-settings.sh [--dry-run]
#   tools/migrate/from-claude-settings.sh --help
#
# Idempotency: re-running after success is a no-op (symlinks already correct).
# After a partial run, the backup directory will preserve original state.

set -euo pipefail

# shellcheck source=../_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../_lib.sh"

cs_print_help() {
  cat <<'EOF'
from-claude-settings.sh — switch ~/.claude/ to claude-system (Phase 10).

Usage:
  tools/migrate/from-claude-settings.sh             Apply (after confirmation)
  tools/migrate/from-claude-settings.sh --dry-run   Show planned actions
  tools/migrate/from-claude-settings.sh --help

Backups: ~/.claude-system-backups/migration-<TIMESTAMP>/ (permanent)
Lock:    $TMPDIR/claude-system.migrate.lock
EOF
}

cs_show_help_if_requested "${1:-}"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) cs_error "Unknown arg: $arg"; exit 2 ;;
  esac
done

cs_require_macos
cs_require_root_dir

cs_acquire_lock migrate >/dev/null
trap 'cs_release_lock migrate' EXIT

cs_ensure_backup_dir

CLAUDE_HOME="$HOME/.claude"
ADAPTER_ROOT="$CS_ROOT/adapters/claude-code"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CS_BACKUP_ROOT/migration-${TIMESTAMP}"

cs_step "from-claude-settings.sh ($([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo APPLY))"
cs_info "CLAUDE_HOME = $CLAUDE_HOME"
cs_info "CS_ROOT     = $CS_ROOT"
cs_info "BACKUP_DIR  = $BACKUP_DIR"

# ---------------------------------------------------------------------------
# 1. Preflight: doctor.sh must pass
# ---------------------------------------------------------------------------
cs_step "Step 1: Verifying preconditions (doctor.sh)..."
if [[ "$DRY_RUN" == "0" ]]; then
  if ! "$CS_ROOT/tools/doctor.sh" >/dev/null 2>&1; then
    cs_error "doctor.sh failed. Aborting migration."
    cs_error "Run 'tools/doctor.sh' manually to inspect."
    exit 1
  fi
  cs_success "doctor.sh: clean"
else
  cs_info "  (dry-run) would invoke tools/doctor.sh"
fi

# ---------------------------------------------------------------------------
# 2. Detect current ~/.claude/ state
# ---------------------------------------------------------------------------
cs_step "Step 2: Detecting current ~/.claude/ state..."
CURRENT_KIND="missing"
if [[ -L "$CLAUDE_HOME" ]]; then
  CURRENT_KIND="symlink"
  cs_info "  ~/.claude is a symlink to: $(readlink "$CLAUDE_HOME")"
elif [[ -d "$CLAUDE_HOME" ]]; then
  CURRENT_KIND="directory"
  cs_info "  ~/.claude is a directory (size: $(du -sh "$CLAUDE_HOME" 2>/dev/null | awk '{print $1}'))"
else
  cs_info "  ~/.claude does not exist"
fi

# ---------------------------------------------------------------------------
# 3. Confirm with user
# ---------------------------------------------------------------------------
if [[ "$DRY_RUN" == "0" ]]; then
  cs_step "Step 3: Confirmation"
  cs_warn "This will:"
  cs_warn "  - Back up current ~/.claude/ to $BACKUP_DIR (permanent)"
  cs_warn "  - Remove ~/.claude/"
  cs_warn "  - Recreate ~/.claude/ with symlinks to claude-system"
  cs_warn "Continue?"
  if ! cs_confirm "Proceed with migration"; then
    cs_info "Aborted by user. No changes made."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 4. Backup
# ---------------------------------------------------------------------------
cs_step "Step 4: Backing up current ~/.claude/..."
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would mkdir $BACKUP_DIR and copy state"
else
  mkdir -p "$BACKUP_DIR"
  case "$CURRENT_KIND" in
    symlink)
      # Resolve symlink target and copy contents
      cp -L -R "$CLAUDE_HOME" "$BACKUP_DIR/dot-claude-resolved"
      printf 'symlink\n%s\n' "$(readlink "$CLAUDE_HOME")" > "$BACKUP_DIR/_kind.txt"
      ;;
    directory)
      cp -R "$CLAUDE_HOME" "$BACKUP_DIR/dot-claude-direct"
      printf 'directory\n' > "$BACKUP_DIR/_kind.txt"
      ;;
    missing)
      printf 'missing\n' > "$BACKUP_DIR/_kind.txt"
      ;;
  esac
  cs_success "  Backup: $BACKUP_DIR"
fi

# ---------------------------------------------------------------------------
# 5. Remove current ~/.claude/
# ---------------------------------------------------------------------------
cs_step "Step 5: Removing current ~/.claude/..."
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would remove $CLAUDE_HOME (kind: $CURRENT_KIND)"
else
  case "$CURRENT_KIND" in
    symlink)   rm "$CLAUDE_HOME" ;;
    directory) rm -rf "$CLAUDE_HOME" ;;
    missing)   : ;;
  esac
fi

# ---------------------------------------------------------------------------
# 6. Recreate ~/.claude/ with symlinks
# ---------------------------------------------------------------------------
cs_step "Step 6: Recreating ~/.claude/ with symlinks to claude-system..."

declare -a LINK_PAIRS=(
  "CLAUDE.md::$ADAPTER_ROOT/user-level/CLAUDE.md"
  "skills::$ADAPTER_ROOT/user-level/skills"
  "hooks::$ADAPTER_ROOT/user-level/hooks"
  "commands::$ADAPTER_ROOT/user-level/commands"
  "agents::$ADAPTER_ROOT/subagents"
)

if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would mkdir $CLAUDE_HOME and create symlinks:"
  for pair in "${LINK_PAIRS[@]}"; do
    target_name="${pair%%::*}"
    source_path="${pair##*::}"
    cs_info "    $CLAUDE_HOME/$target_name -> $source_path"
  done
else
  mkdir -p "$CLAUDE_HOME"
  for pair in "${LINK_PAIRS[@]}"; do
    target_name="${pair%%::*}"
    source_path="${pair##*::}"
    target_path="$CLAUDE_HOME/$target_name"

    if [[ ! -e "$source_path" ]]; then
      cs_error "Source missing: $source_path"
      exit 1
    fi
    ln -s "$source_path" "$target_path"
    cs_success "  $target_path -> $source_path"
  done
fi

# ---------------------------------------------------------------------------
# 7. settings.json: manual placement
# ---------------------------------------------------------------------------
cs_step "Step 7: settings.json (manual)"
SETTINGS_TEMPLATE="$ADAPTER_ROOT/user-level/settings.json.template"
SETTINGS_TARGET="$CLAUDE_HOME/settings.json"

if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would NOT auto-deploy settings.json. Run after migration:"
  cs_info "    cp $SETTINGS_TEMPLATE $SETTINGS_TARGET"
  cs_info "    \$EDITOR $SETTINGS_TARGET"
else
  cs_warn "  Manually deploy settings.json after this script:"
  cs_warn "    cp $SETTINGS_TEMPLATE $SETTINGS_TARGET"
  cs_warn "    \$EDITOR $SETTINGS_TARGET   # fill machine-local TODO sections"
fi

# ---------------------------------------------------------------------------
# 8. Verification
# ---------------------------------------------------------------------------
cs_step "Step 8: Verification"
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would invoke tools/doctor.sh after migration"
else
  ls -la "$CLAUDE_HOME"
  if "$CS_ROOT/tools/doctor.sh" >/dev/null 2>&1; then
    cs_success "  doctor.sh: clean"
  else
    cs_warn "  doctor.sh reported issues. Inspect with: tools/doctor.sh"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
if [[ "$DRY_RUN" == "1" ]]; then
  cs_step "Dry-run complete. No changes applied."
else
  cs_step "Migration complete!"
  cs_info "  Backup (permanent): $BACKUP_DIR"
  cs_info "  Old claude-settings: ~/ws/claude-settings/ (archive)"
  cs_info "  Next step: place ~/.claude/settings.json from template, then test 'claude' in a project."
  cs_info "  Rollback if needed: tools/migrate/rollback-from-claude-system.sh"
fi
