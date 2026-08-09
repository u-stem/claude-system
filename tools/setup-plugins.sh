#!/usr/bin/env bash
# tools/setup-plugins.sh — install the plugins declared in
# adapters/claude-code/user-level/settings.json.template.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
setup-plugins.sh — install plugins from the settings template declaration.

Source: $CS_ROOT/adapters/claude-code/user-level/settings.json.template
Reads .extraKnownMarketplaces (marketplace registration) and .enabledPlugins
(entries set to true). The template is the single source of truth; this script
only reads it — never edit the declaration here (ADR 0023).

Why this exists: enabledPlugins only *declares* plugins. Claude Code does not
install them from that key, so a declaration without `claude plugin install`
stays inert. That gap left three plugins declared-but-absent from 2026-04-26 to
2026-08-08 (ADR 0023). doctor.sh now warns when it reappears.

Idempotent: already-installed plugins and already-added marketplaces are
skipped. Plugin payloads land in ~/.claude/plugins/cache/<marketplace>/<plugin>/
<version> — do not delete that path (see cleanup-claude-code-runtime.sh --help).

Usage:
  tools/setup-plugins.sh
  tools/setup-plugins.sh --dry-run   Preview only
  tools/setup-plugins.sh --help
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_root_dir

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

TEMPLATE="$CS_ROOT/adapters/claude-code/user-level/settings.json.template"
if [[ ! -f "$TEMPLATE" ]]; then
  cs_error "Template missing: $TEMPLATE"
  exit 1
fi
cs_require_cmd jq
cs_require_cmd claude

if ! jq empty "$TEMPLATE" >/dev/null 2>&1; then
  cs_error "Invalid JSON: $TEMPLATE"
  exit 1
fi

# --- marketplaces -----------------------------------------------------------
cs_step "Marketplaces declared in the template"
KNOWN_FILE="$HOME/.claude/plugins/known_marketplaces.json"
while IFS=$'\t' read -r mp_name mp_repo; do
  [[ -z "$mp_name" ]] && continue
  # Reject anything that could be read as a flag by `claude`. Shell injection
  # is not possible here (values are passed as quoted argv, no eval), but a
  # leading dash would silently become an option.
  if [[ ! "$mp_repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    cs_error "$mp_name: refusing malformed repo '$mp_repo' (expected owner/repo)"
    continue
  fi
  if [[ -f "$KNOWN_FILE" ]] && jq -e --arg k "$mp_name" 'has($k)' "$KNOWN_FILE" >/dev/null 2>&1; then
    cs_success "$mp_name: already added (skip)"
    continue
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    cs_info "[dry-run] claude plugin marketplace add $mp_repo"
    continue
  fi
  cs_info "Adding marketplace $mp_name ($mp_repo)"
  if claude plugin marketplace add "$mp_repo"; then
    cs_success "Added marketplace $mp_name"
  else
    cs_error "Failed to add marketplace $mp_name"
  fi
done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
                | select(.value.source.source == "github")
                | "\(.key)\t\(.value.source.repo)"' "$TEMPLATE")

# Anything that is not a github source is silently outside the loop above.
# Warn rather than no-op, so adding a url/path source to the template cannot
# leave the operator believing it was set up.
while IFS=$'\t' read -r mp_name mp_type; do
  [[ -z "$mp_name" ]] && continue
  cs_warn "$mp_name: unsupported marketplace source type '$mp_type' (skipped — add it manually with: claude plugin marketplace add ...)"
done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
                | select(.value.source.source != "github")
                | "\(.key)\t\(.value.source.source // "unknown")"' "$TEMPLATE")

# --- plugins ----------------------------------------------------------------
cs_step "Plugins enabled in the template"
STATE="$HOME/.claude/plugins/installed_plugins.json"
# Mirror doctor.sh's schema guard: installed_plugins.json is not a published
# schema, so an unknown version means "cannot tell", not "not installed".
if [[ -f "$STATE" ]]; then
  state_schema="$(jq -r '.version // empty' "$STATE" 2>/dev/null || true)"
  if [[ "$state_schema" != "2" ]]; then
    cs_warn "unknown installed_plugins.json schema '${state_schema:-none}'; cannot detect existing installs — will attempt install for every declared plugin (claude plugin install is idempotent)"
  fi
fi

while IFS= read -r plugin; do
  [[ -z "$plugin" ]] && continue
  if [[ ! "$plugin" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$ ]]; then
    cs_error "refusing malformed plugin id '$plugin' (expected name@marketplace)"
    continue
  fi
  if [[ -f "$STATE" ]] && jq -e --arg k "$plugin" '.plugins | has($k)' "$STATE" >/dev/null 2>&1; then
    cs_success "$plugin: already installed (skip)"
    continue
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    cs_info "[dry-run] claude plugin install $plugin"
    continue
  fi
  cs_info "Installing $plugin"
  if claude plugin install "$plugin"; then
    cs_success "Installed $plugin"
  else
    cs_error "Failed to install $plugin"
  fi
done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$TEMPLATE")

cs_step "Done"
cs_info "Verify with: claude plugin list   /   tools/doctor.sh"
