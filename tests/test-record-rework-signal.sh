#!/usr/bin/env bash
# tests/test-record-rework-signal.sh — behavior tests for the rework-signal hook.
#
# The hook exists to measure, not to judge: it must never block, never fail a
# tool call, and never leak the operator's home path into a repo-adjacent log
# (ADR 0008). Those three properties are what these tests pin down.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOK="$CS_ROOT/adapters/claude-code/user-level/hooks/record-rework-signal.sh"
[[ -x "$HOOK" ]] || { cs_error "hook missing or not executable: $HOOK"; exit 1; }

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PROJ="$TMP/proj"
mkdir -p "$PROJ"
LOG="$PROJ/.claude/rework-log.jsonl"

# Emit an Edit payload for <file>, optionally as a subagent.
payload() {
  local file="$1" agent="${2:-}"
  if [[ -n "$agent" ]]; then
    jq -nc --arg f "$file" --arg a "$agent" \
      '{tool_name:"Edit",tool_input:{file_path:$f},session_id:"sess-1",agent_type:$a,agent_id:"ag-9"}'
  else
    jq -nc --arg f "$file" \
      '{tool_name:"Edit",tool_input:{file_path:$f},session_id:"sess-1"}'
  fi
}

run_hook() { CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK"; }

# --- 1. a normal edit is recorded ---------------------------------------------
payload "$PROJ/tools/foo.sh" | run_hook >/dev/null 2>&1
[[ -f "$LOG" ]] || err "Test 1: expected $LOG to be created"
[[ "$(wc -l < "$LOG" | tr -d ' ')" == "1" ]] \
  || err "Test 1: expected exactly 1 record, got $(wc -l < "$LOG")"

# --- 2. the path is stored relative to the project ----------------------------
# An absolute path would embed /Users/<name>, which ADR 0008 forbids in tree
# artifacts and .gitleaks.toml blocks at commit time.
[[ "$(jq -r '.file' "$LOG")" == "tools/foo.sh" ]] \
  || err "Test 2: expected a project-relative path, got $(jq -r '.file' "$LOG")"

# --- 3. no operator identifier reaches the log --------------------------------
for pat in "${HK_USER_IDENTIFIER_PATTERNS[@]:-/Users/[a-zA-Z0-9._-]+}"; do
  if /usr/bin/grep -qE "$pat" "$LOG"; then
    err "Test 3: operator identifier matching '$pat' leaked into the log"
  fi
done

# --- 4. repeated edits accumulate ---------------------------------------------
payload "$PROJ/tools/foo.sh" | run_hook >/dev/null 2>&1
payload "$PROJ/tools/foo.sh" | run_hook >/dev/null 2>&1
[[ "$(jq -rs 'map(select(.file == "tools/foo.sh")) | length' "$LOG")" == "3" ]] \
  || err "Test 4: expected 3 records for the same file, got $(jq -rs 'map(select(.file == "tools/foo.sh")) | length' "$LOG")"

# --- 5. subagent attribution is preserved --------------------------------------
# Whether a subagent's payload carries the main session_id is unknown, so both
# identifiers are recorded and the grouping decision is deferred to the data.
payload "$PROJ/tools/bar.sh" "implementer" | run_hook >/dev/null 2>&1
[[ "$(jq -rs 'map(select(.agent_type == "implementer")) | length' "$LOG")" == "1" ]] \
  || err "Test 5: expected the subagent record to carry agent_type"
[[ "$(jq -rs '.[-1].session_id' "$LOG")" == "sess-1" ]] \
  || err "Test 5: expected session_id to be recorded alongside agent_type"

# --- 6. every line is valid JSON ------------------------------------------------
while IFS= read -r line; do
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 \
    || err "Test 6: emitted a line that is not valid JSON: $line"
done < "$LOG"

# --- 7. a payload without a file path is ignored ---------------------------------
before="$(wc -l < "$LOG" | tr -d ' ')"
printf '{"tool_name":"Edit","tool_input":{}}' | run_hook >/dev/null 2>&1
[[ "$(wc -l < "$LOG" | tr -d ' ')" == "$before" ]] \
  || err "Test 7: a payload with no file_path should not be recorded"

# --- 8. empty stdin exits cleanly -------------------------------------------------
if printf '' | run_hook >/dev/null 2>&1; then :; else
  err "Test 8: empty stdin must exit 0 (hooks fail open)"
fi

# --- 9. malformed stdin exits cleanly ----------------------------------------------
if printf 'not json' | run_hook >/dev/null 2>&1; then :; else
  err "Test 9: malformed stdin must exit 0 (hooks fail open)"
fi

# --- 10. an unwritable log directory does not fail the tool call ---------------------
PROJ_RO="$TMP/readonly"
mkdir -p "$PROJ_RO"
chmod 500 "$PROJ_RO"
if jq -nc --arg f "$PROJ_RO/x.sh" '{tool_name:"Edit",tool_input:{file_path:$f},session_id:"s"}' \
   | CLAUDE_PROJECT_DIR="$PROJ_RO" bash "$HOOK" >/dev/null 2>&1; then :; else
  err "Test 10: an unwritable project dir must still exit 0"
fi
chmod 700 "$PROJ_RO"

# --- 11. a path outside the project is not recorded verbatim -------------------------
payload "/etc/hosts" | run_hook >/dev/null 2>&1
if jq -rs '.[-1].file' "$LOG" | /usr/bin/grep -q '^/etc/hosts$'; then
  err "Test 11: an out-of-project absolute path was recorded verbatim"
fi

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-record-rework-signal: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-record-rework-signal: all tests pass"
