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
    while IFS= read -r found_word; do
      hk_warn "forbidden word '$found_word' present in $PATH_FIELD (post-edit-validate)"
    done < <(hk_check_forbidden_words "$WORDS_FILE" "$PATH_FIELD")
    ;;
esac

# 3. User-identifier path detection (ADR 0008, warn layer of two-stage defense).
# Absolute paths of the form /Users/<name>/... leak the operator identity.
# Skip hook scripts themselves: this very file embeds the pattern literal
# below and would self-trigger. .gitleaks.toml is intentionally NOT skipped
# here even though ADR 0008 Decision 3 enumerates it as a file that holds
# the pattern literal — warn is non-blocking, the commit-time gitleaks
# block layer (whose paths allowlist already contains '.gitleaks\.toml')
# is the real defense for that file, and adding a second skip rule would
# broaden the warn-layer allowlist surface for a harmless false-positive.
case "$PATH_FIELD" in
  */adapters/claude-code/user-level/hooks/*) ;;
  *)
    if /usr/bin/grep -qE '/Users/[a-zA-Z0-9._-]+/' "$PATH_FIELD"; then
      hk_warn "user-identifier path '/Users/<name>/' present in $PATH_FIELD (ADR 0008)"
    fi
    ;;
esac

exit 0
