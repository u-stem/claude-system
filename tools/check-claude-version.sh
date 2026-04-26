#!/usr/bin/env bash
# tools/check-claude-version.sh — diff installed Claude Code version vs adapters/.../VERSION.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
check-claude-version.sh — compare installed Claude Code with the version pinned in
adapters/claude-code/VERSION.

Usage:
  tools/check-claude-version.sh
  tools/check-claude-version.sh --help

If installed > pinned, prompts you to consider creating a migration script under
tools/migrate/ (see tools/migrate/README.md).
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_root_dir

PINNED_FILE="$CS_ROOT/adapters/claude-code/VERSION"
if [[ ! -f "$PINNED_FILE" ]]; then
  cs_error "$PINNED_FILE not found"
  exit 1
fi
PINNED="$(tr -d '[:space:]' < "$PINNED_FILE")"

if ! command -v claude >/dev/null 2>&1; then
  cs_warn "claude CLI not found on PATH. Pinned: $PINNED"
  exit 0
fi

# `claude --version` typically prints something like "1.2.3 (Claude Code)".
INSTALLED_RAW="$(claude --version 2>&1 || true)"
INSTALLED="$(echo "$INSTALLED_RAW" | awk '{print $1}')"

cs_info "pinned    : $PINNED"
cs_info "installed : $INSTALLED  ($INSTALLED_RAW)"

if [[ "$INSTALLED" == "$PINNED" ]]; then
  cs_success "Versions match."
  exit 0
fi

# Compare via sort -V; tail -1 wins.
HIGHER="$(printf '%s\n%s\n' "$PINNED" "$INSTALLED" | sort -V | tail -1)"
if [[ "$HIGHER" == "$INSTALLED" ]]; then
  cs_warn "Installed is newer than pinned ($INSTALLED > $PINNED)."
  cs_info "Review the migration playbook: $CS_ROOT/adapters/claude-code/README.md (#移行プレイブック)"
  cs_info "If breaking changes apply, draft tools/migrate/from-v${PINNED}-to-v${INSTALLED}.sh"
else
  cs_warn "Installed is OLDER than pinned ($INSTALLED < $PINNED)."
  cs_info "Upgrade Claude Code, or revert VERSION if intentional."
fi
