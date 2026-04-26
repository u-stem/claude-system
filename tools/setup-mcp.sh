#!/usr/bin/env bash
# tools/setup-mcp.sh — register MCP servers declared in
# adapters/claude-code/user-level/mcp/servers.template.json.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
setup-mcp.sh — register MCP servers from the declarative template.

Source: $CS_ROOT/adapters/claude-code/user-level/mcp/servers.template.json
Reads .servers[].{name, command, args, env_keys, requires_secret}.

Servers with requires_secret=true are SKIPPED (must be added manually with
secrets injected; see ADR 0001 / 0002 — secrets are not in the template).

Memory MCP is intentionally absent (ADR 0003).

Usage:
  tools/setup-mcp.sh
  tools/setup-mcp.sh --help
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_root_dir

TEMPLATE="$CS_ROOT/adapters/claude-code/user-level/mcp/servers.template.json"
if [[ ! -f "$TEMPLATE" ]]; then
  cs_error "Template missing: $TEMPLATE"
  exit 1
fi
cs_require_cmd jq
cs_require_cmd claude

cs_step "Reading $TEMPLATE"
if ! jq empty "$TEMPLATE" >/dev/null 2>&1; then
  cs_error "Invalid JSON: $TEMPLATE"
  exit 1
fi

# Snapshot current MCP list (idempotency check).
EXISTING="$(claude mcp list 2>/dev/null || true)"

count="$(jq '.servers | length' "$TEMPLATE")"
for ((i=0; i<count; i++)); do
  name="$(jq -r ".servers[$i].name" "$TEMPLATE")"
  cmd="$(jq -r ".servers[$i].command" "$TEMPLATE")"
  requires_secret="$(jq -r ".servers[$i].requires_secret // false" "$TEMPLATE")"

  if [[ "$requires_secret" == "true" ]]; then
    cs_warn "$name: requires secret (skip — add manually with claude mcp add)"
    cs_info "  See: https://github.com/anthropics/claude-code (mcp add docs)"
    continue
  fi

  if echo "$EXISTING" | grep -q "^${name}\b"; then
    cs_success "$name: already registered (skip)"
    continue
  fi

  # Build args array.
  mapfile -t args < <(jq -r ".servers[$i].args[]?" "$TEMPLATE")

  cs_info "Adding $name: $cmd ${args[*]}"
  if claude mcp add "$name" -- "$cmd" "${args[@]}"; then
    cs_success "Added $name"
  else
    cs_error "Failed to add $name"
  fi
done

cs_step "Done"
cs_info "List active servers with: claude mcp list"
