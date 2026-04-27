#!/usr/bin/env bash
# pre-bash-guard.sh — PreToolUse(Bash) — block destructive commands.
# Layered defense: settings.json `permissions.deny` already blocks many of these;
# this hook catches dynamic/eval'd forms (e.g. `bash -c "..."`).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -z "$CMD" ]] && exit 0

# Patterns to block outright.
declare -a DENY_PATTERNS=(
  'rm[[:space:]]+-rf?[[:space:]]+~?/?\.claude(/|[[:space:]]|$)'
  'rm[[:space:]]+-rf?[[:space:]]+~?/?\.claude\*'
  'rm[[:space:]]+-rf?[[:space:]]+.*claude-settings'
  'rm[[:space:]]+-rf?[[:space:]]+.*claude-system'
  'git[[:space:]]+push[[:space:]]+(-f|--force)'
  'git[[:space:]]+commit[[:space:]].*--no-verify'
  'git[[:space:]]+commit[[:space:]].*--no-gpg-sign'
)

for pat in "${DENY_PATTERNS[@]}"; do
  if printf '%s' "$CMD" | /usr/bin/grep -qE "$pat"; then
    hk_log pre-bash-guard "deny: $pat (cmd: $CMD)"
    hk_deny PreToolUse "破壊的コマンドが検出されました(pre-bash-guard): $CMD"
  fi
done

# Patterns to ask user (destructive but sometimes intentional).
declare -a ASK_PATTERNS=(
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-[fdxX]'
  'git[[:space:]]+checkout[[:space:]]+\.'
  'git[[:space:]]+restore[[:space:]]+\.'
  'git[[:space:]]+branch[[:space:]]+-D'
)

for pat in "${ASK_PATTERNS[@]}"; do
  if printf '%s' "$CMD" | /usr/bin/grep -qE "$pat"; then
    hk_log pre-bash-guard "ask: $pat (cmd: $CMD)"
    hk_ask PreToolUse "破壊的 git コマンドが検出されました。意図を確認してください: $CMD"
  fi
done

exit 0
