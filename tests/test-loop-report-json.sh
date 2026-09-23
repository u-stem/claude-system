#!/usr/bin/env bash
# tests/test-loop-report-json.sh — contract test for `tools/loop-report.sh --json`.
#
# Verifies the machine-readable export mode (schema cc-loop-draft/1) that hands
# the merged failure log to the workflow-engine side (ADR 0028):
#   - stdout is exactly one JSON document, first byte '{'
#   - the top-level contract fields scope/since/generated carry the run
#   - live + archive failure-log merge and --since filtering carry over from
#     the text mode (same merge_failure_log helper)
#   - the project object never leaks a filesystem path, only `name`
#   - home paths are scrubbed from `error`/`cmd` before they leave the host:
#     the $HOME literal, its dashed form, a prefix left behind by a truncation
#     (including this mode's own 300/200-char cut), and any other account's
#     macOS home
#   - `error`/`cmd` are truncated, `intent` defaults to "real"
#   - malformed JSONL lines are counted into `dropped_lines`
#   - --all works on an empty and on a multi-project machine
#
# Fixture: synthetic JSONL logs in a mktemp directory. No real logs are used.
# Every home-path fragment is derived from $HOME at runtime, never hard-coded,
# and failure messages never echo a value that would contain one.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir

LOOP_REPORT="$CS_ROOT/tools/loop-report.sh"

# The system bash is 3.2 on macOS, where expanding an empty array under
# `set -u` aborts. The --all cases below run through it on purpose.
SYSTEM_BASH=/bin/bash
[[ -x "$SYSTEM_BASH" ]] || SYSTEM_BASH=bash

if [[ ! -x "$LOOP_REPORT" ]]; then
  cs_error "loop-report.sh not found or not executable: $LOOP_REPORT"
  exit 1
fi

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); cs_error "$*"; }

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# ---------------------------------------------------------------------------
# Fixture A: live + archive merge, used for (a) (b) (c) (d) (h) (r) (s) (t) (u)
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

# (r) `scope` reports which selection produced the document; the consumer
# branches on it, so it is part of the contract
[[ "$(printf '%s' "$OUT_A" | jq -r '.scope')" == "project" ]] \
  || err "Test (r) [scope]: expected 'project' for --project, got: $(printf '%s' "$OUT_A" | jq -r '.scope')"

# (s) `since` is JSON null, not the string "null" or "", when unfiltered
[[ "$(printf '%s' "$OUT_A" | jq -r '.since | type')" == "null" ]] \
  || err "Test (s) [since null]: expected .since to be JSON null without --since, got type: $(printf '%s' "$OUT_A" | jq -r '.since | type')"

# (t) `since` echoes the filter verbatim when one is given
[[ "$(printf '%s' "$OUT_A_SINCE" | jq -r '.since')" == "2026-07-05" ]] \
  || err "Test (t) [since echoed]: expected '2026-07-05', got: $(printf '%s' "$OUT_A_SINCE" | jq -r '.since')"

# (u) `generated` is an ISO 8601 UTC instant with a literal Z
[[ "$(printf '%s' "$OUT_A" | jq -r '.generated | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")')" == "true" ]] \
  || err "Test (u) [generated shape]: expected an ISO 8601 UTC instant, got: $(printf '%s' "$OUT_A" | jq -r '.generated')"

# (v) --project and --all together are rejected before anything is emitted, so
# the "stdout carries one JSON document" promise is never half-kept
set +e
OUT_CONFLICT="$(bash "$LOOP_REPORT" --project "$PROJA" --all --json 2>/dev/null)"
CONFLICT_RC=$?
set -e
[[ "$CONFLICT_RC" == "2" && -z "$OUT_CONFLICT" ]] \
  || err "Test (v) [--project + --all]: expected exit 2 with empty stdout, got exit $CONFLICT_RC with ${#OUT_CONFLICT} byte(s)"

# ---------------------------------------------------------------------------
# Fixture B: home-path scrubbing, truncation, missing `intent`, dropped lines.
# Used for (e) (f) (g) (i) (j) (k) (l) (m) (n) (o) (p) (q)
# ---------------------------------------------------------------------------

PROJB="$TMPDIR_TEST/scrub-proj"
mkdir -p "$PROJB/.claude"

# The tail rule only fires on a *proper* prefix of $HOME that is at least 8
# chars long, so the fragment length is derived rather than fixed: a hard-coded
# 10 would equal the whole $HOME on a short-home host, the exact-literal scrub
# would do the work, and cases (i)/(j)/(o) would pass without ever exercising
# the rule they exist for.
HOME_LEN=${#HOME}
FRAG_LEN=$(( HOME_LEN - 1 < 10 ? HOME_LEN - 1 : 10 ))
SKIP_TAIL_CASES=0
if [[ $FRAG_LEN -lt 8 ]]; then
  SKIP_TAIL_CASES=1
  FRAG_LEN=$HOME_LEN
  echo "SKIP (i)/(j)/(o): \$HOME is $HOME_LEN chars, too short for a proper prefix of 8+"
fi

LONG_ERR="$(printf 'x%.0s' $(seq 1 400))"
# A record whose `cmd` is a $HOME prefix cut mid-string, as a hook that
# truncates before this feature runs would leave behind (case i). Built from
# $HOME at runtime, never hard-coded.
HOME_TAIL_FRAGMENT="${HOME:0:$FRAG_LEN}"
# Same idea for the scratchpad dash form (case j).
HOMEDASH_VAL="${HOME//\//-}"
HOMEDASH_TAIL_FRAGMENT="${HOMEDASH_VAL:0:$FRAG_LEN}"

# Case (m)/(n): the 300-char cut lands inside a home path. Written the way the
# security audit described it: filler, then a whole $HOME, then one more char.
BOUNDARY_ERR="$(printf 'x%.0s' $(seq 1 290))$HOME/x"

# Case (o): the same cut, but the record only ever held a *fragment* of $HOME,
# sitting in the middle. The cut pushes that fragment to the very end, so a
# tail rule applied before the cut (the pre-fix order) can no longer see it.
# The trailing noise character is chosen so the fragment plus noise can never
# spell the whole $HOME, which would hand the work to the exact-literal scrub.
TAIL_NOISE_CHAR='Z'
[[ "${HOME:$FRAG_LEN:1}" == "Z" ]] && TAIL_NOISE_CHAR='Q'
TAIL_NOISE="$(printf 'z%.0s' $(seq 1 30) | tr 'z' "$TAIL_NOISE_CHAR")"
MIDCUT_ERR="$(printf 'x%.0s' $(seq 1 $((300 - FRAG_LEN))))${HOME_TAIL_FRAGMENT}${TAIL_NOISE}"

# Case (p): another account's macOS home. Guarded so it can never contain the
# real $HOME, which would make the exact-literal scrub rather than the generic
# rule do the work and leave the assertion meaningless.
# Assembled from two pieces so the file itself never carries a literal
# /Users/<name>, which is exactly what .gitleaks.toml scans for.
MACOS_HOME_PREFIX="/Users"
OTHER_HOME="$MACOS_HOME_PREFIX/cs-test-otheruser"
SKIP_OTHER_HOME=0
if [[ "$OTHER_HOME" == *"$HOME"* ]]; then
  SKIP_OTHER_HOME=1
  echo "SKIP (p): the synthetic third-party home would contain the real \$HOME"
fi

LOGB="$PROJB/.claude/failure-log.jsonl"
{
  printf '{"ts":"2026-01-01T00:00:00Z","category":"test","error":"%s/x","exit_code":1,"cmd":"cat file"}\n' "$HOME"
  printf '{"ts":"2026-01-02T00:00:00Z","category":"test","error":"%s","exit_code":1,"cmd":"echo hi"}\n' "$LONG_ERR"
  printf '{"ts":"2026-01-03T00:00:00Z","category":"test","error":"e3","exit_code":1,"cmd":"%s"}\n' "$HOME_TAIL_FRAGMENT"
  printf '{"ts":"2026-01-04T00:00:00Z","category":"test","error":"e4","exit_code":1,"cmd":"scratchpad-run-%s"}\n' "$HOMEDASH_TAIL_FRAGMENT"
  printf '{"ts":"2026-01-05T00:00:00Z","category":"test","error":"%s","exit_code":1,"cmd":"echo hi"}\n' "$BOUNDARY_ERR"
  printf '{"ts":"2026-01-06T00:00:00Z","category":"test","error":"%s","exit_code":1,"cmd":"echo hi"}\n' "$MIDCUT_ERR"
  printf '{"ts":"2026-01-07T00:00:00Z","category":"test","error":"%s/x","exit_code":1,"cmd":"echo hi"}\n' "$OTHER_HOME"
  # (q): one line that is not JSON at all. It must not reach `entries`, and it
  # must not vanish without a trace either.
  printf 'this line is not json\n'
} > "$LOGB"

OUT_B="$(bash "$LOOP_REPORT" --project "$PROJB" --json)"

# (e) $HOME is scrubbed from error, replaced with ~
printf '%s' "$OUT_B" | grep -qF "$HOME" \
  && err "Test (e) [no \$HOME literal]: expected no occurrence of \$HOME in output (first 80 bytes: ${OUT_B:0:80})"
# The '~/x' below is a literal search pattern for grep, not a path for the
# shell to expand.
# shellcheck disable=SC2088
printf '%s' "$OUT_B" | grep -qF '~/x' \
  || err "Test (e) [scrubbed to ~]: expected '~/x' in output (first 80 bytes: ${OUT_B:0:80})"

# (f) a 400-char error is truncated to 300 chars
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[1].error | length')" == "300" ]] \
  || err "Test (f) [truncation]: expected error length 300, got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[1].error | length')"

# (g) a record without `intent` defaults to "real"
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[0].intent')" == "real" ]] \
  || err "Test (g) [default intent]: expected 'real', got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[0].intent')"

# (k) no 8-char prefix of $HOME survives anywhere in the document. Derived from
# $HOME rather than matching a literal '/Users/', which is only true on macOS
# and would be a tautology on any other platform.
if [[ $HOME_LEN -ge 8 ]]; then
  printf '%s' "$OUT_B" | grep -qF "${HOME:0:8}" \
    && err "Test (k) [no \$HOME prefix fragment]: expected no 8-char \$HOME prefix anywhere in the output"
fi

# (l) same for the scratchpad dash form
if [[ $HOME_LEN -ge 8 ]]; then
  printf '%s' "$OUT_B" | grep -qF "${HOMEDASH_VAL:0:8}" \
    && err "Test (l) [no dashed \$HOME fragment]: expected no 8-char dashed-\$HOME prefix anywhere in the output"
fi

if [[ $SKIP_TAIL_CASES -eq 0 ]]; then
  # (i) a $HOME prefix truncated mid-string (no complete $HOME literal left for
  # the exact-match scrub to catch) is still scrubbed via the tail rule
  [[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[2].cmd | endswith("~")')" == "true" ]] \
    || err "Test (i) [tail scrubbed]: expected the truncated cmd to end with '~'"

  # (j) same tail rule, dashed form: a cmd ending in a truncated
  # scratchpad-style $HOME fragment is scrubbed too
  [[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[3].cmd | endswith("~")')" == "true" ]] \
    || err "Test (j) [dashed tail scrubbed]: expected the truncated cmd to end with '~'"

  # (o) the 300-char cut moves a mid-string fragment to the end. The tail rule
  # runs after the cut, so the fragment the cut created is still caught.
  [[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[5].error | endswith("~")')" == "true" ]] \
    || err "Test (o) [fragment created by the cut]: expected the truncated error to end with '~'"
fi

# (m) the boundary record still obeys the 300-char cap
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[4].error | length')" -le 300 ]] \
  || err "Test (m) [boundary length]: expected error length <= 300, got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[4].error | length')"

# (n) and it carries no $HOME prefix fragment, because the whole-literal scrub
# runs before the cut rather than after it
if [[ $HOME_LEN -ge 8 ]]; then
  [[ "$(printf '%s' "$OUT_B" | jq -r --arg frag "${HOME:0:8}" '.projects[0].entries[4].error | contains($frag)')" == "false" ]] \
    || err "Test (n) [boundary fragment]: expected no 8-char \$HOME prefix in the boundary error"
fi

# (p) another account's macOS home is replaced too, not just the operator's
if [[ $SKIP_OTHER_HOME -eq 0 ]]; then
  # '~/x' is the expected scrubbed value, not a path for the shell to expand.
  # shellcheck disable=SC2088
  [[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[6].error')" == "~/x" ]] \
    || err "Test (p) [third-party home]: expected '~/x', got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].entries[6].error')"
fi

# (q) the malformed line is skipped but counted, so the consumer can tell a
# clean log from a half-parsed one
[[ "$(printf '%s' "$OUT_B" | jq -r '.projects[0].dropped_lines')" == "1" ]] \
  || err "Test (q) [dropped_lines]: expected 1, got: $(printf '%s' "$OUT_B" | jq -r '.projects[0].dropped_lines')"

# ---------------------------------------------------------------------------
# Fixture C: --all, against a fake $HOME. Used for (w) (x)
# ---------------------------------------------------------------------------

# (w) --all on a machine with no ~/ws/*/.claude still produces the one JSON
# document the contract promises, rather than empty stdout with exit 0
EMPTY_HOME="$TMPDIR_TEST/empty-home"
mkdir -p "$EMPTY_HOME"
set +e
OUT_EMPTY="$(HOME="$EMPTY_HOME" "$SYSTEM_BASH" "$LOOP_REPORT" --all --json 2>/dev/null)"
EMPTY_RC=$?
set -e
[[ "$EMPTY_RC" == "0" && "$(printf '%s' "$OUT_EMPTY" | jq -c '.projects')" == "[]" ]] \
  || err "Test (w) [--all with no projects]: expected exit 0 and .projects == [], got exit $EMPTY_RC with ${#OUT_EMPTY} byte(s)"

# (x) --all rolls up every project under $HOME/ws, one object each
MULTI_HOME="$TMPDIR_TEST/multi-home"
for p in alpha-proj beta-proj; do
  mkdir -p "$MULTI_HOME/ws/$p/.claude"
  printf '{"ts":"2026-07-10T00:00:00Z","category":"test","error":"e","exit_code":1,"cmd":"bun test","intent":"real"}\n' \
    > "$MULTI_HOME/ws/$p/.claude/failure-log.jsonl"
done
OUT_MULTI="$(HOME="$MULTI_HOME" "$SYSTEM_BASH" "$LOOP_REPORT" --all --json 2>/dev/null)"
[[ "$(printf '%s' "$OUT_MULTI" | jq -r '[.projects[].name] | join(",")')" == "alpha-proj,beta-proj" ]] \
  || err "Test (x) [--all rollup]: expected both projects by name, got: $(printf '%s' "$OUT_MULTI" | jq -r '[.projects[].name] | join(",")')"

# ---------------------------------------------------------------------------
# Fixture D: `probe` classification (exit_code == 1 AND the left-most
# pipeline/&&-segment's head token, after stripping a leading env/command
# prefix, is grep/rg/diff/test/[). Used for (y) (z) (z2)
# ---------------------------------------------------------------------------

PROJD="$TMPDIR_TEST/probe-proj"
mkdir -p "$PROJD/.claude"

LOGD="$PROJD/.claude/failure-log.jsonl"
{
  # (y) positive: an exploratory grep that found nothing
  printf '{"ts":"2026-08-01T00:00:00Z","category":"check","error":"e1","exit_code":1,"cmd":"grep -q foo file"}\n'
  # (z) negative: same command shape, but a different exit code — grep failing
  # for a REAL reason (e.g. a bad regex) is exit 2, not "found nothing"
  printf '{"ts":"2026-08-02T00:00:00Z","category":"check","error":"e2","exit_code":2,"cmd":"grep -E ( foo"}\n'
  # (z2) negative: exit 1, but the command head is not in the probe set
  printf '{"ts":"2026-08-03T00:00:00Z","category":"test","error":"e3","exit_code":1,"cmd":"bun test"}\n'
} > "$LOGD"

OUT_D="$(bash "$LOOP_REPORT" --project "$PROJD" --json)"

# (y) positive case is flagged
[[ "$(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[0].probe')" == "true" ]] \
  || err "Test (y) [probe positive]: expected true for 'grep -q foo file' exit 1, got: $(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[0].probe')"

# (z) negative case (wrong exit code) is not flagged
[[ "$(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[1].probe')" == "false" ]] \
  || err "Test (z) [probe negative, exit code]: expected false for grep exit 2, got: $(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[1].probe')"

# (z2) negative case (command not in the probe set) is not flagged, and the
# record is still present (probe classification never drops a record)
[[ "$(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[2].probe')" == "false" ]] \
  || err "Test (z2) [probe negative, command]: expected false for 'bun test' exit 1, got: $(printf '%s' "$OUT_D" | jq -r '.projects[0].entries[2].probe')"
[[ "$(printf '%s' "$OUT_D" | jq -r '.projects[0].entries | length')" == "3" ]] \
  || err "Test (z2) [probe never drops records]: expected 3 entries, got: $(printf '%s' "$OUT_D" | jq -r '.projects[0].entries | length')"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

if [[ $ERRORS -gt 0 ]]; then
  cs_error "test-loop-report-json: $ERRORS failure(s)"
  exit 1
fi
cs_success "test-loop-report-json: all tests pass"
