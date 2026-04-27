#!/usr/bin/env bash
# log-bash-failure.sh — PostToolUse(Bash) — categorize & log failures for the
# self-referential feedback loop. Migrated from claude-settings/hooks/log-bash-failure.sh
# (absolute path to log-failure.sh replaced with $HOME-relative path via _lib.sh).
#
# Companion: check-failure-patterns.sh (SessionStart) reads the same log.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

exit_code="$(printf '%s' "$INPUT" | jq -r '.tool_result.exitCode // .tool_result.exit_code // 0' 2>/dev/null || echo 0)"
if [[ "$exit_code" == "0" || -z "$exit_code" || "$exit_code" == "null" ]]; then
  exit 0
fi

cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
stderr="$(printf '%s' "$INPUT" | jq -r '.tool_result.stderr // empty' 2>/dev/null || true)"

[[ -z "$stderr" ]] && exit 0

# Categorize.
category="unknown"
if printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(test|pytest|vitest|jest)\b'; then
  category="test"
elif printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(tsc|typecheck|type-check|mypy|pyright)\b'; then
  category="check-types"
elif printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(lint|eslint|clippy|ruff|flake8|biome)\b'; then
  category="check"
fi

printf '%s' "$stderr" | "$HOOKS_LIB_DIR/log-failure.sh" "$category"
