#!/usr/bin/env bash
# tests/validate-frontmatter.sh — verify YAML frontmatter parses correctly for
# all skill / subagent / command files.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir
cd "$CS_ROOT"

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

# Lightweight frontmatter validation:
#   - file starts with "---"
#   - second "---" closes the block within first 30 lines
#   - between, every non-empty line matches "^[a-z_]+:.*$" (or is a list continuation "  - ...")
validate_one() {
  local file="$1"
  local first
  first="$(head -1 "$file")"
  if [[ "$first" != "---" ]]; then
    err "no leading frontmatter: $file"
    return
  fi
  local close_line
  close_line="$(awk 'NR>1 && /^---$/ {print NR; exit}' "$file")"
  if [[ -z "$close_line" ]]; then
    err "unclosed frontmatter: $file"
    return
  fi
  if [[ "$close_line" -gt 30 ]]; then
    err "frontmatter unusually long ($close_line lines): $file"
  fi

  local between
  between="$(sed -n "2,$((close_line - 1))p" "$file")"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! [[ "$line" =~ ^[a-z_][a-z0-9_]*:[[:space:]]*.*$ || "$line" =~ ^[[:space:]]+-[[:space:]]+.+$ || "$line" =~ ^[[:space:]]+[a-z_]+:[[:space:]]*.+$ ]]; then
      err "malformed frontmatter line in $file: $line"
    fi
  done <<<"$between"
}

for f in adapters/claude-code/user-level/skills/*/SKILL.md \
         adapters/claude-code/subagents/*.md \
         adapters/claude-code/user-level/commands/*.md; do
  [[ -f "$f" ]] || continue
  case "$(basename "$f")" in
    _index.md|README.md) continue ;;
  esac
  validate_one "$f"
done

if [[ $ERRORS -gt 0 ]]; then
  cs_error "validate-frontmatter: $ERRORS issue(s)"
  exit 1
fi
cs_success "validate-frontmatter: clean"
