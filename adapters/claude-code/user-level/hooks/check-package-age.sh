#!/usr/bin/env bash
# check-package-age.sh — PreToolUse(Bash) — supply-chain protection.
# Migrated from claude-settings/hooks/check-package-age.sh (ADR 0001 / 0002:
# absolute personal paths replaced with $HOME-derived paths via _lib.sh).
#
# Denies install of packages whose first-publish date is younger than
# PACKAGE_MIN_AGE_DAYS (default 7).
#
# References:
#   - adapter: ~/ws/claude-system/practices/supply-chain-hygiene.md
#   - related: ~/ws/claude-system/adapters/claude-code/user-level/skills/dependency-review/

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -z "$COMMAND" ]] && exit 0

COOLDOWN_DAYS="${PACKAGE_MIN_AGE_DAYS:-7}"

# Determine ecosystem from command. Early exit for non-install commands.
case "$COMMAND" in
  *bun\ add*|*npm\ add*)        ECOSYSTEM="npm" ;;
  *uv\ add*|*uv\ pip\ install*) ECOSYSTEM="pypi" ;;
  *cargo\ add*)                 ECOSYSTEM="crates" ;;
  *)                            exit 0 ;;
esac

# Extract package names, skipping flags / option values / subcommands.
extract_packages() {
  local skip_next=false
  local found_add=false
  for arg in $COMMAND; do
    if $skip_next; then skip_next=false; continue; fi
    if ! $found_add; then
      case "$arg" in add|install) found_add=true ;; esac
      continue
    fi
    case "$arg" in
      --registry|--tag|--index) skip_next=true ;;
      -*) ;;
      *) echo "$arg" ;;
    esac
  done
}

strip_version() {
  local pkg="$1"
  case "$ECOSYSTEM" in
    npm)
      if [[ "$pkg" == @*/*@* ]]; then
        echo "${pkg%@*}"
      elif [[ "$pkg" == @* ]]; then
        echo "$pkg"
      else
        echo "${pkg%%@*}"
      fi
      ;;
    pypi)   echo "${pkg%%[=<>!~]*}" ;;
    crates) echo "${pkg%%@*}" ;;
  esac
}

get_created_ts() {
  local pkg_name="$1"
  local raw_date=""

  case "$ECOSYSTEM" in
    npm)
      raw_date="$(npm view "$pkg_name" time.created 2>/dev/null)" || return 1
      ;;
    pypi)
      raw_date="$(curl -sf --max-time 5 "https://pypi.org/pypi/$pkg_name/json" \
        | jq -r '
          [.releases | to_entries[]
           | select(.value | length > 0)
           | .value[0].upload_time_iso_8601
          ] | sort | first // empty
        ')" || return 1
      ;;
    crates)
      raw_date="$(curl -sf --max-time 5 "https://crates.io/api/v1/crates/$pkg_name" \
        | jq -r '.crate.created_at // empty')" || return 1
      ;;
  esac

  [[ -z "$raw_date" ]] && return 1

  # Parse ISO 8601 to epoch (BSD `date -jf` first, GNU `date -d` fallback).
  local trimmed="${raw_date%%.*}"
  trimmed="${trimmed%%Z}"
  date -jf "%Y-%m-%dT%H:%M:%S" "$trimmed" +%s 2>/dev/null && return 0
  date -d "$raw_date" +%s 2>/dev/null && return 0
  return 1
}

threshold="$(date -v-"${COOLDOWN_DAYS}"d +%s 2>/dev/null || date -d "${COOLDOWN_DAYS} days ago" +%s)"

PACKAGES="$(extract_packages)"
[[ -z "$PACKAGES" ]] && exit 0

while IFS= read -r raw_pkg; do
  [[ -z "$raw_pkg" ]] && continue
  pkg_name="$(strip_version "$raw_pkg")"
  [[ -z "$pkg_name" ]] && continue

  if ! created_ts="$(get_created_ts "$pkg_name")"; then
    hk_log check-package-age "registry lookup failed: $pkg_name"
    hk_deny PreToolUse "$pkg_name: registry lookup failed. Verify the package name."
  fi

  if [[ "$created_ts" -gt "$threshold" ]]; then
    created_human="$(date -r "$created_ts" "+%Y-%m-%d" 2>/dev/null || date -d "@$created_ts" "+%Y-%m-%d" 2>/dev/null || echo unknown)"
    hk_log check-package-age "deny too-young: $pkg_name (created $created_human, threshold ${COOLDOWN_DAYS}d)"
    hk_deny PreToolUse "$pkg_name: first published $created_human (< ${COOLDOWN_DAYS} days ago). Too new to install automatically."
  fi
done <<<"$PACKAGES"

exit 0
