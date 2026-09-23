#!/usr/bin/env bash
# subagent-stop-audit.sh — SubagentStop — sanitization checks aligned with
# ADR 0001 (anonymity policy) and ADR 0002 (Public/Private boundary), plus
# `tools` overreach detection. Phase 7b decision A3: log-only (no escalation
# yet); Phase 9 retrospective will assess whether escalation is warranted.
#
# Audit signals emitted:
#   - any literal tail-of-name / personal email patterns
#   - Private repo URLs (claude-settings, internal hostnames)
#   - tools used outside the subagent's frontmatter `tools` declaration
# Findings are recorded under hook-logs/subagent-audit.jsonl.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
[[ -z "$INPUT" ]] && exit 0

# Extract fields using the public SubagentStop schema (2.x).
# .subagent.type and .subagent.transcript_path are non-existent keys in the
# official payload; using them caused transcript_path to always be empty,
# which made the early-exit guard below skip the entire audit body.
#
# A second, more subtle mistake was fixed later: the payload's
# .transcript_path points at the MAIN SESSION's JSONL transcript, not at the
# subagent's own transcript. Auditing it directly produced near-total false
# positives, because the main transcript routinely contains instruction-doc
# references (e.g. "claude-settings") and the operator's own email address in
# unrelated turns. The real per-agent transcript is resolved via
# hk_resolve_agent_transcript in _lib.sh (same resolution as
# subagent-stop-record.sh): prefer the official `.agent_transcript_path`
# payload field when present and readable, otherwise fall back to
# `<session_dir>/subagents/agent-<agent_id>.jsonl` derived from the main
# session transcript path. Harness-internal helper agents have neither and
# are skipped (not audited) rather than falling back to the main transcript.
agent_type="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)"
agent_id="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null || true)"
main_transcript_path="$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)"

transcript_path="$(hk_resolve_agent_transcript "$INPUT" "$main_transcript_path" "$agent_id")"

mkdir -p "$HOOK_LOG_DIR"
audit_log="$HOOK_LOG_DIR/subagent-audit.jsonl"

emit_finding() {
  local kind="$1"; local detail="$2"
  printf '{"ts":"%s","agent_type":%s,"kind":"%s","detail":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$(printf '%s' "$agent_type" | jq -Rs .)" \
    "$kind" \
    "$(printf '%s' "$detail" | jq -Rs .)" \
    >> "$audit_log"
}

# Skip if the transcript file is missing or unreadable. Audit is best-effort.
# This is the ordinary path for harness-internal helper agents, which have no
# per-agent transcript on disk at all — most SubagentStop invocations take it
# — so it is not logged: a 2026-09 audit run showed the diagnostic log at
# 100% skip lines (659/659), all this same expected no-op. Only deny / finding
# / actual-error paths are worth a diagnostic entry.
if [[ -z "$transcript_path" || ! -r "$transcript_path" ]]; then
  exit 0
fi

# 1. ADR 0001 / ADR 0006: well-known personal email shape.
# Per ADR 0006 the tree contains no literal user identifiers, so any match
# here is a real leak — no allowlist is needed and the previous
# SUBAGENT_AUDIT_KNOWN_EMAILS env-var has been removed.
if /usr/bin/grep -qE '[A-Za-z0-9._%+-]+@(gmail\.com|icloud\.com|outlook\.com)' "$transcript_path"; then
  emit_finding personal-email-shape "$(basename "$transcript_path")"
fi

# 2. ADR 0002: claude-settings / private-host references.
#
# Two restrictions were added after a 2026-09 audit run produced 74 findings
# that were all the same false positive:
#
# (a) Path-shaped only. A bare "claude-settings" substring also matches every
#     subagent transcript that quotes the user-level CLAUDE.md, which tells
#     every subagent that `~/ws/claude-settings/` is Read-only — prose
#     instruction, not a leaked link. Requiring one of the three concrete
#     path/URL shapes (home-relative, absolute macOS home, or a GitHub blob
#     URL) keeps the check aimed at an actual reference while dropping the
#     instruction-quoting noise.
# (b) Write/Edit tool_input only. Even a path-shaped match is not a leak when
#     it is the assistant *reading about* the path (its own reasoning text,
#     or a Read tool result echoing a file's contents) — ADR 0002 is about
#     what a subagent *writes into a public artifact*, not what it read or
#     said. So only .input.content / .input.new_string / .input.file_path of
#     a Write or Edit tool_use block count.
private_link_pattern='(~/ws/claude-settings|/Users/[^/]+/ws/claude-settings|github\.com/[^/]+/claude-settings)'
write_edit_fields="$(jq -r '
    select(.type == "assistant")
    | .message.content[]?
    | select(.type == "tool_use" and (.name == "Write" or .name == "Edit"))
    | [(.input.content // ""), (.input.new_string // ""), (.input.file_path // "")]
    | join("\n")
  ' "$transcript_path" 2>/dev/null || true)"
if [[ -n "$write_edit_fields" ]] \
   && printf '%s' "$write_edit_fields" | /usr/bin/grep -qE "$private_link_pattern"; then
  emit_finding private-resource-link "$(basename "$transcript_path")"
fi

# 3. tools overreach: cross-check the subagent definition's `tools` frontmatter
# against tool-call markers in the transcript. Heuristic only (transcript
# format may evolve); failures are logged, not blocking.
if [[ -n "$agent_type" ]]; then
  # basename the payload-derived agent_type before path construction so a
  # crafted "../" value cannot traverse out of the subagents directory.
  safe_agent_type="$(basename "$agent_type")"
  agent_def="$CS_ROOT/adapters/claude-code/subagents/${safe_agent_type}.md"
  if [[ -f "$agent_def" ]]; then
    declared_tools="$(awk '/^---$/{c++; next} c==1 && /^tools:/{sub(/^tools:[[:space:]]*/,""); print; exit}' "$agent_def" || true)"
    # Tool names in the transcript appear like "tool: Read" or {"tool":"Bash"}.
    used_tools="$(/usr/bin/grep -oE '"tool"[[:space:]]*:[[:space:]]*"[A-Za-z_]+"' "$transcript_path" 2>/dev/null \
                  | sed -E 's/.*"([A-Za-z_]+)"$/\1/' | sort -u || true)"
    # Normalise declared tools into an array of exact names. Supports either
    # `tools: A, B, C` or `tools: [A, B, C]` frontmatter shapes.
    declared_normalised="${declared_tools#[}"
    declared_normalised="${declared_normalised%]}"
    declared_arr=()
    if [[ -n "$declared_normalised" ]]; then
      IFS=',' read -ra _dt <<<"$declared_normalised"
      for _t in "${_dt[@]}"; do
        # Trim surrounding whitespace and quotes.
        _t="${_t#"${_t%%[![:space:]]*}"}"
        _t="${_t%"${_t##*[![:space:]]}"}"
        _t="${_t#\"}"; _t="${_t%\"}"
        [[ -n "$_t" ]] && declared_arr+=("$_t")
      done
    fi

    while IFS= read -r tool; do
      [[ -z "$tool" ]] && continue
      [[ -z "$declared_tools" ]] && continue
      matched=0
      for d in "${declared_arr[@]}"; do
        if [[ "$d" == "$tool" ]]; then
          matched=1
          break
        fi
      done
      if [[ $matched -eq 0 ]]; then
        emit_finding tool-overreach "${agent_type}: used $tool not declared in $(basename "$agent_def")"
      fi
    done <<<"$used_tools"
  fi
fi

exit 0
