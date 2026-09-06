#!/usr/bin/env bash
# tools/loop-report.sh — manual aggregation of observation logs
# (failure-log.jsonl + subagent-log.jsonl). Minimal implementation of the
# "aggregation starting point" from ADR 0012. Read-only, idempotent.
#
# Reads the canonical per-project paths:
#   <project>/.claude/failure-log.jsonl (live)
#   <project>/.claude/failure-log.archive/*.jsonl (archived)
#   <project>/.claude/subagent-log.jsonl
#
# The failure log is merged live+archive and sorted chronologically by `ts`
# so that archiving (see check-failure-patterns.sh) does not break trend
# analysis across the archive boundary.
#
# subagent-audit.jsonl (recorded by subagent-stop-audit.sh) is NOT scoped
# per project: it lives under $CS_BACKUP_ROOT/hook-logs (machine-wide,
# default ~/.claude-system-backups/hook-logs), the same directory the hooks'
# own HOOK_LOG_DIR resolves to. It is reported once, globally, regardless of
# --project/--all (there is exactly one such log on the machine).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
loop-report.sh — aggregate failure-log.jsonl and subagent-log.jsonl.

Usage:
  tools/loop-report.sh                        Report for $PWD
  tools/loop-report.sh --project <dir>        Report for a specific project root
  tools/loop-report.sh --all                  Roll up every ~/ws/*/.claude project
  tools/loop-report.sh --since YYYY-MM-DD     Only include records at/after this date
  tools/loop-report.sh --json                 Emit the merged failure log as one JSON document (for the workflow-engine side, ADR 0028)
  tools/loop-report.sh --help

Notes:
  - Read-only. Never modifies or deletes log files.
  - Missing log files are reported as "no data", not an error (exit 0).
  - --project and --all are mutually exclusive.
  - The subagent-audit section is machine-wide (not per project) and is
    always printed once, filtered by --since like the other sections.
  - --json is combinable with --project/--all/--since. In that mode stdout
    carries exactly one JSON document (schema cc-loop-draft/1) and nothing
    else: no banners, no subagent/rework/audit sections. Warnings may still
    go to stderr.
EOF
}

cs_show_help_if_requested "${1:-}"
cs_require_cmd jq

PROJECT_ARG=""
ALL=0
SINCE=""
JSON_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ARG="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    --since) SINCE="$2"; shift 2 ;;
    --json) JSON_MODE=1; shift ;;
    -h|--help) cs_print_help; exit 0 ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -n "$PROJECT_ARG" && "$ALL" == "1" ]]; then
  cs_error "--project and --all are mutually exclusive"
  exit 2
fi

if [[ -n "$SINCE" ]]; then
  # Validate format only; comparisons below use lexical string compare
  # against ISO 8601 `ts` values, which sorts correctly for date prefixes.
  # BSD `date -jf` first, GNU `date -d` fallback (see check-package-age.sh).
  if ! date -jf "%Y-%m-%d" "$SINCE" +%s >/dev/null 2>&1 \
    && ! date -d "$SINCE" +%s >/dev/null 2>&1; then
    cs_error "--since must be YYYY-MM-DD: $SINCE"
    exit 2
  fi
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# Malformed JSONL lines discarded by jsonl_sanitize since the last reset.
# emit_json_report zeroes it per project and reports it as dropped_lines;
# the text mode never reads it.
JSONL_DROPPED=0

PROJECTS=()
if [[ "$ALL" == "1" ]]; then
  shopt -s nullglob
  for dir in "$HOME"/ws/*/.claude; do
    PROJECTS+=("$(dirname "$dir")")
  done
  shopt -u nullglob
  if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    cs_warn "no ~/ws/*/.claude directories found"
  fi
else
  PROJECTS+=("${PROJECT_ARG:-$PWD}")
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Filter a JSONL file down to only its syntactically valid lines, writing the
# result to $2. Under `set -e`, feeding a file with a malformed line straight
# into `jq -s`/`jq -c` aborts the whole report (jq exits non-zero on a parse
# error); reading it one raw line at a time via `-R` and parsing each line
# individually with `fromjson? // empty` drops bad lines silently instead of
# failing the pipeline. Every prep_*/merge_* function below sanitizes its
# input(s) through this before handing them to jq's structured filters.
#
# Dropping silently is right for the text mode (a human reads the totals), but
# a --json consumer cannot tell a clean log from a half-parsed one, so the
# discarded count accumulates in JSONL_DROPPED. awk counts a last line that has
# no trailing newline, which `wc -l` would miss on exactly the half-written
# record this filter exists to survive.
jsonl_sanitize() {
  local src="$1" out="$2"
  jq -R -c 'fromjson? // empty' "$src" > "$out" 2>/dev/null || : > "$out"
  local raw kept
  raw="$(awk 'END{print NR}' "$src" 2>/dev/null || echo 0)"
  kept="$(awk 'END{print NR}' "$out" 2>/dev/null || echo 0)"
  if [[ "$raw" -gt "$kept" ]]; then
    JSONL_DROPPED=$((JSONL_DROPPED + raw - kept))
  fi
}

# Merge live + archived failure-log JSONL for one project, chronologically
# sorted, optionally filtered by --since. Writes to $2 (may end up empty).
merge_failure_log() {
  local claude_dir="$1" out="$2"
  local files=()
  [[ -f "$claude_dir/failure-log.jsonl" ]] && files+=("$claude_dir/failure-log.jsonl")
  if [[ -d "$claude_dir/failure-log.archive" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$claude_dir/failure-log.archive" -name '*.jsonl' -print0 2>/dev/null)
  fi
  if [[ ${#files[@]} -eq 0 ]]; then
    : > "$out"
    return
  fi
  local sanitized=() f s
  for f in "${files[@]}"; do
    s="$(mktemp "$WORKDIR/sanitize-XXXXXX")"
    jsonl_sanitize "$f" "$s"
    sanitized+=("$s")
  done
  if [[ -n "$SINCE" ]]; then
    jq -sc --arg since "$SINCE" \
      '[.[] | select((.ts // "") >= $since)] | sort_by(.ts) | .[]' \
      "${sanitized[@]}" > "$out"
  else
    jq -sc 'sort_by(.ts) | .[]' "${sanitized[@]}" > "$out"
  fi
}

# Build one entry object per the cc-loop-draft/1 schema (ADR 0028), scrubbing
# any $HOME literal (both the plain form and the scratchpad dash form used
# under $TMPDIR) so a host path never leaves the machine. Home paths are all
# this removes: secrets, third-party identifiers and project names stay.
json_failure_entries() {
  local file="$1"
  jq -c --arg home "$HOME" --arg homedash "${HOME//\//-}" '
    # A field that other hooks already truncated (e.g. log-bash-failure.sh
    # cuts `cmd` to 200 chars before this feature existed), or one the 300/200
    # cut below shortens, can end mid-way through $HOME, so the exact-literal
    # scrub has nothing complete left to match. This catches that: if the
    # string ends with a *proper*
    # prefix of $needle at least 8 chars long (longer than "/Users/", which
    # would otherwise false-positive on unrelated text), replace that tail
    # with "~". Tried longest prefix first, at most one replacement — a
    # shorter accidental match should not pre-empt a longer real one.
    # $HOME shorter than 8 chars skips the rule entirely (range() below then
    # generates no candidates, so this is inert, not a separate branch).
    def scrub_tail($needle):
      ($needle | length) as $nlen
      | . as $s
      | ($s | length) as $slen
      | if $nlen < 8 then $s
        else
          (reduce range($nlen - 1; 7; -1) as $n (
             {done: false, out: $s};
             if .done then .
             else
               ($needle[0:$n]) as $prefix
               | if ($s | endswith($prefix)) then
                   {done: true, out: ($s[0:($slen - $n)] + "~")}
                 else .
                 end
             end
           )).out
        end;
    # Whole-literal replacement. Runs before the length cut, on the full
    # string, so an occurrence that the cut would have sliced in half is
    # already gone by then.
    def scrub_literal:
      (if ($home | length) > 0 then split($home) | join("~") else . end)
      | (if ($homedash | length) > 0 then split($homedash) | join("~") else . end);
    # Runs after the length cut: the cut is itself a truncation, so it can
    # leave a fresh $HOME prefix sitting at the new end of the string, and a
    # rule applied before it would already be done. The closing gsub covers
    # the macOS home directory of any other account, which the $HOME rules
    # cannot see; it is after the cut for the same reason.
    def scrub_tails:
      scrub_tail($home)
      | scrub_tail($homedash)
      | gsub("/Users/[A-Za-z0-9._-]+"; "~");
    {
      ts: (.ts // null),
      # tostring keeps a non-string category (a future hook could write one)
      # from silently changing the schema the consumer parses.
      category: ((.category // "unknown") | tostring),
      error: ((.error // "") | tostring | scrub_literal | .[0:300] | scrub_tails),
      exit_code: (.exit_code | if type == "number" then . else null end),
      cmd: ((.cmd // "") | tostring | scrub_literal | .[0:200] | scrub_tails),
      intent: (.intent // "real")
    }
  ' "$file"
}

# Emit the merged failure log (live + archive, --since filtered, ts sorted) as
# one JSON document on stdout for the workflow-engine side (ADR 0028). Prints
# nothing else: no cs_step banners, no "Generated:" line, no text sections.
# Each project object also carries dropped_lines, the number of malformed
# JSONL lines skipped for it, so a consumer can tell a clean log from a
# half-parsed one.
emit_json_report() {
  local generated since_json scope
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -n "$SINCE" ]]; then
    since_json="$(jq -nc --arg s "$SINCE" '$s')"
  else
    since_json="null"
  fi
  if [[ "$ALL" == "1" ]]; then
    scope="all"
  else
    scope="project"
  fi

  local projects_file
  projects_file="$WORKDIR/json-projects.jsonl"
  : > "$projects_file"

  # ${PROJECTS[@]+...} rather than a plain "${PROJECTS[@]}": expanding an
  # empty array under `set -u` aborts on bash 3.2 (the system bash on macOS),
  # which would break the "stdout always carries one JSON document" contract
  # for --all on a machine with no matching projects.
  local idx=0 proj claude_dir name fl_out
  for proj in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
    idx=$((idx + 1))
    claude_dir="$proj/.claude"
    name="$(basename "$proj")"

    fl_out="$WORKDIR/json-fl-$idx.jsonl"
    JSONL_DROPPED=0
    merge_failure_log "$claude_dir" "$fl_out"

    # Streamed into jq instead of passed as --argjson: one project-year of
    # entries can exceed ARG_MAX and take the whole report down with
    # "Argument list too long". `jq -s` on empty input still yields [], so
    # the shape for a project with no records is unchanged.
    json_failure_entries "$fl_out" \
      | jq -sc --arg name "$name" --argjson dropped "$JSONL_DROPPED" \
        '{name: $name, dropped_lines: $dropped, entries: .}' >> "$projects_file"
  done

  jq -s --arg generated "$generated" --argjson since "$since_json" --arg scope "$scope" \
    '{schema: "cc-loop-draft/1", generated: $generated, since: $since, scope: $scope, projects: .}' \
    "$projects_file"
}

if [[ "$JSON_MODE" == "1" ]]; then
  emit_json_report
  exit 0
fi

# Copy subagent-log.jsonl for one project, optionally filtered by --since.
prep_subagent_log() {
  local claude_dir="$1" out="$2"
  local src="$claude_dir/subagent-log.jsonl"
  if [[ ! -f "$src" ]]; then
    : > "$out"
    return
  fi
  local sanitized
  sanitized="$(mktemp "$WORKDIR/sanitize-XXXXXX")"
  jsonl_sanitize "$src" "$sanitized"
  if [[ -n "$SINCE" ]]; then
    jq -c --arg since "$SINCE" 'select((.ts // "") >= $since)' "$sanitized" > "$out"
  else
    cp "$sanitized" "$out"
  fi
}

emit_failure_report() {
  local file="$1"
  local total
  total="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$total" -eq 0 ]]; then
    echo "  no data"
    return
  fi
  echo "  total: $total"
  # Deliberate failures are counted separately, not dropped. A rising count of
  # expected failures is a fine thing (more negative tests); mixing it into the
  # recurrence numbers is what misleads. Records predating the field are "real".
  local real_n expected_n
  real_n="$(jq -rs 'map(select((.intent // "real") == "real")) | length' "$file")"
  expected_n="$(jq -rs 'map(select(.intent == "expected")) | length' "$file")"
  echo "  by intent: real: $real_n  deliberate (negative tests): $expected_n"
  echo "  by category (desc, real only):"
  jq -r 'select((.intent // "real") == "real") | .category // "unknown"' "$file" | sort | uniq -c | sort -rn | \
    while read -r count cat; do
      printf '    %-15s %s\n' "$cat" "$count"
    done
  echo "  recent errors per category (up to 3, most recent last):"
  local cats
  cats="$(jq -r '.category // "unknown"' "$file" | sort -u)"
  while IFS= read -r cat; do
    [[ -z "$cat" ]] && continue
    echo "    [$cat]"
    jq -c --arg c "$cat" 'select((.category // "unknown") == $c)' "$file" | tail -3 | \
      jq -r '.error // empty' | sed 's/^/      - /'
  done <<< "$cats"
  echo "  monthly counts (YYYY-MM):"
  jq -r '(.ts // null)[0:7] // "unknown"' "$file" | sort | uniq -c | sort -k2 | \
    while read -r count month; do
      printf '    %-10s %s\n' "$month" "$count"
    done
}

# Rework: how often the same file was edited repeatedly inside one session.
# This is a proxy, not a verdict — a long file legitimately takes several edits.
# What makes it worth watching is the shape over time, and whether the sessions
# with the most rework are the ones that skipped the planning or refutation
# stage. That correlation is the input to the Step 4 decision; until there is
# enough data the honest answer is that we do not know.
emit_rework_report() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    echo "  no data (hook records on every Edit/Write; expect data after normal use)"
    return
  fi
  local total sessions
  total="$(wc -l < "$file" | tr -d ' ')"
  sessions="$(jq -rs '[.[].session_id] | unique | length' "$file" 2>/dev/null || echo "?")"
  echo "  edits recorded: $total across $sessions session(s)"

  # Threshold of 3 mirrors the recurrence threshold used by the failure loop.
  echo "  files edited 3+ times in one session (rework candidates):"
  local found
  found="$(jq -rs '
    group_by(.session_id + "\u0000" + .file)
    | map(select(length >= 3))
    | sort_by(-length)
    | .[:10][]
    | "    \(.[0].file)  \(length)x  session=\(.[0].session_id[0:8])"
  ' "$file" 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
  else
    echo "    (none)"
  fi

  # Whether a subagent's payload carries the main session id is unverified, so
  # this split is the evidence for deciding how to group. If delegated edits
  # land under session ids that never appear for the main session, counting by
  # session alone undercounts exactly the delegation-first sessions.
  echo "  by agent_type:"
  jq -r '.agent_type // "" | if . == "" then "(main session)" else . end' "$file" \
    | sort | uniq -c | sort -rn | while read -r count kind; do
      printf '    %-20s %s\n' "$kind" "$count"
    done
}

emit_subagent_report() {
  local file="$1"
  local total
  total="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$total" -eq 0 ]]; then
    echo "  no data"
    return
  fi
  echo "  total: $total"

  # Split delegated agents from harness-internal ones before doing any rates.
  # `(internal)` is the harness's own machinery (summarization, compaction,
  # titles); it is logged with an empty model on purpose, because its transcript
  # is the main session's and attributing that model would be a lie. Measured
  # 2026-08-09: 230 of 313 records were (internal) or legacy-empty, so mixing
  # them in made every rate describe harness noise rather than the delegation
  # loop this report exists to observe (ADR 0013 reads these numbers).
  local delegated_file internal_count legacy_count delegated_total
  # Under $WORKDIR so the existing EXIT trap removes it; explicit rm calls
  # would leak the file on any early exit added later.
  delegated_file="$(mktemp "$WORKDIR/delegated-XXXXXX")"
  jq -c 'select(((.agent_type // "") != "") and (.agent_type != "(internal)"))' \
    "$file" > "$delegated_file" 2>/dev/null || true
  delegated_total="$(wc -l < "$delegated_file" | tr -d ' ')"
  internal_count="$(jq -r 'select(.agent_type == "(internal)")' "$file" | jq -s length 2>/dev/null || echo 0)"
  legacy_count="$(jq -r 'select((.agent_type // "") == "")' "$file" | jq -s length 2>/dev/null || echo 0)"
  printf '  delegated: %s   harness-internal: %s   legacy-empty: %s\n' \
    "$delegated_total" "${internal_count:-0}" "${legacy_count:-0}"

  if [[ "${delegated_total:-0}" -eq 0 ]]; then
    echo "  (no delegated-agent records; the sections below would be empty)"
    return
  fi

  echo "  by agent_type (delegated only):"
  jq -r '.agent_type' "$delegated_file" | \
    sort | uniq -c | sort -rn | while read -r count v; do
      printf '    %-20s %s\n' "$v" "$count"
    done
  echo "  by model (delegated only):"
  jq -r 'if (.model // "") == "" then "(empty)" else .model end' "$delegated_file" | \
    sort | uniq -c | sort -rn | while read -r count v; do
      printf '    %-20s %s\n' "$v" "$count"
    done
  echo "  by effort (delegated only):"
  jq -r 'if (.effort // "") == "" then "(empty)" else .effort end' "$delegated_file" | \
    sort | uniq -c | sort -rn | while read -r count v; do
      printf '    %-20s %s\n' "$v" "$count"
    done
  local nonzero
  nonzero="$(jq -r '.exit_code // 0' "$file" | grep -vc '^0$' || true)"
  echo "  exit_code != 0: ${nonzero:-0}"
  local empty_model
  empty_model="$(jq -r '.model // ""' "$delegated_file" | grep -c '^$' || true)"
  empty_model="${empty_model:-0}"
  printf '  empty model rate (delegated): %s/%s (%s%%)\n' "$empty_model" "$delegated_total" \
    "$(awk -v a="$empty_model" -v t="$delegated_total" 'BEGIN{printf "%.1f", (t>0)?(a/t*100):0}')"
  # Field validity windows — these fields were added over time, so a rate taken
  # across all history understates coverage. Verified 2026-08-09.
  echo "  field validity: model from 2026-06, spawn_depth from 2026-07-25 (ADR 0022),"
  echo "                  agent_type complete from 2026-08; parent_agent_id is empty"
  echo "                  by design while delegation stays single-layer (ADR 0015)"
  # Nested-delegation visibility (ADR 0022): spawn_depth is backfilled from
  # the per-agent transcript's sidecar meta.json and is absent/0 on records
  # predating that field, so this section is additive and safe on old logs.
  local nested_count
  nested_count="$(jq -r '.spawn_depth // 0' "$file" | awk '$1 >= 2' | wc -l | tr -d ' ')"
  if [[ "${nested_count:-0}" -eq 0 ]]; then
    echo "  nested delegations (spawn_depth >= 2): no nested delegations"
  else
    echo "  nested delegations (spawn_depth >= 2): $nested_count"
    echo "  nested delegations by agent_type:"
    jq -rc 'select((.spawn_depth // 0) >= 2)' "$file" | \
      jq -r 'if (.agent_type // "") == "" then "(empty)" else .agent_type end' | \
      sort | uniq -c | sort -rn | while read -r count v; do
        printf '    %-20s %s\n' "$v" "$count"
      done
  fi
}

# Copy the machine-wide subagent-audit.jsonl, optionally filtered by --since.
# Unlike failure-log/subagent-log this file is not per-project: it is always
# read from $CS_BACKUP_ROOT/hook-logs (see _lib.sh sourced above).
prep_audit_log() {
  local out="$1"
  local src="$CS_BACKUP_ROOT/hook-logs/subagent-audit.jsonl"
  if [[ ! -f "$src" ]]; then
    : > "$out"
    return
  fi
  local sanitized
  sanitized="$(mktemp "$WORKDIR/sanitize-XXXXXX")"
  jsonl_sanitize "$src" "$sanitized"
  if [[ -n "$SINCE" ]]; then
    jq -c --arg since "$SINCE" 'select((.ts // "") >= $since)' "$sanitized" > "$out"
  else
    cp "$sanitized" "$out"
  fi
}

emit_audit_report() {
  local file="$1"
  local total
  total="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$total" -eq 0 ]]; then
    echo "  no data"
    return
  fi
  echo "  total: $total"
  echo "  by kind (desc):"
  jq -r '.kind // "unknown"' "$file" | sort | uniq -c | sort -rn | \
    while read -r count kind; do
      printf '    %-20s %s\n' "$kind" "$count"
    done
  echo "  recent findings (up to 5, most recent last):"
  tail -5 "$file" | jq -r '"    [\(.kind // "unknown")] \(.ts // "?") \(.detail // "")"'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

cs_step "loop-report.sh"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Since filter: ${SINCE:-(none)}"

ALL_FL="$WORKDIR/all-failure.jsonl"
ALL_SL="$WORKDIR/all-subagent.jsonl"
: > "$ALL_FL"
: > "$ALL_SL"

idx=0
# See the note in emit_json_report: an empty array is not expandable under
# `set -u` on bash 3.2.
for proj in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
  idx=$((idx + 1))
  claude_dir="$proj/.claude"

  cs_step "Project: $proj"

  if [[ ! -d "$claude_dir" ]]; then
    echo "  no .claude directory found (no data)"
    continue
  fi

  fl_out="$WORKDIR/fl-$idx.jsonl"
  sl_out="$WORKDIR/sl-$idx.jsonl"
  merge_failure_log "$claude_dir" "$fl_out"
  prep_subagent_log "$claude_dir" "$sl_out"

  echo " -- failure-log --"
  emit_failure_report "$fl_out"
  echo " -- subagent-log --"
  emit_subagent_report "$sl_out"
  echo " -- rework --"
  emit_rework_report "$claude_dir/rework-log.jsonl"

  cat "$fl_out" >> "$ALL_FL"
  cat "$sl_out" >> "$ALL_SL"
done

if [[ "$ALL" == "1" && ${#PROJECTS[@]} -gt 1 ]]; then
  cs_step "Total (all projects)"
  # Re-sort the merged failure log chronologically for the rollup's
  # "recent errors" and "monthly counts" sections.
  ALL_FL_SORTED="$WORKDIR/all-failure-sorted.jsonl"
  if [[ -s "$ALL_FL" ]]; then
    jq -sc 'sort_by(.ts) | .[]' "$ALL_FL" > "$ALL_FL_SORTED"
  else
    : > "$ALL_FL_SORTED"
  fi
  echo " -- failure-log --"
  emit_failure_report "$ALL_FL_SORTED"
  echo " -- subagent-log --"
  emit_subagent_report "$ALL_SL"
fi

# subagent-audit.jsonl is machine-wide, not per-project, so it is reported
# once here rather than inside the per-project loop above.
cs_step "Subagent audit (machine-wide, $CS_BACKUP_ROOT/hook-logs)"
AUDIT_OUT="$WORKDIR/audit.jsonl"
prep_audit_log "$AUDIT_OUT"
echo " -- subagent-audit --"
emit_audit_report "$AUDIT_OUT"
