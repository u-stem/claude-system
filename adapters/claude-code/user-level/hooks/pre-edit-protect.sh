#!/usr/bin/env bash
# pre-edit-protect.sh — PreToolUse(Edit|Write) — protect read-only locations
# and run forbidden-words check on principles/practices edits.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

PATH_FIELD="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || true)"
[[ -z "$PATH_FIELD" ]] && exit 0

# 1. Block writes to legacy archive / backup files (defense in depth: settings.json
# permissions.deny already blocks these; this hook catches edge cases).
case "$PATH_FIELD" in
  *claude-settings/*)
    hk_log pre-edit-protect "deny: claude-settings/ ($PATH_FIELD)"
    hk_deny PreToolUse "claude-settings/ は読み取り専用アーカイブです: $PATH_FIELD"
    ;;
  *.backup-*)
    hk_log pre-edit-protect "deny: backup file ($PATH_FIELD)"
    hk_deny PreToolUse "*.backup-* は人手バックアップ原本です: $PATH_FIELD"
    ;;
esac

# 2. principles/ practices/ edits → check for forbidden words in NEW content.
case "$PATH_FIELD" in
  */principles/*|*/practices/*)
    NEW_CONTENT="$(printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null || true)"
    if [[ -n "$NEW_CONTENT" ]]; then
      WORDS_FILE="$CS_ROOT/meta/forbidden-words.txt"
      while IFS= read -r found_word; do
        hk_log pre-edit-protect "forbidden word '$found_word' in $PATH_FIELD"
        hk_deny PreToolUse "principles/practices に禁止語 '$found_word' が含まれています($PATH_FIELD)。adapters/ 以下に移動してください。"
      done < <(printf '%s' "$NEW_CONTENT" | hk_check_forbidden_words "$WORDS_FILE" -)
    fi
    ;;
esac

exit 0
