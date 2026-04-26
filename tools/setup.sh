#!/usr/bin/env bash
# tools/setup.sh — initialize a new machine for claude-system.
# Idempotent: re-running is safe.
#
# Usage:
#   tools/setup.sh
#   tools/setup.sh --help

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
setup.sh — bootstrap a new machine for claude-system.

Steps (all idempotent):
  1. macOS check
  2. Required commands check (git, gh, bun, uv, gitleaks, jq, shellcheck, tree)
  3. Optional commands (chezmoi) — detection only, no integration here
  4. Ensure ~/.claude-system-backups/ exists
  5. Run doctor.sh

Missing tools are reported with `brew install` suggestions; nothing is auto-installed.
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_macos
cs_require_root_dir

cs_step "Required tools"
declare -a REQUIRED=(git gh bun uv gitleaks jq shellcheck tree)
declare -a MISSING=()
for cmd in "${REQUIRED[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    cs_success "$cmd: $(command -v "$cmd")"
  else
    MISSING+=("$cmd")
    cs_warn "$cmd: not found"
  fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  cs_warn "Install missing tools with:"
  printf '    brew install %s\n' "${MISSING[*]}"
fi

cs_step "Optional tools"
if command -v chezmoi >/dev/null 2>&1; then
  cs_info "chezmoi detected: $(command -v chezmoi)"
  cs_info "chezmoi integration is detection-only here; configure manually if you use it."
else
  cs_info "chezmoi not installed (optional)."
fi

cs_step "Backup directory"
cs_ensure_backup_dir
cs_success "Backup root: $CS_BACKUP_ROOT"

cs_step "Run doctor"
"$CS_ROOT/tools/doctor.sh" || cs_warn "doctor.sh reported issues; review above."

cs_step "Done"
cs_success "setup.sh complete. Next steps:"
echo "  - Phase 0-9: keep ~/.claude/ pointing at the legacy claude-settings."
echo "  - Phase 10:  run tools/sync.sh --dry-run, then --force with CLAUDE_SYSTEM_ALLOW_SYNC=1."
echo "  - MCP setup: tools/setup-mcp.sh (interactive)."
