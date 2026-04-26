#!/usr/bin/env bash
# tools/new-skill.sh — scaffold a new user-level skill.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
new-skill.sh — create a new skill scaffold under
  $CS_ROOT/adapters/claude-code/user-level/skills/<name>/

Usage:
  tools/new-skill.sh <skill-name>
  tools/new-skill.sh --help

Naming: kebab-case verb-based (see practices/skill-design-guide.md).
After creation, edit SKILL.md and run tools/doctor.sh.
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -ne 1 ]]; then
  cs_error "Usage: tools/new-skill.sh <skill-name>"
  exit 2
fi

cs_require_root_dir

NAME="$1"
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  cs_error "Invalid skill name (kebab-case lowercase only): $NAME"
  exit 2
fi

DIR="$CS_ROOT/adapters/claude-code/user-level/skills/$NAME"
if [[ -e "$DIR" ]]; then
  cs_error "Already exists: $DIR"
  exit 2
fi

mkdir -p "$DIR"
cat > "$DIR/SKILL.md" <<EOF
---
name: $NAME
description: TODO
recommended_model: sonnet
---

# $NAME

## 目的

TODO: 1 文で。

## いつ発動するか

- TODO

## 手順

1. TODO

## チェックリスト

- [ ] TODO

## アンチパターン

- TODO

## 関連

- [\`practices/skill-design-guide.md\`](~/ws/claude-system/practices/skill-design-guide.md)
EOF

cs_success "Created $DIR/SKILL.md"
cs_info "Next:"
cs_info "  1. Edit SKILL.md (description must be <=50 chars, single line)"
cs_info "  2. Add a row to $CS_ROOT/adapters/claude-code/user-level/skills/_index.md"
cs_info "  3. Run tools/doctor.sh"

if [[ -n "${EDITOR:-}" ]]; then
  cs_info "Opening with \$EDITOR=$EDITOR"
  "$EDITOR" "$DIR/SKILL.md" || true
fi
