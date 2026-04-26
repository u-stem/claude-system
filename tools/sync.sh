#!/usr/bin/env bash
# WARNING: This switches ~/.claude/ from claude-settings to claude-system.
# DO NOT execute without --dry-run during Phase 0-9.
# Real execution should happen in Phase 10 only.
#
# tools/sync.sh — distribute symlinks from claude-system into ~/.claude/.
# Usage:
#   tools/sync.sh --dry-run        # show planned actions (default during Phase 0-9)
#   tools/sync.sh --force          # apply without prompts (Phase 10+ only)
#   tools/sync.sh --help

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
sync.sh — distribute symlinks into ~/.claude/

Usage:
  tools/sync.sh --dry-run    Show planned actions (no changes)
  tools/sync.sh --force      Apply changes (Phase 10 only)
  tools/sync.sh --help

Phase 0-9: --dry-run only. The script blocks real execution unless --force is
passed AND the safeguard env CLAUDE_SYSTEM_ALLOW_SYNC=1 is set.

Backups are written to: ~/.claude-system-backups/
Lock file: $TMPDIR/claude-system.sync.lock
EOF
}

cs_show_help_if_requested "${1:-}"

DRY_RUN=1
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1; DRY_RUN=0 ;;
    *) cs_error "Unknown arg: $arg"; exit 2 ;;
  esac
done

cs_require_macos
cs_require_root_dir

if [[ "$FORCE" == "1" && "${CLAUDE_SYSTEM_ALLOW_SYNC:-}" != "1" ]]; then
  cs_error "--force passed but CLAUDE_SYSTEM_ALLOW_SYNC=1 is not set."
  cs_error "This is the Phase 0-9 safeguard. Real switch happens only in Phase 10."
  exit 2
fi

# Acquire lock
cs_acquire_lock sync >/dev/null
trap 'cs_release_lock sync' EXIT

cs_ensure_backup_dir

CLAUDE_HOME="$HOME/.claude"
ADAPTER_ROOT="$CS_ROOT/adapters/claude-code"

# Symlink plan: target_in_~/.claude/  ->  source_in_claude-system
# settings.json is intentionally cp-deployed (machine-local values), not symlinked.
declare -a LINK_PAIRS=(
  "CLAUDE.md::$ADAPTER_ROOT/user-level/CLAUDE.md"
  "skills::$ADAPTER_ROOT/user-level/skills"
  "hooks::$ADAPTER_ROOT/user-level/hooks"
  "commands::$ADAPTER_ROOT/user-level/commands"
  "agents::$ADAPTER_ROOT/subagents"
)

cs_step "sync.sh plan ($([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo APPLY))"
cs_info "CLAUDE_HOME = $CLAUDE_HOME"
cs_info "CS_ROOT     = $CS_ROOT"

if [[ ! -d "$CLAUDE_HOME" ]]; then
  cs_warn "$CLAUDE_HOME does not exist. (would mkdir on apply)"
fi

for pair in "${LINK_PAIRS[@]}"; do
  target_name="${pair%%::*}"
  source_path="${pair##*::}"
  target_path="$CLAUDE_HOME/$target_name"

  if [[ ! -e "$source_path" ]]; then
    cs_warn "Source missing, skipping: $source_path"
    continue
  fi

  current=""
  if [[ -L "$target_path" ]]; then
    current="$(readlink "$target_path")"
    if [[ "$current" == "$source_path" ]]; then
      cs_success "Already linked: $target_path -> $source_path"
      continue
    fi
    cs_info "Will replace symlink: $target_path -> $source_path (was: $current)"
  elif [[ -e "$target_path" ]]; then
    backup="$(cs_backup_path_for "$target_path")"
    cs_warn "Existing $target_path will be moved to $backup"
    if [[ "$DRY_RUN" == "0" ]]; then
      mv "$target_path" "$backup"
    fi
  else
    cs_info "Will create symlink: $target_path -> $source_path"
  fi

  if [[ "$DRY_RUN" == "0" ]]; then
    mkdir -p "$CLAUDE_HOME"
    [[ -L "$target_path" ]] && rm "$target_path"
    ln -s "$source_path" "$target_path"
    cs_success "Linked: $target_path -> $source_path"
  fi
done

# settings.json: cp-deploy (not symlink). In dry-run, only preview.
SETTINGS_TEMPLATE="$ADAPTER_ROOT/user-level/settings.json.template"
SETTINGS_TARGET="$CLAUDE_HOME/settings.json"

cs_step "settings.json deployment plan"
if [[ ! -f "$SETTINGS_TEMPLATE" ]]; then
  cs_warn "Template missing: $SETTINGS_TEMPLATE"
elif [[ -f "$SETTINGS_TARGET" ]]; then
  cs_info "settings.json already exists at $SETTINGS_TARGET; manual diff/merge required."
  cs_info "Phase 10 procedure: review, then cp or merge from $SETTINGS_TEMPLATE"
else
  cs_info "Will copy $SETTINGS_TEMPLATE -> $SETTINGS_TARGET (manual placeholder fill needed)"
  if [[ "$DRY_RUN" == "0" ]]; then
    cp "$SETTINGS_TEMPLATE" "$SETTINGS_TARGET"
    cs_success "Copied settings.json (review for machine-local values)"
  fi
fi

if [[ "$DRY_RUN" == "1" ]]; then
  cs_step "Dry-run complete. No changes applied."
else
  cs_step "Sync complete."
fi
