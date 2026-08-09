#!/usr/bin/env bash
# WARNING: This script switches ~/.claude/ from claude-settings to claude-system.
#
# It performed that one-time switchover on 2026-05-04 and is retained for two
# cases: a fresh machine that still carries a legacy claude-settings tree, and
# rollback rehearsal. A machine with no legacy tree wants tools/sync.sh instead.
#
# Behavior:
#   - Detects dangling symlinks in the source tree (preflight) and offers to
#     remove them before backup. Non-interactive shells warn and continue;
#     Step 4 then skips any remaining dangling links. (ADR 0007)
#   - Backs up current ~/.claude/ to ~/.claude-system-backups/migration-<TIMESTAMP>/
#     using a robust per-entry copy (resolves resolvable symlinks, skips
#     dangling ones with a warning). Preserved permanently — not removed by
#     cleanup-backups.sh.
#   - Removes ~/.claude/.
#   - Recreates ~/.claude/ as a directory with symlinks to claude-system:
#       CLAUDE.md / skills / hooks / commands / agents
#   - Delegates ~/.claude/settings.json deployment to tools/sync.sh
#     (machine-local cp-deploy; see ADR 0007 for the boundary rationale).
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
from-claude-settings.sh — switch ~/.claude/ from a legacy claude-settings tree
to claude-system (one-time structural migration).

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

# Lock-acquisition order: explicit `|| exit 1` before installing the trap
# so that a failed acquisition does not leave a partial trap pointing at a
# lock we never owned.
cs_acquire_lock migrate >/dev/null || exit 1
trap 'cs_release_lock migrate' EXIT

cs_ensure_backup_dir

CLAUDE_HOME="$HOME/.claude"
ADAPTER_ROOT="$CS_ROOT/adapters/claude-code"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CS_BACKUP_ROOT/migration-${TIMESTAMP}"

# ---------------------------------------------------------------------------
# Local helper: robust per-entry copy for the symlink-resolution backup.
#
# Replaces the prior `cp -L -R` (which aborts on the first dangling link).
# Walks the source tree with `find -print0`, dispatches per entry kind:
#   - dangling symlink     -> skip + warn  (ADR 0007: tolerate runtime cruft)
#   - resolvable symlink   -> cp -L         (preserve old -L semantics)
#   - directory (non-link) -> mkdir         (recreate structure)
#   - regular file         -> cp            (plain copy)
# Prints the count of skipped dangling entries on stdout.
# ---------------------------------------------------------------------------
cs_robust_copy_resolved() {
  local src="$1"
  local dest="$2"
  local skipped=0
  mkdir -p "$dest"
  while IFS= read -r -d '' entry; do
    [[ "$entry" == "$src" ]] && continue
    local rel="${entry#"$src"/}"
    local target="$dest/$rel"
    if [[ -L "$entry" ]] && [[ ! -e "$entry" ]]; then
      cs_warn "  Skipping dangling symlink: $entry"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ -d "$entry" ]] && [[ ! -L "$entry" ]]; then
      mkdir -p "$target"
    elif [[ -L "$entry" ]]; then
      cp -L "$entry" "$target" 2>/dev/null || cs_warn "  Copy failed: $entry"
    else
      cp "$entry" "$target" 2>/dev/null || cs_warn "  Copy failed: $entry"
    fi
  done < <(find "$src" -print0)
  echo "$skipped"
}

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
# 2.5. Preflight: detect dangling symlinks in the source tree (ADR 0007)
# ---------------------------------------------------------------------------
# Runtime-derived dangling links (e.g., debug/latest pointing at a removed
# session) caused the prior `cp -L -R` to fail mid-run. Detect them here and
# offer interactive removal; non-interactive shells warn and continue, and
# Step 4's robust copy will skip whatever remains.
cs_step "Step 2.5: Preflight — dangling symlink scan"
SCAN_ROOT=""
case "$CURRENT_KIND" in
  symlink)   SCAN_ROOT="$(readlink "$CLAUDE_HOME")" ;;
  directory) SCAN_ROOT="$CLAUDE_HOME" ;;
  missing)   SCAN_ROOT="" ;;
esac

if [[ -n "$SCAN_ROOT" ]] && [[ -d "$SCAN_ROOT" ]]; then
  DANGLING_LIST="$(find "$SCAN_ROOT" -type l ! -exec test -e {} \; -print 2>/dev/null || true)"
  if [[ -z "$DANGLING_LIST" ]]; then
    cs_success "  No dangling symlinks under $SCAN_ROOT"
  else
    DANGLING_COUNT="$(printf '%s\n' "$DANGLING_LIST" | wc -l | tr -d ' ')"
    cs_warn "  Detected $DANGLING_COUNT dangling symlink(s):"
    printf '%s\n' "$DANGLING_LIST" | sed 's/^/    /' >&2
    if [[ "$DRY_RUN" == "1" ]]; then
      cs_info "  (dry-run) would offer to delete dangling links before backup"
    elif [[ -t 0 ]] && cs_confirm "Delete these dangling symlinks before backup?"; then
      while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        rm -f "$link" && cs_success "  Removed: $link"
      done <<<"$DANGLING_LIST"
    else
      cs_warn "  Continuing — Step 4 will skip dangling links and warn."
    fi
  fi
else
  cs_info "  No source tree to scan (CURRENT_KIND=$CURRENT_KIND)"
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
# 4. Backup (robust per-entry copy, ADR 0007)
# ---------------------------------------------------------------------------
cs_step "Step 4: Backing up current ~/.claude/..."
if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) would mkdir $BACKUP_DIR and copy state"
else
  mkdir -p "$BACKUP_DIR"
  case "$CURRENT_KIND" in
    symlink)
      # Resolve symlink target and copy contents per entry, tolerating
      # dangling links that may remain after Step 2.5.
      src_resolved="$(readlink "$CLAUDE_HOME")"
      skipped="$(cs_robust_copy_resolved "$src_resolved" "$BACKUP_DIR/dot-claude-resolved")"
      printf 'symlink\n%s\n' "$src_resolved" > "$BACKUP_DIR/_kind.txt"
      if [[ "$skipped" -gt 0 ]]; then
        cs_warn "  $skipped dangling symlink(s) were skipped during backup"
      fi
      ;;
    directory)
      skipped="$(cs_robust_copy_resolved "$CLAUDE_HOME" "$BACKUP_DIR/dot-claude-direct")"
      printf 'directory\n' > "$BACKUP_DIR/_kind.txt"
      if [[ "$skipped" -gt 0 ]]; then
        cs_warn "  $skipped dangling symlink(s) were skipped during backup"
      fi
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
# 7. settings.json: delegated to tools/sync.sh (ADR 0007)
# ---------------------------------------------------------------------------
# settings.json holds machine-local values (API keys etc.) and cannot be a
# symlink. Its cp-deploy is the responsibility of tools/sync.sh (the canonical
# follow-up step per tools/setup.sh). This script handles the one-shot
# structural switch only.
cs_step "Step 7: settings.json (delegated to tools/sync.sh)"

if [[ "$DRY_RUN" == "1" ]]; then
  cs_info "  (dry-run) settings.json deployment is delegated to tools/sync.sh."
  cs_info "  Run next:"
  cs_info "    tools/sync.sh --dry-run"
  cs_info "    CLAUDE_SYSTEM_ALLOW_SYNC=1 tools/sync.sh --force"
else
  cs_info "  settings.json deployment is delegated to tools/sync.sh"
  cs_info "  (machine-local cp-deploy; see ADR 0007 for boundary rationale)."
  cs_info "  Run next:"
  cs_info "    tools/sync.sh --dry-run"
  cs_info "    CLAUDE_SYSTEM_ALLOW_SYNC=1 tools/sync.sh --force"
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
  cs_info "  Next step: deploy settings.json via 'tools/sync.sh' (ADR 0007),"
  cs_info "             then test 'claude' in a project."
  cs_info "  Rollback if needed: tools/migrate/rollback-from-claude-system.sh"
fi
