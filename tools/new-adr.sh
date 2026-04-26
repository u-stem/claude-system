#!/usr/bin/env bash
# tools/new-adr.sh — scaffold a new ADR file in the current project's docs/adr/.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
new-adr.sh — create a new ADR scaffold.

Usage:
  tools/new-adr.sh <slug>                Use $PWD/docs/adr/
  tools/new-adr.sh <slug> <project-dir>  Explicit project root
  tools/new-adr.sh --help

Auto-numbers based on existing NNNN-*.md files in docs/adr/.
Template: $CS_ROOT/adapters/claude-code/project-fragments/adr-template.md
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  cs_error "Usage: tools/new-adr.sh <slug> [<project-dir>]"
  exit 2
fi

SLUG="$1"
PROJ_DIR="${2:-$PWD}"

if [[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
  cs_error "Invalid slug (kebab-case lowercase only): $SLUG"
  exit 2
fi

ADR_DIR="$PROJ_DIR/docs/adr"
mkdir -p "$ADR_DIR"

# Determine next number.
last="$(find "$ADR_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' \
        | sed -E 's|.*/([0-9]{4})-.*|\1|' | sort -n | tail -1 || true)"
if [[ -z "$last" ]]; then
  next="0001"
else
  next="$(printf '%04d' $((10#$last + 1)))"
fi

OUT="$ADR_DIR/${next}-${SLUG}.md"
if [[ -f "$OUT" ]]; then
  cs_error "Already exists: $OUT"
  exit 2
fi

# Pull template body and substitute.
TEMPLATE="$CS_ROOT/adapters/claude-code/project-fragments/adr-template.md"
if [[ ! -f "$TEMPLATE" ]]; then
  cs_error "Template missing: $TEMPLATE"
  exit 2
fi

# Extract the fenced markdown block from the template.
awk '
  /^```markdown$/ { capture=1; next }
  /^```$/ && capture { capture=0; next }
  capture { print }
' "$TEMPLATE" > "$OUT"

if [[ ! -s "$OUT" ]]; then
  cs_warn "Template fence extraction yielded empty output; falling back to inline."
  cat > "$OUT" <<EOF
# ADR ${next}: ${SLUG}

- **Status**: Proposed
- **Date**: $(date +%Y-%m-%d)
- **Decider**: プロジェクトオーナー

## Context

TODO

## Decision

TODO

## Consequences

### Positive
-

### Negative
-

### Neutral
-

## Related

-
EOF
fi

# Replace placeholder NNNN with the actual number.
cs_sed_inplace "s|ADR NNNN|ADR ${next}|" "$OUT"
cs_sed_inplace "1s|<短いタイトル>|${SLUG}|" "$OUT"
cs_sed_inplace "s|YYYY-MM-DD|$(date +%Y-%m-%d)|" "$OUT"

cs_success "Created $OUT"
cs_info "Edit it: open $OUT"
