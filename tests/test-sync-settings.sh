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

# CS_BACKUP_ROOT must be unset, not just HOME overridden: tools/_lib.sh exports
# it, so when this test runs from a parent that already sourced _lib.sh (e.g.
# doctor.sh), the parent's real-HOME value leaks in and the run writes backups
# into the operator's actual ~/.claude-system-backups. Unsetting it lets _lib.sh
# re-derive the path from the throwaway HOME, which is also what we want to test.
run() {
  env -u CS_BACKUP_ROOT HOME="$TMP_HOME" "$ROOT/tools/sync-settings.sh" "$@"
}

SETTINGS="$TMP_HOME/.claude/settings.json"
OVERRIDES="$TMP_HOME/.claude/settings.machine-overrides.json"

# Derive the expected model from the template rather than hardcoding it. A
# literal here rots on every model switch: it was pinned to claude-fable-5 and
# went unnoticed from the ADR 0022 switch (2026-07-25) until ADR 0023, because
# this test was not wired into doctor.sh. What matters is that the renderer
# carries the template value through, not which model that value names.
TEMPLATE_MODEL="$(jq -r '.model' "$ROOT/adapters/claude-code/user-level/settings.json.template")"

# --- fresh apply (no overrides) ---------------------------------------------
run --apply >/dev/null
check "fresh apply writes settings.json" test -f "$SETTINGS"
check "fresh apply renders template model" \
  jq -e --arg m "$TEMPLATE_MODEL" '.model == $m' "$SETTINGS"
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
  jq -e --arg m "$TEMPLATE_MODEL" '.model == $m' "$SETTINGS"
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
