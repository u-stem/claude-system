#!/usr/bin/env bash
# tests/test-pre-bash-guard.sh — behavior tests for the PreToolUse Bash guard.
#
# Focus: the subagent push guard added in the ADR 0023 follow-up. v2.1.221 made
# background/agent sessions commit and push on their own; on 2026-08-09 that
# published 10 commits to a public main unasked. `agent_type` is present in the
# PreToolUse payload only for subagent calls (measured on 2.1.226), so the guard
# keys off it. These tests pin both directions so the distinction cannot rot.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/adapters/claude-code/user-level/hooks/pre-bash-guard.sh"

PASS=0
FAIL=0

# decision <payload-json> -> "deny" | "ask" | "allow"
decision() {
  local out
  out="$(printf '%s' "$1" | bash "$HOOK" 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    echo "allow"
  else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null || echo "allow"
  fi
}

check() {
  local name="$1" want="$2" payload="$3"
  local got
  got="$(decision "$payload")"
  if [[ "$got" == "$want" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (want=$want got=$got)" >&2
  fi
}

sub()  { printf '{"tool_name":"Bash","agent_type":"%s","agent_id":"a1","tool_input":{"command":%s}}' "$1" "$(jq -Rn --arg c "$2" '$c')"; }
main() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')"; }

# --- subagent push is denied -------------------------------------------------
check "subagent plain push denied"      deny  "$(sub code-reviewer 'git push origin main')"
check "subagent bare push denied"       deny  "$(sub implementer   'git push')"
check "subagent chained push denied"    deny  "$(sub implementer   'git add -A && git commit -m x && git push')"
check "subagent push with flags denied" deny  "$(sub doc-writer    'git push --set-upstream origin feat/x')"

# Invocation forms the first implementation missed. A regex looking for "git"
# followed by "push" anywhere sees none of these as a push (2026-08-09 review).
check "absolute path git denied"        deny  "$(sub code-reviewer '/usr/bin/git push')"
check "command-prefixed git denied"     deny  "$(sub code-reviewer 'command git push')"
check "env-prefixed git denied"         deny  "$(sub code-reviewer 'env git push')"
check "nohup-prefixed git denied"       deny  "$(sub code-reviewer 'nohup git push')"
check "xargs-prefixed git denied"       deny  "$(sub code-reviewer 'xargs git push')"
check "sh -c wrapped push denied"       deny  "$(sub code-reviewer 'sh -c "git push"')"
check "bash -c wrapped push denied"     deny  "$(sub code-reviewer 'bash -c "git push origin main"')"

# Global options that take a value must not be mistaken for the subcommand.
check "git -C <dir> push denied"        deny  "$(sub code-reviewer 'git -C /tmp/repo push')"
check "git -c <cfg> push denied"        deny  "$(sub code-reviewer 'git -c user.name=x push')"
check "git --git-dir <d> push denied"   deny  "$(sub code-reviewer 'git --git-dir /tmp/.git push')"

# --- the main session keeps pushing -----------------------------------------
# The operator drives the main session, so §6-2's "confirm outward actions"
# applies there and a mechanical block would only add friction.
check "main session push allowed"       allow "$(main 'git push origin main')"

# --- commit is never blocked by this rule -----------------------------------
# Work committed to a branch is not lost; only publishing is withheld.
check "subagent commit allowed"         allow "$(sub code-reviewer 'git commit -m msg')"
check "subagent add allowed"            allow "$(sub code-reviewer 'git add -A')"

# --- no false positives ------------------------------------------------------
check "word 'push' in echo allowed"     allow "$(sub explorer 'echo do not push this')"

# The first implementation denied these: it saw "git ... push" and stopped
# looking. Blocking a commit whose message mentions pushing is the opposite of
# what the rule promises, and "push" is a very ordinary word in a message.
check "commit msg mentioning push ok"   allow "$(sub code-reviewer "git commit -m 'fix push behavior'")"
check "commit msg 'push notification'"  allow "$(sub code-reviewer "git commit -m 'add push notification'")"
check "git log --grep push allowed"     allow "$(sub code-reviewer 'git log --grep push')"
check "prose about pushing allowed"     allow "$(sub explorer 'echo about to git push soon')"
check "git status allowed"              allow "$(sub code-reviewer 'git status')"
check "subcommand prefix 'pushx' ok"    allow "$(sub code-reviewer 'git pushx')"

# --- the force rule is independent of agent_type ------------------------------
check "force push denied in main"       deny  "$(main 'git push --force origin main')"

echo "test-pre-bash-guard: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
