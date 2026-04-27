#!/usr/bin/env bash
# adapters/claude-code/user-level/hooks/_lib.sh
# Common helpers for Claude Code hooks. Sourced by every hook in this directory.
#
# Hook contract:
#   - input: JSON on stdin (provided by Claude Code)
#   - output: optional JSON on stdout (hookSpecificOutput); plain stderr is for human logs
#   - exit 0   = allow / continue
#   - exit 2   = blocking error (tool call denied)
#   - exit !=0 (other) = treated as warning by Claude Code
#
# Performance budget: <1s per hook invocation. Fail open on transient errors
# unless the check is security-critical (typosquatting / forbidden-words).

if [[ -n "${_CLAUDE_HOOKS_LIB_LOADED:-}" ]]; then
  return 0
fi
_CLAUDE_HOOKS_LIB_LOADED=1

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# claude-system root, relative to this file (hooks/_lib.sh -> ../../../..).
HOOKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS_ROOT="$(cd "$HOOKS_LIB_DIR/../../../.." && pwd)"
export CS_ROOT

CS_BACKUP_ROOT="${CS_BACKUP_ROOT:-$HOME/.claude-system-backups}"
HOOK_LOG_DIR="$CS_BACKUP_ROOT/hook-logs"
export CS_BACKUP_ROOT HOOK_LOG_DIR

# Project root (set by Claude Code when available). Exported so dispatchers can read it.
export PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
export HOOKS_LIB_DIR

# ---------------------------------------------------------------------------
# Color output (only when stderr is a tty — most hook calls are non-tty)
# ---------------------------------------------------------------------------

if [[ -t 2 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  HK_RESET=$'\033[0m'
  HK_RED=$'\033[31m'
  HK_GREEN=$'\033[32m'
  HK_YELLOW=$'\033[33m'
else
  HK_RESET=""; HK_RED=""; HK_GREEN=""; HK_YELLOW=""
fi

hk_info()  { printf '[hook] %s\n' "$*" >&2; }
hk_warn()  { printf '%s[hook][WARN]%s %s\n' "$HK_YELLOW" "$HK_RESET" "$*" >&2; }
hk_error() { printf '%s[hook][ERROR]%s %s\n' "$HK_RED" "$HK_RESET" "$*" >&2; }
hk_ok()    { printf '%s[hook][ok]%s %s\n' "$HK_GREEN" "$HK_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# Hook log (diagnostic, not security-relevant)
# ---------------------------------------------------------------------------

hk_log() {
  # hk_log <hook-name> <message>
  local name="$1"; shift
  local msg="$*"
  mkdir -p "$HOOK_LOG_DIR" 2>/dev/null || return 0
  local logfile="$HOOK_LOG_DIR/${name}.log"
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg" >> "$logfile" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Hook output helpers (Claude Code hookSpecificOutput JSON)
# ---------------------------------------------------------------------------

# hk_deny <event> <reason>     — emit deny JSON, then exit 0 (Claude Code
#                                interprets the JSON; non-zero would be
#                                treated as a hook failure rather than tool deny).
hk_deny() {
  local event="$1"; local reason="$2"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","permissionDecision":"deny","permissionDecisionReason":%s}}\n' \
    "$event" "$(printf '%s' "$reason" | jq -Rs .)"
  exit 0
}

# hk_ask <event> <reason>      — emit ask JSON, exit 0
hk_ask() {
  local event="$1"; local reason="$2"
  printf '{"hookSpecificOutput":{"hookEventName":"%s","permissionDecision":"ask","permissionDecisionReason":%s}}\n' \
    "$event" "$(printf '%s' "$reason" | jq -Rs .)"
  exit 0
}

# hk_pass — silent allow (default). Use plain `exit 0` instead unless you want
# a JSON allow record.

# ---------------------------------------------------------------------------
# stdin helpers
# ---------------------------------------------------------------------------

# Read up to 1 MiB from stdin (hook payloads are tiny; cap to avoid pathological cases).
hk_read_input() {
  if [[ -t 0 ]]; then
    echo ""
    return
  fi
  head -c 1048576
}
