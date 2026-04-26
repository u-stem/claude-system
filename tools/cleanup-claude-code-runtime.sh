#!/usr/bin/env bash
# tools/cleanup-claude-code-runtime.sh — remove Claude Code runtime artifacts
# from ~/.claude/. Manual-execution only (per Phase 7a design decision A1).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
cleanup-claude-code-runtime.sh — purge Claude Code runtime artifacts.

Usage:
  tools/cleanup-claude-code-runtime.sh             Interactive confirm
  tools/cleanup-claude-code-runtime.sh --dry-run   Preview only
  tools/cleanup-claude-code-runtime.sh --force     No prompt
  tools/cleanup-claude-code-runtime.sh --help

Removes (under ~/.claude/):
  projects/ telemetry/ history.jsonl backups/ file-history/ statsig/
  plugins/cache/ ide/ paste-cache/ session-env/ shell-snapshots/ todos/
  tasks/ debug/ cache/ downloads/ mcp-needs-auth-cache.json stats-cache.json
  double-shot-latte/

Does NOT touch: settings.json, CLAUDE.md, skills, agents, commands, hooks,
plugins/ (only its `cache/` subdir).
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_macos

DRY_RUN=0
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1; shift ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

CLAUDE_HOME="$HOME/.claude"
if [[ ! -d "$CLAUDE_HOME" ]]; then
  cs_info "$CLAUDE_HOME does not exist; nothing to clean."
  exit 0
fi

declare -a TARGETS=(
  "projects" "telemetry" "history.jsonl" "backups" "file-history"
  "statsig" "plugins/cache" "ide" "paste-cache" "session-env"
  "shell-snapshots" "todos" "tasks" "debug" "cache" "downloads"
  "mcp-needs-auth-cache.json" "stats-cache.json" "double-shot-latte"
)

cs_step "Cleanup plan ($([[ $DRY_RUN -eq 1 ]] && echo DRY-RUN || echo APPLY))"
declare -a TO_REMOVE=()
for t in "${TARGETS[@]}"; do
  full="$CLAUDE_HOME/$t"
  if [[ -e "$full" ]]; then
    TO_REMOVE+=("$full")
    cs_info "would remove: $full"
  fi
done

if [[ ${#TO_REMOVE[@]} -eq 0 ]]; then
  cs_success "Nothing to clean."
  exit 0
fi

if [[ "$DRY_RUN" == "1" ]]; then
  cs_step "Dry-run complete (${#TO_REMOVE[@]} targets)."
  exit 0
fi

if [[ "$FORCE" != "1" ]]; then
  if ! cs_confirm "Remove ${#TO_REMOVE[@]} target(s)?"; then
    cs_info "Cancelled."
    exit 0
  fi
fi

for f in "${TO_REMOVE[@]}"; do
  rm -rf "$f"
  cs_success "removed: $f"
done

cs_step "Done"
