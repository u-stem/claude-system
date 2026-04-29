#!/usr/bin/env bash
# tests/lint-skills.sh — structural lint for skills.
# Exit 0 if all skills pass, 1 if any error.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir
cd "$CS_ROOT"

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  for field in name description recommended_model; do
    head -10 "$skill" | grep -q "^${field}:" || err "missing $field: $skill"
  done
  dir_name="$(basename "$(dirname "$skill")")"
  name_field="$(grep '^name:' "$skill" | head -1 | cut -d: -f2 | tr -d ' ')"
  [[ "$dir_name" == "$name_field" ]] || err "dir/name mismatch: dir=$dir_name name=$name_field ($skill)"
  desc="$(grep '^description:' "$skill" | head -1 | sed 's/^description: //')"
  # Force UTF-8 locale so `wc -m` counts characters (not bytes) for CJK
  # descriptions on macOS BSD.
  chars="$(printf '%s' "$desc" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')"
  [[ "$chars" -le 50 ]] || err "description over 50 ($chars): $skill"
  for sec in '## 目的' '## いつ発動するか' '## 手順'; do
    grep -q "^${sec}" "$skill" || err "missing section '${sec}': $skill"
  done
done

if [[ $ERRORS -gt 0 ]]; then
  cs_error "lint-skills: $ERRORS error(s)"
  exit 1
fi
cs_success "lint-skills: all skills pass"
