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

# ---------------------------------------------------------------------------
# SubagentStop transcript resolution (shared by subagent-stop-record.sh and
# subagent-stop-audit.sh)
# ---------------------------------------------------------------------------

# hk_resolve_agent_transcript <input_json> <main_transcript_path> <agent_id>
# Prints the resolved per-agent transcript path on stdout (empty if it
# cannot be determined). The path is a *candidate* — callers must still
# check `-f` before reading it, since a harness-internal helper agent has
# no per-agent transcript on disk at all.
#
# Resolution order:
#   1. The payload's own `.agent_transcript_path` (official field per the
#      public hooks schema, code.claude.com/docs/en/hooks.md as of 2026-07),
#      when present AND the file actually exists on disk.
#   2. The on-disk convention: `<session_dir>/subagents/agent-<agent_id>.jsonl`,
#      where session_dir is the MAIN session transcript path (the payload's
#      `.transcript_path`) with its `.jsonl` suffix stripped. Empirically
#      verified against real payloads; kept as a fallback in case the
#      official key is absent on some Claude Code versions (an earlier
#      commit found `.agent_transcript_path` unpopulated and removed it —
#      2026-06-06 — so both paths are exercised defensively here).
#
# The sidecar meta.json for either resolution is always the same basename
# with `.jsonl` swapped for `.meta.json` (verified against real payloads).
hk_resolve_agent_transcript() {
  local input="$1" main_transcript_path="$2" agent_id="$3"
  local agent_transcript
  agent_transcript="$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null || true)"
  if [[ -z "$agent_transcript" || ! -f "$agent_transcript" ]]; then
    agent_transcript=""
    if [[ -n "$agent_id" && -n "$main_transcript_path" ]]; then
      local session_dir="${main_transcript_path%.jsonl}"
      agent_transcript="$session_dir/subagents/agent-${agent_id}.jsonl"
    fi
  fi
  printf '%s' "$agent_transcript"
}

# ---------------------------------------------------------------------------
# Project hook dispatcher
# ---------------------------------------------------------------------------

# hk_dispatch_project_hook <hook-name>
# Reads the Claude Code JSON payload from stdin, then delegates to the
# project-local .claude/hooks/<hook-name>.sh when it exists and is executable.
# Forwards stdin verbatim to the project hook. Propagates the project hook's
# exit code on failure. Silent no-op when the project hook is absent.
#
# Usage (from a dispatcher script):
#   hk_dispatch_project_hook post-edit
#   exit 0
hk_dispatch_project_hook() {
  local hook_name="$1"
  local input
  input="$(hk_read_input)"
  local proj_hook="${PROJECT_ROOT}/.claude/hooks/${hook_name}.sh"
  if [[ -x "$proj_hook" ]]; then
    printf '%s' "$input" | "$proj_hook" || {
      # NB: keep `local rc=$?` on one line. `local rc; rc=$?` would clobber $?
      # because the bare `local` runs first and resets $? to 0.
      local rc=$?
      hk_log "${hook_name}-dispatcher" "project hook failed rc=${rc} ($(basename "$proj_hook"))"
      exit "$rc"
    }
  fi
}

# ---------------------------------------------------------------------------
# Forbidden-words helpers
# ---------------------------------------------------------------------------

# hk_check_forbidden_words <words-file> <input-source>
# Prints each forbidden word found in the input to stdout, one word per line.
# <input-source>: a file path to check on disk, or "-" to read from stdin.
# Silently returns 0 (no output) when words-file does not exist.
# Empty lines and comment lines (# ...) in words-file are skipped.
# Case-insensitive fixed-string match via grep -iF: forbidden words are
# literals (e.g. "claude.md", "settings.json"), not regex, so a BRE "." must
# not match an arbitrary character.
#
# Usage examples:
#   # check new content (stdin mode — caller pipes the content):
#   while IFS= read -r found; do
#     hk_deny PreToolUse "forbidden word '$found' in $path"
#   done < <(printf '%s' "$new_content" | hk_check_forbidden_words "$words_file" -)
#
#   # check a file on disk:
#   while IFS= read -r found; do
#     hk_warn "forbidden word '$found' in $path"
#   done < <(hk_check_forbidden_words "$words_file" "$path")
# ---------------------------------------------------------------------------
# Operator-identity path patterns (ADR 0008) — SINGLE SOURCE OF TRUTH.
#
# The same username reaches disk in more than one shape. Until 2026-08-09 only
# the slash form was checked, so the flattened form Claude Code uses for its own
# session directories sailed past every layer for three months. Add new shapes
# HERE, never inline in a hook.
#
# `.gitleaks.toml` cannot source shell, so it repeats these patterns as rules.
# tests/test-user-identifier-patterns.sh asserts the two stay in sync — that
# test is the mechanical guarantee that this list and the toml cannot diverge
# again. Update both, or the test fails.
#
# Placeholders (`-Users-<user>-`, `/Users/<name>/`) do not match: `<` and `>`
# are outside the character classes, which is deliberate.
HK_USER_IDENTIFIER_PATTERNS=(
  '/Users/[a-zA-Z0-9._-]+/'      # absolute macOS home path
  '-Users-[a-zA-Z0-9._]+-'       # Claude Code flattened project dir
)

# hk_scan_user_identifiers <file>
# Prints each pattern that matches the file, one per line. Silent when clean.
hk_scan_user_identifiers() {
  local target="$1"
  [[ -f "$target" ]] || return 0
  local pat
  for pat in "${HK_USER_IDENTIFIER_PATTERNS[@]}"; do
    if /usr/bin/grep -qE "$pat" "$target"; then
      printf '%s\n' "$pat"
    fi
  done
}

hk_check_forbidden_words() {
  local words_file="$1"
  local input_source="$2"
  [[ -f "$words_file" ]] || return 0

  local _hcfw_content=""
  if [[ "$input_source" == "-" ]]; then
    _hcfw_content="$(cat)"
  fi

  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    case "$word" in \#*) continue ;; esac
    if [[ "$input_source" == "-" ]]; then
      if printf '%s' "$_hcfw_content" | /usr/bin/grep -qiF "$word"; then
        printf '%s\n' "$word"
      fi
    else
      if /usr/bin/grep -qiF "$word" "$input_source"; then
        printf '%s\n' "$word"
      fi
    fi
  done < "$words_file"
}
