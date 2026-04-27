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

agent_type="$(printf '%s' "$INPUT" | jq -r '.subagent.type // .agent_type // empty' 2>/dev/null || true)"
transcript_path="$(printf '%s' "$INPUT" | jq -r '.subagent.transcript_path // .agent_transcript_path // empty' 2>/dev/null || true)"

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
if [[ -z "$transcript_path" || ! -r "$transcript_path" ]]; then
  exit 0
fi

# 1. ADR 0001: well-known personal email pattern (literal addresses are private,
# so this hook only flags shape — actual literals are not stored anywhere
# except meta/decisions/0001-anonymity-policy.md).
if /usr/bin/grep -qE '[A-Za-z0-9._%+-]+@(gmail\.com|icloud\.com|outlook\.com)' "$transcript_path"; then
  emit_finding personal-email-shape "$transcript_path"
fi

# 2. ADR 0002: claude-settings / private-host references.
if /usr/bin/grep -qE 'claude-settings|github\.com/[^/]+/private|gitlab\.[^/]+/private' "$transcript_path"; then
  emit_finding private-resource-link "$transcript_path"
fi

# 3. tools overreach: cross-check the subagent definition's `tools` frontmatter
# against tool-call markers in the transcript. Heuristic only (transcript
# format may evolve); failures are logged, not blocking.
if [[ -n "$agent_type" ]]; then
  agent_def="$CS_ROOT/adapters/claude-code/subagents/${agent_type}.md"
  if [[ -f "$agent_def" ]]; then
    declared_tools="$(awk '/^---$/{c++; next} c==1 && /^tools:/{sub(/^tools:[[:space:]]*/,""); print; exit}' "$agent_def" || true)"
    # Tool names in the transcript appear like "tool: Read" or {"tool":"Bash"}.
    used_tools="$(/usr/bin/grep -oE '"tool"[[:space:]]*:[[:space:]]*"[A-Za-z_]+"' "$transcript_path" 2>/dev/null \
                  | sed -E 's/.*"([A-Za-z_]+)"$/\1/' | sort -u || true)"
    while IFS= read -r tool; do
      [[ -z "$tool" ]] && continue
      if [[ -n "$declared_tools" ]] && ! echo "$declared_tools" | /usr/bin/grep -q "$tool"; then
        emit_finding tool-overreach "${agent_type}: used $tool not declared in $agent_def"
      fi
    done <<<"$used_tools"
  fi
fi

exit 0
