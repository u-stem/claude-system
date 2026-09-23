#!/usr/bin/env bash
# record-rework-signal.sh — PostToolUse(Edit|Write) — record which file was
# edited, so repeated edits to the same file become countable after the fact.
#
# MEASUREMENT ONLY. This hook blocks nothing, warns about nothing, and judges
# nothing. It appends one line and exits 0 on every path.
#
# Why it exists: the operator's actual complaint about running in auto mode is
# rework — work that gets redone after a premise turns out to be wrong. Whether
# any intervention is worth building, and where it would have to sit, depends on
# how often that happens and under what conditions. None of that is measured
# today. ADR 0019 §5 is explicit that promotion follows measurement, not the
# other way round, so this records and stops.
#
# Both session_id and agent_id/agent_type are captured because it is NOT known
# whether a subagent's PostToolUse payload carries the main session's id. If it
# does not, grouping by session_id alone would split one delegated edit sequence
# into two and undercount rework in exactly the sessions that follow the
# delegation-first rule. Rather than guess, record both and let the data decide
# — the same approach ADR 0024 took when it measured agent_type instead of
# assuming how subagents were distinguishable.
#
# Reading it: tools/loop-report.sh --rework

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

# One jq call for all five fields instead of five, each spawning its own jq
# process — a subagent's edit stream used to fork jq once per field per hook
# invocation for no reason.
#
# Joined with U+001F (ASCII Unit Separator), not @tsv's real tab: `read -r`
# treats a literal tab as "IFS whitespace" (the same class as space/newline)
# REGARDLESS of what IFS is set to, so `IFS=$'\t' read` collapses runs of
# tabs and strips a leading one — verified empirically, e.g. field_path
# empty + 4 more empty fields (a legitimate, common shape for this payload)
# comes back as "\t\t\t\t", whose leading run of 4 delimiters gets eaten,
# silently shifting every field left by one. U+001F is not in that
# whitespace class, so each occurrence delimits exactly one field, empty
# fields included. The only field where a control character is a realistic
# input is file_path, and U+001F does not appear in real paths.
fields="$(printf '%s' "$INPUT" | jq -r \
  '[.tool_input.file_path // .tool_input.path // "", .session_id // "", .agent_type // "", .agent_id // "", .tool_name // ""] | join("\u001f")' \
  2>/dev/null || true)"
IFS=$'\x1f' read -r file_path session_id agent_type agent_id tool_name <<< "$fields"
[[ -z "${file_path:-}" ]] && exit 0

# Store the path relative to the project. An absolute path embeds /Users/<name>,
# which ADR 0008 forbids in tree artifacts and .gitleaks.toml blocks at commit
# time — and this log lives under the project's .claude/. Anything outside the
# project is reduced to a marker rather than recorded verbatim, since its
# absolute form is exactly the shape that leaks.
case "$file_path" in
  "$PROJECT_ROOT"/*) rel_path="${file_path#"$PROJECT_ROOT"/}" ;;
  *)                 rel_path="(outside project)" ;;
esac

log_file="${PROJECT_ROOT}/.claude/rework-log.jsonl"
mkdir -p "$(dirname "$log_file")" 2>/dev/null || exit 0

# jq builds the record so that any character in a path or agent name is encoded
# correctly. If jq is missing or the write fails, drop the sample rather than
# disturb the tool call: an incomplete measurement is acceptable, a hook that
# interferes with editing is not.
record="$(jq -nc \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg file "$rel_path" \
  --arg tool "$tool_name" \
  --arg session_id "$session_id" \
  --arg agent_type "$agent_type" \
  --arg agent_id "$agent_id" \
  '{ts:$ts,file:$file,tool:$tool,session_id:$session_id,agent_type:$agent_type,agent_id:$agent_id}' \
  2>/dev/null || true)"
[[ -n "$record" ]] || exit 0

printf '%s\n' "$record" >> "$log_file" 2>/dev/null || true
exit 0
