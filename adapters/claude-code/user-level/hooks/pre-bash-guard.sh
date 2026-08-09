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

# Identity of the caller. `agent_type` / `agent_id` are present in the
# PreToolUse payload only when the call comes from inside a subagent — measured
# 2026-08-09 on 2.1.226: a main-session call carries
#   [cwd, effort, hook_event_name, permission_mode, prompt_id, session_id,
#    tool_input, tool_name, tool_use_id, transcript_path]
# while a subagent call adds agent_id + agent_type (observed agent_type=
# code-reviewer). This is the only verified signal that distinguishes the two;
# SessionStart's `source` does not (its values are startup/resume/clear/compact/
# fork, none of which mean "unattended").
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"

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

# Ban `cd`: the session already starts in the working directory, so `cd` is
# unnecessary and slows things down. Repeatedly used despite instructions, so
# enforce mechanically here (applies to subagent Bash calls too). Matches `cd`
# at a command position: start, or after ; & | ( { (covers `&& cd`, `| cd`,
# `(cd ...)`). Does NOT match substrings like `cdk` / paths containing "cd".
if printf '%s' "$CMD" | /usr/bin/grep -qE '(^|[;&|({])[[:space:]]*cd([[:space:]]|$)'; then
  hk_log pre-bash-guard "deny cd (cmd: $CMD)"
  hk_deny PreToolUse "cd は禁止です(既にカレントディレクトリで起動済み)。絶対パス、または git -C <dir> / make -C <dir> / bun --cwd <dir> 等の cwd 指定フラグを使ってください。コマンド: $CMD"
fi

# Subagents must not push. v2.1.221 changed background/agent sessions to commit
# and push on their own to "preserve work"; on 2026-08-09 that published 10
# commits straight to a public main from this repo without the operator asking.
# The user-level CLAUDE.md §8 prohibition did not stop it — a subagent has no
# one to ask, so a written rule is the wrong layer. Enforce it here instead.
# Commit is still allowed: work on a branch is not lost, it just isn't published.
# The main session is unaffected (no agent_type), so the operator can still push.
if [[ -n "$AGENT_TYPE" ]] \
  && printf '%s' "$CMD" | /usr/bin/grep -qE '(^|[;&|({])[[:space:]]*git[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)'; then
  hk_log pre-bash-guard "deny subagent push (agent_type: $AGENT_TYPE, cmd: $CMD)"
  hk_deny PreToolUse "subagent からの git push は禁止です(agent_type: $AGENT_TYPE)。commit までに留め、push はメインセッションで運用者の確認を経てください(ADR 0023 §8)。コマンド: $CMD"
fi

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
