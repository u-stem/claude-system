#!/usr/bin/env bash
# pre-bash-output-cap.sh — PreToolUse(Bash) — cap stdout of verbose test/build/
# lint commands to the last N lines before the output enters the model context.
# Token-economy mechanism (ADR 0012). Companion to log-bash-failure.sh.
#
# Mechanism: returns hookSpecificOutput.updatedInput.command (Claude Code
# v2.0.10+) rewriting the command so its stdout is piped through `tail -n N`.
# stderr is left untouched so log-bash-failure.sh (PostToolUse) still captures
# failures, and the original exit code is preserved via PIPESTATUS.
#
# Safety: only SIMPLE commands (no &&, ||, ;, |, &, redirection, command subst,
# newline) in the test/build/lint/typecheck category are rewritten. Compound or
# already-piped commands are passed through untouched, so this hook never emits
# an allow that could override a deny from pre-bash-guard.sh / check-package-age.sh.
#
# Disable: set CLAUDE_BASH_OUTPUT_CAP=0 (or use tools/disable-guardrails.sh).
# Cap size: CLAUDE_BASH_OUTPUT_CAP (default 200 lines).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

CAP="${CLAUDE_BASH_OUTPUT_CAP:-200}"
# Disabled when set to 0 / empty / non-numeric.
case "$CAP" in
  ''|*[!0-9]*) exit 0 ;;
esac
[[ "$CAP" -eq 0 ]] && exit 0

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
[[ -z "$cmd" ]] && exit 0

# Skip compound / already-routed / multi-line commands. Wrapping these is unsafe
# (could mangle semantics or override a sibling hook's deny on a destructive part).
case "$cmd" in
  *$'\n'*|*'&&'*|*'||'*|*';'*|*'|'*|*'&'*|*'>'*|*'<'*|*'$('*|*'`'*) exit 0 ;;
esac

# Only cap verbose, non-destructive build-loop commands.
if ! printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(test|pytest|vitest|jest|tsc|typecheck|type-check|mypy|pyright|lint|eslint|clippy|ruff|flake8|biome|build|compile)\b'; then
  exit 0
fi

# Rewrite: cap stdout, keep stderr, preserve the original exit code.
rewritten="$cmd | tail -n $CAP; exit \"\${PIPESTATUS[0]}\""

jq -nc --arg c "$rewritten" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: { command: $c }
  }
}'
exit 0
