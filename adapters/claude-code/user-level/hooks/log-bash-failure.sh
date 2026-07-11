#!/usr/bin/env bash
# log-bash-failure.sh — PostToolUseFailure(Bash) — categorize & log failures
# for the self-referential feedback loop. Bound to PostToolUseFailure, not
# PostToolUse: Claude Code does not fire PostToolUse for a failed Bash call
# (verified empirically), so this hook recorded zero entries under the
# previous binding since it was deployed.
#
# Payload shape is parsed defensively — three different shapes have been
# observed/documented across sources, none matching each other exactly:
#   - the public PostToolUseFailure docs describe the result under
#     .tool_output (exit_code/stdout/stderr)
#   - a real PostToolUse (success) payload observed in this repo carries it
#     under .tool_response (stdout/stderr/interrupted/isImage/noOutputExpected,
#     no exit-code key at all)
#   - the REAL PostToolUseFailure(Bash) payload, captured via a nested
#     headless e2e run on v2.1.206, has NEITHER: no .tool_output, .tool_response,
#     nor .tool_result at all. The result is a top-level `.error` string whose
#     first line is "Exit code <N>" followed by stderr content, plus a
#     top-level `.is_interrupt` boolean (not `.interrupted` nested under a
#     result object).
# All three shapes are checked; the two result-object forms (tool_output /
# tool_response / tool_result) are tried first as they carry structured
# stdout/stderr, and the top-level .error/.is_interrupt form is the fallback
# actually exercised in production today.
#
# Migrated from claude-settings/hooks/log-bash-failure.sh
# (absolute path to log-failure.sh replaced with $HOME-relative path via _lib.sh).
#
# Companion: check-failure-patterns.sh (SessionStart) reads the same log.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

event="$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"

# result: docs-described .tool_output, then the empirically observed
# .tool_response, then the legacy .tool_result shape. Empty {} when none of
# the three are present (the real v2.1.206 PostToolUseFailure shape).
result_json="$(printf '%s' "$INPUT" | jq -c '.tool_output // .tool_response // .tool_result // {}' 2>/dev/null || echo '{}')"

payload_error="$(printf '%s' "$INPUT" | jq -r '.error // empty' 2>/dev/null || true)"

# Interrupt gate: checked in both known shapes — .interrupted nested under a
# result object, and the real v2.1.206 top-level .is_interrupt.
interrupted="$(printf '%s' "$result_json" | jq -r '.interrupted // false' 2>/dev/null || echo false)"
is_interrupt="$(printf '%s' "$INPUT" | jq -r '.is_interrupt // false' 2>/dev/null || echo false)"
[[ "$interrupted" == "true" || "$is_interrupt" == "true" ]] && exit 0

exit_code="$(printf '%s' "$result_json" | jq -r '.exit_code // .exitCode // empty' 2>/dev/null || true)"

# Real v2.1.206 fallback: no result object carries an exit code, but the
# top-level .error string's first line is "Exit code <N>".
if [[ -z "$exit_code" || "$exit_code" == "null" ]]; then
  exit_code="$(printf '%s' "$payload_error" | head -1 | /usr/bin/grep -oE '^Exit code [0-9]+' | /usr/bin/grep -oE '[0-9]+$' || true)"
fi

case "$event" in
  PostToolUseFailure)
    : # a failure event by definition — record even without an exit code
    ;;
  PostToolUse)
    # Defensive: only if an environment still binds this hook to PostToolUse
    # AND reports a non-zero exit code (the success-only binding otherwise
    # observed never reaches here with a failure at all).
    if [[ -z "$exit_code" || "$exit_code" == "null" || "$exit_code" == "0" ]]; then
      exit 0
    fi
    ;;
  *)
    exit 0
    ;;
esac

cmd="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
stderr="$(printf '%s' "$result_json" | jq -r '.stderr // empty' 2>/dev/null || true)"
stdout="$(printf '%s' "$result_json" | jq -r '.stdout // empty' 2>/dev/null || true)"

# Fallback chain: stderr (log-failure.sh itself prefers a line matching an
# error keyword; when no line matches — e.g. "bash: cmd: command not found"
# — it falls back to the first line instead) -> stdout (same logic, e.g.
# vitest/jest print failures there) -> payload .error -> a fixed placeholder
# so a record is never empty.
if [[ -n "$stderr" ]]; then
  error_text="$stderr"
elif [[ -n "$stdout" ]]; then
  error_text="$stdout"
elif [[ -n "$payload_error" ]]; then
  error_text="$payload_error"
else
  error_text="(no output)"
fi

# Categorize.
category="unknown"
if printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(test|pytest|vitest|jest)\b'; then
  category="test"
elif printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(tsc|typecheck|type-check|mypy|pyright)\b'; then
  category="check-types"
elif printf '%s' "$cmd" | /usr/bin/grep -qiE '\b(lint|eslint|clippy|ruff|flake8|biome)\b'; then
  category="check"
fi

exit_code_arg="$exit_code"
[[ "$exit_code_arg" == "null" ]] && exit_code_arg=""

# Redact likely secrets from the command line before it hits disk (Bash
# commands routinely carry API keys / tokens / passwords inline, e.g.
# `API_KEY=sk-... some-cli`). Best-effort only — pattern coverage is not
# exhaustive, so this is not a substitute for not putting secrets on the
# command line in the first place. Value-only redaction after a known key
# name, plus a few common bare-token shapes. BSD sed -E (no GNU extensions).
cmd_redacted="$(printf '%s' "$cmd" | /usr/bin/sed -E \
  -e 's/(api[_-]?key|token|password|passwd|secret|bearer|authorization)([=: ]+)[^[:space:]]+/\1\2[REDACTED]/gi' \
  -e 's/sk-[A-Za-z0-9_-]+/[REDACTED]/g' \
  -e 's/ghp_[A-Za-z0-9]+/[REDACTED]/g' \
  -e 's/github_pat_[A-Za-z0-9_]+/[REDACTED]/g')"

cmd_trunc="${cmd_redacted:0:200}"

printf '%s' "$error_text" | "$HOOKS_LIB_DIR/log-failure.sh" "$category" "$exit_code_arg" "$cmd_trunc"
