#!/usr/bin/env bash
# tests/test-loop-report-json.sh — contract test for `tools/loop-report.sh --json`.
#
# Verifies the machine-readable export mode (schema cc-loop-draft/1) that hands
# the merged failure log to the workflow-engine side (ADR 0028):
#   - stdout is exactly one JSON document, first byte '{'
#   - live + archive failure-log merge and --since filtering carry over from
#     the text mode (same merge_failure_log helper)
#   - the project object never leaks a filesystem path, only `name`
#   - $HOME literals are scrubbed from `error`/`cmd` before they leave the host
#   - `error`/`cmd` are truncated, `intent` defaults to "real"
#
# Fixture: synthetic JSONL logs in a mktemp directory. No real logs are used.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

LOOP_REPORT="$CS_ROOT/tools/loop-report.sh"

if [[ ! -x "$LOOP_REPORT" ]]; then
  cs_error "loop-report.sh not found or not executable: $LOOP_REPORT"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Fixture A: live + archive merge, used for (a) (b) (c) (d)
# ---------------------------------------------------------------------------

PROJA="$TMPDIR_TEST/merge-proj"
mkdir -p "$PROJA/.claude/failure-log.archive"

LOGA="$PROJA/.claude/failure-log.jsonl"
{
  printf '{"ts":"2026-07-10T00:00:00Z","category":"test","error":"live e1","exit_code":1,"cmd":"bun test","intent":"real"}\n'
  printf '{"ts":"2026-07-11T00:00:00Z","category":"test","error":"live e2","exit_code":1,"cmd":"bun test","intent":"real"}\n'
} > "$LOGA"

ARCHIVEA="$PROJA/.claude/failure-log.archive/2026-07.jsonl"
{
  printf '{"ts":"2026-07-01T00:00:00Z","category":"check","error":"old e1","exit_code":1,"cmd":"bash -n foo.sh","intent":"real"}\n'
  printf '{"ts":"2026-07-02T00:00:00Z","category":"check","error":"old e2","exit_code":1,"cmd":"bash -n foo.sh","intent":"real"}\n'
} > "$ARCHIVEA"

OUT_A="$(bash "$LOOP_REPORT" --project "$PROJA" --json)"

# (a) stdout parses as a single JSON document with the expected schema
printf '%s' "$OUT_A" | jq -e . >/dev/null \
  || err "Test (a) [valid JSON]: expected --json output to parse as JSON, got: $OUT_A"
[[ "$(printf '%s' "$OUT_A" | jq -r '.schema')" == "cc-loop-draft/1" ]] \
  || err "Test (a) [schema]: expected schema 'cc-loop-draft/1', got: $(printf '%s' "$OUT_A" | jq -r '.schema')"

# (b) live (2) + archive (2) merged = 4 entries
[[ "$(printf '%s' "$OUT_A" | jq -r '.projects[0].entries | length')" == "4" ]] \
  || err "Test (b) [live+archive merge count]: expected 4 entries, got: $(printf '%s' "$OUT_A" | jq -r '.projects[0].entries | length')"

# (d) project object carries only `name` (basename), never a path
[[ "$(printf '%s' "$OUT_A" | jq -r '.projects[0] | has("path")')" == "false" ]] \
  || err "Test (d) [no path]: expected .projects[0] to not have a 'path' key"
[[ "$(printf '%s' "$OUT_A" | jq -r '.projects[0].name')" == "$(basename "$PROJA")" ]] \
  || err "Test (d) [name is basename]: expected name '$(basename "$PROJA")', got: $(printf '%s' "$OUT_A" | jq -r '.projects[0].name')"

# (c) --since between the archive and live timestamps drops the archive half
OUT_A_SINCE="$(bash "$LOOP_REPORT" --project "$PROJA" --json --since 2026-07-05)"
[[ "$(printf '%s' "$OUT_A_SINCE" | jq -r '.projects[0].entries | length')" == "2" ]] \
  || err "Test (c) [--since filters]: expected 2 entries, got: $(printf '%s' "$OUT_A_SINCE" | jq -r '.projects[0].entries | length')"

# (h) --json prints nothing else on stdout: exactly one top-level JSON value,
# first byte '{'
[[ "$(printf '%s' "$OUT_A" | jq -c . | wc -l | tr -d ' ')" == "1" ]] \
  || err "Test (h) [single JSON document]: expected exactly one JSON value on stdout"
[[ "${OUT_A:0:1}" == "{" ]] \
  || err "Test (h) [first byte]: expected stdout to start with '{', got: ${OUT_A:0:1}"

# ---------------------------------------------------------------------------
# Fixture B: $HOME scrubbing, truncation, missing `intent`, used for
# (e) (f) (g) (i)
# ---------------------------------------------------------------------------

PROJB="$TMPDIR_TEST/scrub-proj"
mkdir -p "$PROJB/.claude"

LONG_ERR="$(printf 'x%.0s' $(seq 1 400))"
# A record whose `cmd` is a $HOME prefix cut mid-string, as a hook that
# truncates before this feature runs would leave behind (case i). Built from
# $HOME at runtime, never hard-coded.
HOME_TAIL_FRAGMENT="${HOME:0:10}"
LOGB="$PROJB/.claude/failure-log.jsonl"
{
  printf '{"ts":"2026-01-01T00:00:00Z","category":"test","error":"%s/x","exit_code":1,"cmd":"cat file"}\n' "$HOME"
  printf '{"ts":"2026-01-02T00:00:00Z","category":"test","error":"%s","exit_code":1,"cmd":"echo hi"}\n' "$LONG_ERR"
  printf '{"ts":"2026-01-03T00:00:00Z","category":"test","error":"e3","exit_code":1,"cmd":"%s"}\n' "$HOME_TAIL_FRAGMENT"
} > "$LOGB"

OUT_B="$(bash "$LOOP_REPORT" --project "$PROJB" --json)"

# (e) $HOME is scrubbed from error, replaced with ~
printf '%s' "$OUT_B" | grep -qF "$HOME" \
  && err "Test (e) [no \$HOME literal]: expected no occurrence of \$HOME in output, got: $OUT_B"
# The '~/x' below is a literal search pattern for grep, not a path for the
# shell to expand.
# shellcheck disable=SC2088
printf '%s' "$OUT_B" | grep -qF '~/x' \
  || err "Test (e) [scrubbed to ~]: expected '~/x' in output, got: $OUT_B"

# (f) a 400-char error is truncated to 300 chars
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[1].error | length')" == "300" ]] \
  || err "Test (f) [truncation]: expected error length 300, got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[1].error | length')"

# (g) a record without `intent` defaults to "real"
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[0].intent')" == "real" ]] \
  || err "Test (g) [default intent]: expected 'real', got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[0].intent')"

# (i) a $HOME prefix truncated mid-string (no complete $HOME literal left for
# the exact-match scrub to catch) is still scrubbed via the tail rule
printf '%s' "$OUT_B" | grep -qF '/Users/' \
  && err "Test (i) [no /Users/ substring]: expected no '/Users/' in output, got: $OUT_B"
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[2].cmd | endswith("~")')" == "true" ]] \
  || err "Test (i) [tail scrubbed]: expected cmd to end with '~', got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[2].cmd')"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-loop-report-json: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-loop-report-json: all tests pass"
