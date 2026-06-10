#!/usr/bin/env bash
# tests/test-sync-settings.sh — behavior tests for tools/sync-settings.sh.
# Runs against a throwaway HOME so the real ~/.claude is never touched.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/cs-test-sync-settings.XXXXXX")"
trap 'rm -rf "$TMP_HOME"' EXIT

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name" >&2
  fi
}

run() {
  HOME="$TMP_HOME" "$ROOT/tools/sync-settings.sh" "$@"
}

SETTINGS="$TMP_HOME/.claude/settings.json"
OVERRIDES="$TMP_HOME/.claude/settings.machine-overrides.json"

# --- fresh apply (no overrides) ---------------------------------------------
run --apply >/dev/null
check "fresh apply writes settings.json" test -f "$SETTINGS"
check "fresh apply renders template model" \
  jq -e '.model == "claude-fable-5"' "$SETTINGS"
check "rendered file carries managed marker" \
  jq -e 'has("// managed")' "$SETTINGS"
check "check exits 0 when in sync" run --check

# --- overrides merge ---------------------------------------------------------
mkdir -p "$TMP_HOME/.claude"
printf '%s\n' '{"effortLevel": "medium", "agentPushNotifEnabled": true}' > "$OVERRIDES"
if ! run --check; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: check exits 1 on drift" >&2
fi
run --apply >/dev/null
check "override key wins over template" \
  jq -e '.effortLevel == "medium"' "$SETTINGS"
check "override-only key is added" \
  jq -e '.agentPushNotifEnabled == true' "$SETTINGS"
check "non-overridden template key survives merge" \
  jq -e '.model == "claude-fable-5"' "$SETTINGS"
check "template policy arrays survive merge" \
  jq -e '(.permissions.deny | length) > 0' "$SETTINGS"

# --- idempotency -------------------------------------------------------------
before="$(cat "$SETTINGS")"
run --apply >/dev/null
after="$(cat "$SETTINGS")"
check "re-apply is idempotent" test "$before" = "$after"
check "apply creates a backup of the previous file" \
  bash -c 'ls "$1"/.claude-system-backups/settings.json.backup-* >/dev/null 2>&1' _ "$TMP_HOME"

# --- summary -----------------------------------------------------------------
echo "test-sync-settings: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
