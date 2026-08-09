#!/usr/bin/env bash
# tests/test-guardrails-dry-run.sh — behavior tests for --dry-run on
# tools/disable-guardrails.sh and tools/enable-guardrails.sh.
#
# These two scripts are the emergency kill switch for the hook layer. Until now
# the only way to learn what they would do was to let them do it, which is a bad
# property for the one lever you reach for when the guardrails themselves are
# misbehaving. --dry-run must therefore be provably side-effect free.
#
# Runs against a throwaway HOME so the real ~/.claude is never touched.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/cs-test-guardrails.XXXXXX")"
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

# CS_BACKUP_ROOT must be unset rather than merely overriding HOME: tools/_lib.sh
# exports it, so a parent that already sourced _lib.sh (doctor.sh does) would
# leak its real-HOME value in and this test would write into the operator's
# actual ~/.claude-system-backups. Same rationale as tests/test-sync-settings.sh.
disable() {
  env -u CS_BACKUP_ROOT HOME="$TMP_HOME" "$ROOT/tools/disable-guardrails.sh" "$@"
}
enable() {
  env -u CS_BACKUP_ROOT HOME="$TMP_HOME" "$ROOT/tools/enable-guardrails.sh" "$@"
}

SETTINGS="$TMP_HOME/.claude/settings.json"
BACKUPS="$TMP_HOME/.claude-system-backups"

seed_settings() {
  mkdir -p "$TMP_HOME/.claude"
  printf '%s\n' \
    '{"model":"test-model","hooks":{"Stop":[{"hooks":[{"type":"command","command":"true"}]}]}}' \
    > "$SETTINGS"
}

# --- disable --dry-run is side-effect free -----------------------------------
seed_settings
before="$(cat "$SETTINGS")"
disable --dry-run >/dev/null 2>&1
after="$(cat "$SETTINGS")"

check "disable --dry-run leaves settings.json byte-identical" \
  test "$before" = "$after"
check "disable --dry-run does not create the backup directory" \
  test ! -d "$BACKUPS"
check "disable --dry-run reports the planned action" \
  bash -c 'env -u CS_BACKUP_ROOT HOME="$1" "$2/tools/disable-guardrails.sh" --dry-run 2>&1 | grep -q "would"' \
  _ "$TMP_HOME" "$ROOT"

# --- disable (real) still works ----------------------------------------------
disable >/dev/null 2>&1
check "disable clears the hooks section" \
  jq -e '.hooks == {}' "$SETTINGS"
check "disable records why the hooks were cleared" \
  jq -e 'has("// hooks-disabled-by")' "$SETTINGS"
check "disable preserves unrelated keys" \
  jq -e '.model == "test-model"' "$SETTINGS"
check "disable takes a backup" \
  bash -c 'ls "$1"/settings.json.backup-* >/dev/null 2>&1' _ "$BACKUPS"

# --- enable --dry-run is side-effect free ------------------------------------
# A backup now exists (created by the real disable above), so enable has
# something to restore from.
before="$(cat "$SETTINGS")"
backup_count_before="$(find "$BACKUPS" -name 'settings.json.backup-*' | wc -l | tr -d ' ')"
enable --dry-run >/dev/null 2>&1
after="$(cat "$SETTINGS")"
backup_count_after="$(find "$BACKUPS" -name 'settings.json.backup-*' | wc -l | tr -d ' ')"

check "enable --dry-run leaves settings.json byte-identical" \
  test "$before" = "$after"
check "enable --dry-run does not take a pre-restore backup" \
  test "$backup_count_before" = "$backup_count_after"
check "enable --dry-run names the backup it would restore" \
  bash -c 'env -u CS_BACKUP_ROOT HOME="$1" "$2/tools/enable-guardrails.sh" --dry-run 2>&1 | grep -q "would restore"' \
  _ "$TMP_HOME" "$ROOT"

# --- argument handling --------------------------------------------------------
# An unknown flag must fail loudly. Silently ignoring it on a kill switch would
# mean "--dry-run" typo'd as "--dryrun" performs the real action.
if disable --bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "FAIL: disable rejects unknown args" >&2
else
  PASS=$((PASS + 1))
fi
if enable --bogus >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "FAIL: enable rejects unknown args" >&2
else
  PASS=$((PASS + 1))
fi

check "disable --help still works" disable --help
check "enable --help still works" enable --help

# --- enable --dry-run with no backup present ----------------------------------
# Must fail rather than claim it would restore something that does not exist.
rm -f "$BACKUPS"/settings.json.backup-*
if enable --dry-run >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "FAIL: enable --dry-run fails when no backup exists" >&2
else
  PASS=$((PASS + 1))
fi

# --- summary -------------------------------------------------------------------
echo "test-guardrails-dry-run: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
