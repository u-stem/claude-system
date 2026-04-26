#!/usr/bin/env bash
# tests/lint-principles-language.sh — fail if any forbidden tool-specific word
# appears in principles/ or practices/.
# Source of truth: meta/forbidden-words.txt

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir
cd "$CS_ROOT"

WORDS_FILE="meta/forbidden-words.txt"
if [[ ! -f "$WORDS_FILE" ]]; then
  cs_error "missing $WORDS_FILE"
  exit 1
fi

ERRORS=0
while IFS= read -r word; do
  [[ -z "$word" ]] && continue
  case "$word" in \#*) continue ;; esac
  matches="$(grep -ril "$word" principles/ practices/ 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    while IFS= read -r m; do
      cs_error "forbidden word '$word' in $m"
      ERRORS=$((ERRORS + 1))
    done <<<"$matches"
  fi
done < "$WORDS_FILE"

if [[ $ERRORS -gt 0 ]]; then
  cs_error "lint-principles-language: $ERRORS leak(s)"
  exit 1
fi
cs_success "lint-principles-language: clean"
