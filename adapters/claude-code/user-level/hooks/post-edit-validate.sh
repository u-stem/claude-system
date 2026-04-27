#!/usr/bin/env bash
# post-edit-validate.sh — PostToolUse(Edit|Write) — quick correctness checks
# on the edited file. Keep <1s. Reports warnings via stderr; does not block.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

PATH_FIELD="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
[[ -z "$PATH_FIELD" ]] && exit 0
[[ ! -f "$PATH_FIELD" ]] && exit 0

# 1. SKILL.md frontmatter validation.
if [[ "$(basename "$PATH_FIELD")" == "SKILL.md" ]]; then
  for field in name description recommended_model; do
    if ! head -10 "$PATH_FIELD" | /usr/bin/grep -q "^${field}:"; then
      hk_warn "SKILL.md missing '$field': $PATH_FIELD"
    fi
  done
  desc="$(/usr/bin/grep '^description:' "$PATH_FIELD" | head -1 | sed 's/^description: //')"
  chars="$(printf '%s' "$desc" | wc -m | tr -d ' ')"
  if [[ "$chars" -gt 50 ]]; then
    hk_warn "SKILL.md description exceeds 50 chars ($chars): $PATH_FIELD"
  fi
fi

# 2. principles/practices forbidden-words check on disk content (defense in depth
# beyond pre-edit-protect, which inspects only the new content fragment).
case "$PATH_FIELD" in
  */principles/*|*/practices/*)
    WORDS_FILE="$CS_ROOT/meta/forbidden-words.txt"
    if [[ -f "$WORDS_FILE" ]]; then
      while IFS= read -r word; do
        [[ -z "$word" ]] && continue
        case "$word" in \#*) continue ;; esac
        if /usr/bin/grep -qi "$word" "$PATH_FIELD"; then
          hk_warn "forbidden word '$word' present in $PATH_FIELD (post-edit-validate)"
        fi
      done < "$WORDS_FILE"
    fi
    ;;
esac

exit 0
