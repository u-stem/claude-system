#!/usr/bin/env bash
# tests/test-hooks-lib.sh — behavioral unit tests for the new helper functions
# added to adapters/claude-code/user-level/hooks/_lib.sh:
#
#   hk_dispatch_project_hook <hook-name>
#   hk_check_forbidden_words <words-file> <input-source>
#
# Verifies:
#   (A) hk_dispatch_project_hook: stdin forwarded to a synthetic project hook
#   (B) hk_dispatch_project_hook: silent no-op when project hook is absent
#   (C) hk_dispatch_project_hook: propagates non-zero exit from project hook
#   (D) hk_check_forbidden_words: detects forbidden word via stdin mode
#   (E) hk_check_forbidden_words: no output when stdin content is clean
#   (F) hk_check_forbidden_words: detects forbidden word in a file
#   (G) hk_check_forbidden_words: no output when file content is clean
#   (H) hk_check_forbidden_words: silent no-op when words file is absent
#
# Fixtures: synthetic scripts and word lists in mktemp dirs.
# CS_BACKUP_ROOT is overridden per test to keep hook logs in tmpdir.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

HOOKS_DIR="$CS_ROOT/adapters/claude-code/user-level/hooks"
LIB="$HOOKS_DIR/_lib.sh"

if [[ ! -f "$LIB" ]]; then
  cs_error "_lib.sh not found: $LIB"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

# ---------------------------------------------------------------------------
# Fixture: isolated temp dir per test run
# ---------------------------------------------------------------------------

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# run_lib_fn [env=NAME=VALUE ...] <bash-code>
# Evaluates <bash-code> inside a fresh bash that sources the hooks _lib.sh.
# Any NAME=VALUE pairs placed before bash-code are exported into that shell.
# Stdin is inherited from the caller (so pipes work).
run_lib_fn() {
  local env_args=()
  while [[ "$1" == *=* ]]; do
    env_args+=("$1")
    shift
  done
  env "${env_args[@]}" bash -c "source \"$LIB\"; $1"
}

# ---------------------------------------------------------------------------
# Test A: hk_dispatch_project_hook — stdin forwarded to project hook
# ---------------------------------------------------------------------------

mkdir -p "$TMPDIR_TEST/ta/.claude/hooks"

# Project hook writes its stdin to a capture file.
cat > "$TMPDIR_TEST/ta/.claude/hooks/post-edit.sh" << 'HOOK_EOF'
#!/usr/bin/env bash
cat > "$CAPTURE_FILE"
HOOK_EOF
chmod +x "$TMPDIR_TEST/ta/.claude/hooks/post-edit.sh"

CAPTURE_A="$TMPDIR_TEST/ta/captured.txt"
TEST_PAYLOAD_A='{"tool":"Edit","path":"/tmp/x.ts"}'

printf '%s' "$TEST_PAYLOAD_A" \
  | run_lib_fn \
      "CLAUDE_PROJECT_DIR=$TMPDIR_TEST/ta" \
      "CS_BACKUP_ROOT=$TMPDIR_TEST/ta/bk" \
      "CAPTURE_FILE=$CAPTURE_A" \
      "hk_dispatch_project_hook post-edit"

if [[ ! -f "$CAPTURE_A" ]]; then
  err "Test A: capture file not created — stdin was not forwarded to project hook"
else
  captured_a="$(cat "$CAPTURE_A")"
  [[ "$captured_a" == "$TEST_PAYLOAD_A" ]] \
    || err "Test A [content]: expected JSON payload, got '$(printf '%s' "$captured_a" | head -c 120)'"
fi

# ---------------------------------------------------------------------------
# Test B: hk_dispatch_project_hook — no-op when project hook is absent
# ---------------------------------------------------------------------------

# $TMPDIR_TEST/tb has no .claude/hooks/ at all
exit_b=0
printf '{}' \
  | run_lib_fn \
      "CLAUDE_PROJECT_DIR=$TMPDIR_TEST/tb" \
      "CS_BACKUP_ROOT=$TMPDIR_TEST/tb/bk" \
      "hk_dispatch_project_hook post-edit" \
  || exit_b=$?

[[ $exit_b -eq 0 ]] \
  || err "Test B: expected exit 0 when project hook absent, got $exit_b"

# ---------------------------------------------------------------------------
# Test C: hk_dispatch_project_hook — propagates project hook exit code
# ---------------------------------------------------------------------------

mkdir -p "$TMPDIR_TEST/tc/.claude/hooks"

cat > "$TMPDIR_TEST/tc/.claude/hooks/post-stop.sh" << 'HOOK_EOF'
#!/usr/bin/env bash
exit 42
HOOK_EOF
chmod +x "$TMPDIR_TEST/tc/.claude/hooks/post-stop.sh"

exit_c=0
printf '{}' \
  | run_lib_fn \
      "CLAUDE_PROJECT_DIR=$TMPDIR_TEST/tc" \
      "CS_BACKUP_ROOT=$TMPDIR_TEST/tc/bk" \
      "hk_dispatch_project_hook post-stop" \
  || exit_c=$?

[[ $exit_c -eq 42 ]] \
  || err "Test C: expected exit 42 from failing project hook, got $exit_c"

# ---------------------------------------------------------------------------
# Test D: hk_check_forbidden_words — detects forbidden word via stdin mode
# ---------------------------------------------------------------------------

printf 'skill\nsubagent\n' > "$TMPDIR_TEST/words.txt"

found_d="$(
  printf 'this uses skill-based routing' \
    | run_lib_fn \
        "CS_BACKUP_ROOT=$TMPDIR_TEST/d/bk" \
        "hk_check_forbidden_words \"$TMPDIR_TEST/words.txt\" -"
)"

[[ "$found_d" == "skill" ]] \
  || err "Test D: expected 'skill', got '$(printf '%s' "$found_d" | head -c 80)'"

# ---------------------------------------------------------------------------
# Test E: hk_check_forbidden_words — no output when stdin content is clean
# ---------------------------------------------------------------------------

found_e="$(
  printf 'this is clean content with no forbidden terms' \
    | run_lib_fn \
        "CS_BACKUP_ROOT=$TMPDIR_TEST/e/bk" \
        "hk_check_forbidden_words \"$TMPDIR_TEST/words.txt\" -"
)"

[[ -z "$found_e" ]] \
  || err "Test E: expected empty output for clean stdin, got '$found_e'"

# ---------------------------------------------------------------------------
# Test F: hk_check_forbidden_words — detects forbidden word in a file
# ---------------------------------------------------------------------------

printf 'this file references a subagent definition\n' > "$TMPDIR_TEST/dirty-file.txt"

found_f="$(
  run_lib_fn \
    "CS_BACKUP_ROOT=$TMPDIR_TEST/f/bk" \
    "hk_check_forbidden_words \"$TMPDIR_TEST/words.txt\" \"$TMPDIR_TEST/dirty-file.txt\""
)"

[[ "$found_f" == "subagent" ]] \
  || err "Test F: expected 'subagent', got '$(printf '%s' "$found_f" | head -c 80)'"

# ---------------------------------------------------------------------------
# Test G: hk_check_forbidden_words — no output for clean file
# ---------------------------------------------------------------------------

printf 'this file is perfectly clean\n' > "$TMPDIR_TEST/clean-file.txt"

found_g="$(
  run_lib_fn \
    "CS_BACKUP_ROOT=$TMPDIR_TEST/g/bk" \
    "hk_check_forbidden_words \"$TMPDIR_TEST/words.txt\" \"$TMPDIR_TEST/clean-file.txt\""
)"

[[ -z "$found_g" ]] \
  || err "Test G: expected empty output for clean file, got '$found_g'"

# ---------------------------------------------------------------------------
# Test H: hk_check_forbidden_words — silent no-op when words file is absent
# ---------------------------------------------------------------------------

exit_h=0
found_h="$(
  printf 'content with skill mention' \
    | run_lib_fn \
        "CS_BACKUP_ROOT=$TMPDIR_TEST/h/bk" \
        "hk_check_forbidden_words \"$TMPDIR_TEST/nonexistent-words.txt\" -" \
    || exit_h=$?
)"

[[ $exit_h -eq 0 ]] \
  || err "Test H: expected exit 0 when words file absent, got $exit_h"
[[ -z "$found_h" ]] \
  || err "Test H: expected empty output when words file absent, got '$found_h'"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-hooks-lib: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-hooks-lib: all tests pass"
