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
# Patterns live in _lib.sh (HK_USER_IDENTIFIER_PATTERNS) rather than inline: this
# check previously hardcoded only the /Users/<name>/ form while .gitleaks.toml
# grew a second rule, and the two silently diverged. This hook is user-level, so
# it is the ONLY identifier check that runs in every project — repos other than
# claude-system have no .gitleaks.toml at all.
#
# Skip hook scripts themselves: _lib.sh holds the pattern literals and would
# self-trigger. .gitleaks.toml is intentionally NOT skipped even though it also
# holds them — warn is non-blocking, and the gitleaks block layer (whose paths
# allowlist already contains '.gitleaks\.toml') is the real defense for it.
case "$PATH_FIELD" in
  */adapters/claude-code/user-level/hooks/*) ;;
  *)
    while IFS= read -r matched_pattern; do
      hk_warn "user-identifier path matching '$matched_pattern' present in $PATH_FIELD (ADR 0008)"
    done < <(hk_scan_user_identifiers "$PATH_FIELD")
    ;;
esac

exit 0
