#!/usr/bin/env bash
# tests/check-doc-parity.sh — detect documentation that has drifted away from
# the repository it describes.
#
# Why this exists: every drift below was found by hand on 2026-08-09, months
# after it appeared. tests/README.md listed none of the 12 live tests,
# tools/README.md omitted 7 scripts including the pre-push guard, and 17 places
# still described a switchover completed in May. Prose does not fail a build, so
# it rots in silence while every code-level gate stays green.
#
# Scope note: these are cheap textual checks, not comprehension. They catch
# "the file is not mentioned at all" and "this wording expired", which is the
# class of drift actually observed. They cannot tell whether a description is
# accurate, and they are not meant to.
#
# Usage:
#   tests/check-doc-parity.sh [--root <dir>]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_help() {
  cat <<'EOF'
check-doc-parity.sh — fail when docs no longer match the repository.

Usage:
  tests/check-doc-parity.sh              Check this repository
  tests/check-doc-parity.sh --root DIR   Check DIR instead (used by tests)
  tests/check-doc-parity.sh --help

Checks:
  1. every tests/*.sh is named in tests/README.md
  2. every tools/*.sh (including extensionless tools/githooks/*) is named in
     tools/README.md
  3. every user-level hook is named in hooks/_README.md
  4. no expired phase wording outside the historical record
  5. ADR Status values are in the documented vocabulary, point at an ADR that
     exists, and are acknowledged by the ADR that supersedes them
  6. every ADR is listed in meta/decisions/README.md's ADR 一覧 table; an ADR
     numbered 0027+ that names an overturned ADR in its 覆す決定 section is
     acknowledged back in that ADR's index row; every 出典 in the 現行の決定
     tables names a file that exists; ADRs numbered 0027+ stay at or under
     60 lines
  7. each adapter's VERSION pin matches the prose in its README
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    -h|--help) print_help; exit 0 ;;
    *) printf '[ERROR] Unknown arg: %s\n' "$1" >&2; exit 2 ;;
  esac
done

FAILED=0
err() { printf '[ERROR] %s\n' "$*" >&2; FAILED=1; }

# ---------------------------------------------------------------------------
# 1-3. Scripts must be named in the README that indexes them
# ---------------------------------------------------------------------------
# Substring match, not an exact listing format: the three indexes use different
# table shapes, and pinning the format here would make this check a style rule.
# Being mentioned at all is the bar.
check_index_parity() {
  local dir="$1" readme="$2"
  [[ -d "$ROOT/$dir" ]] || return 0
  if [[ ! -f "$ROOT/$readme" ]]; then
    err "index missing: $readme (expected to describe $dir)"
    return 0
  fi
  local f base
  for f in "$ROOT/$dir"/*.sh; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if ! /usr/bin/grep -qF "$base" "$ROOT/$readme"; then
      err "$dir/$base is not mentioned in $readme"
    fi
  done
}

# Versioned git hooks (tools/githooks/*) carry no .sh suffix, so the *.sh glob
# above never reaches them. They need their own sweep of the same directory,
# scoped to a single subdir rather than folded into check_index_parity: that
# function's *.sh glob is reused across tests/tools/hooks and widening it to
# "every file" would also start flagging non-script files those dirs may hold.
check_githooks_parity() {
  local dir="tools/githooks" readme="tools/README.md"
  [[ -d "$ROOT/$dir" ]] || return 0
  if [[ ! -f "$ROOT/$readme" ]]; then
    err "index missing: $readme (expected to describe $dir)"
    return 0
  fi
  local f base
  for f in "$ROOT/$dir"/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    if ! /usr/bin/grep -qF "$base" "$ROOT/$readme"; then
      err "$dir/$base is not mentioned in $readme"
    fi
  done
}

check_index_parity "tests" "tests/README.md"
check_index_parity "tools" "tools/README.md"
check_index_parity "adapters/claude-code/user-level/hooks" \
                   "adapters/claude-code/user-level/hooks/_README.md"
check_githooks_parity

# ---------------------------------------------------------------------------
# 4. Expired phase wording
# ---------------------------------------------------------------------------
# The switchover completed 2026-05-04. Text that still speaks of it in the
# future tense misleads both a human reading the repo and an agent reasoning
# from it — doctor.sh itself had encoded the pre-switch expectation and would
# have called an unprovisioned ~/.claude healthy.
#
# Historical records are exempt by design. CHANGELOG entries, ADR bodies and the
# migration write-ups describe what was true when written; flagging them would
# force rewriting history to get a green check.
STALE_PATTERNS=(
  'Phase 10 で'
  'Phase 0-9'
)
EXEMPT_PATHS=(
  'meta/CHANGELOG.md'
  'meta/decisions/'
  'meta/migration-inventory.md'
  'meta/integration-trace.md'
  'meta/migration-from-claude-settings.md'
  'meta/retrospectives/'
  # This checker and its tests must name the patterns they detect, and the test
  # fixtures must contain them. Same self-reference exemption ADR 0008 needed
  # for the gitleaks identifier rule.
  'tests/check-doc-parity.sh'
  'tests/test-doc-parity.sh'
)

is_exempt() {
  local path="$1" ex
  for ex in "${EXEMPT_PATHS[@]}"; do
    [[ "$path" == *"$ex"* ]] && return 0
  done
  return 1
}

check_stale_wording() {
  local pattern hit path
  for pattern in "${STALE_PATTERNS[@]}"; do
    while IFS= read -r hit; do
      [[ -n "$hit" ]] || continue
      path="${hit%%:*}"
      is_exempt "$path" && continue
      err "expired phase wording in ${hit}"
    done < <(
      /usr/bin/grep -rn --include='*.md' --include='*.sh' --include='*.template' \
        -F "$pattern" "$ROOT" 2>/dev/null \
        | /usr/bin/sed "s|^${ROOT}/||" || true
    )
  done
}

check_stale_wording

# ---------------------------------------------------------------------------
# 5. ADR Status vocabulary and cross-references
# ---------------------------------------------------------------------------
# ADR 0005 reserved 0006 for a switchover record; 0006 went to another topic and
# nothing noticed for three months. A status that names a successor is a claim
# about another file, so it is checkable: the target must exist, and it must
# acknowledge what it replaced.
check_adr_status() {
  local dir="$ROOT/meta/decisions"
  [[ -d "$dir" ]] || return 0
  local f self status num
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    self="$(basename "$f")"
    self="${self%%-*}"
    status="$(/usr/bin/sed -n 's/^- \*\*Status\*\*: *//p' "$f" | head -1)"
    status="${status%"${status##*[![:space:]]}"}"

    if [[ -z "$status" ]]; then
      err "ADR ${self}: no Status line"
      continue
    fi

    case "$status" in
      Proposed|Accepted|Rejected|Withdrawn|Deprecated)
        ;;
      'Superseded by '[0-9][0-9][0-9][0-9] | 'Partially superseded by '[0-9][0-9][0-9][0-9])
        num="${status##* }"
        local -a matches=( "$dir/${num}-"*.md )
        if [[ ! -e "${matches[0]}" ]]; then
          err "ADR ${self}: Status names ADR ${num}, which does not exist"
        elif ! /usr/bin/grep -q "${self}" "${matches[0]}"; then
          err "ADR ${self}: says it is superseded by ${num}, but ${num} never mentions ${self}"
        fi
        ;;
      *)
        err "ADR ${self}: Status outside the documented vocabulary: '${status}'"
        ;;
    esac
  done
}

check_adr_status

# ---------------------------------------------------------------------------
# 5b. New-format ADR (0027+) parity with the decision index
# ---------------------------------------------------------------------------
# ADR 0027 replaced the Status-based Superseded chain with a decision index
# (meta/decisions/README.md) plus an optional per-ADR "## 覆す決定" section.
# A devil's-advocate review of that change noted nothing checks the index and
# the ADRs stay in sync, so a wrong or missing row would go unnoticed the same
# way ADR 0005's reserved-then-reused number did.
ADR_README="$ROOT/meta/decisions/README.md"

# ADR number from a decisions-dir filename, e.g. "0027-foo.md" -> "0027".
adr_num_from_path() {
  local base
  base="$(basename "$1")"
  printf '%s' "${base%%-*}"
}

# Every ADR file must appear in the README's "ADR 一覧" table, or the index
# can silently fall behind the files it claims to catalog.
check_adr_indexed() {
  local dir="$ROOT/meta/decisions"
  [[ -d "$dir" ]] || return 0
  if [[ ! -f "$ADR_README" ]]; then
    err "meta/decisions/README.md is missing"
    return 0
  fi
  local list_section
  list_section="$(/usr/bin/sed -n '/^## ADR 一覧/,$p' "$ADR_README")"
  local f self
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    self="$(adr_num_from_path "$f")"
    if ! printf '%s\n' "$list_section" | /usr/bin/grep -qE "\[${self}\]"; then
      err "ADR ${self}: not listed in the ADR 一覧 table of meta/decisions/README.md"
    fi
  done
}

# ADRs numbered 0027 and later may carry a "## 覆す決定" section naming the
# ADR(s) they overturn. Each named ADR's own row in the index must name the
# overturning ADR back, the same trail the old Status chain enforced.
check_adr_overturns_annotated() {
  local dir="$ROOT/meta/decisions"
  [[ -d "$dir" ]] || return 0
  [[ -f "$ADR_README" ]] || return 0
  local list_section
  list_section="$(/usr/bin/sed -n '/^## ADR 一覧/,$p' "$ADR_README")"
  local f self overturn_section n row
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    self="$(adr_num_from_path "$f")"
    (( 10#$self >= 27 )) || continue
    overturn_section="$(/usr/bin/awk '
      /^## 覆す決定/ { flag = 1; next }
      /^## / { flag = 0 }
      flag { print }
    ' "$f")"
    [[ -n "$overturn_section" ]] || continue
    while IFS= read -r n; do
      [[ -n "$n" ]] || continue
      row="$(printf '%s\n' "$list_section" | /usr/bin/grep -E "^\| \[${n}\]" || true)"
      if [[ -z "$row" ]]; then
        err "ADR ${self}: 覆す決定 names ${n}, which has no row in the ADR 一覧 table"
      elif ! printf '%s' "$row" | /usr/bin/grep -qF "${self}"; then
        err "ADR ${self}: overturns ${n}, but the ADR 一覧 row for ${n} does not name ${self}"
      fi
    done < <(printf '%s' "$overturn_section" | /usr/bin/grep -oE '[0-9]{4}' | sort -u)
  done
}

# Every 出典 (source) named in the README's 現行の決定 tables must resolve to
# an ADR file that exists. Entries with no 4-digit number (a bare 注記 or
# CHANGELOG reference) name no ADR and are not checked.
check_adr_source_columns_exist() {
  local dir="$ROOT/meta/decisions"
  [[ -d "$dir" ]] || return 0
  [[ -f "$ADR_README" ]] || return 0
  local section
  section="$(/usr/bin/sed -n '/^## 現行の決定/,/^## ADR 一覧/p' "$ADR_README")"
  local line last_col n
  while IFS= read -r line; do
    [[ "$line" == '|'*'|'* ]] || continue
    last_col="${line%|}"
    last_col="${last_col##*|}"
    /usr/bin/grep -qE '[0-9]{4}' <<<"$last_col" || continue
    while IFS= read -r n; do
      [[ -n "$n" ]] || continue
      local -a matches=( "$dir/${n}-"*.md )
      if [[ ! -e "${matches[0]}" ]]; then
        err "meta/decisions/README.md 現行の決定表: 出典 ${n} を指す行があるが meta/decisions/${n}-*.md が存在しない"
      fi
    done < <(/usr/bin/grep -oE '[0-9]{4}' <<<"$last_col")
  done <<<"$section"
}

# The short-form cap ADR 0027 introduced: ADRs numbered 0027+ must fit in 60
# lines, or the format that was supposed to stay short quietly grows back.
check_adr_short_form_length() {
  local dir="$ROOT/meta/decisions"
  [[ -d "$dir" ]] || return 0
  local f self lines
  for f in "$dir"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    self="$(adr_num_from_path "$f")"
    (( 10#$self >= 27 )) || continue
    lines="$(/usr/bin/wc -l < "$f" | tr -d '[:space:]')"
    if (( lines > 60 )); then
      err "ADR ${self}: ${lines} lines, over the 60-line cap for ADRs numbered 0027 and later"
    fi
  done
}

check_adr_indexed
check_adr_overturns_annotated
check_adr_source_columns_exist
check_adr_short_form_length

# ---------------------------------------------------------------------------
# 6. Adapter VERSION pin vs the prose that repeats it
# ---------------------------------------------------------------------------
# One fact lives in two places: adapters/<tool>/VERSION and the sentence in the
# same directory's README that names it. They drifted twice — ADR 0022 raised
# the pin and left the prose behind, and ADR 0023 found the README two releases
# stale while fixing something else. Nothing mechanical was watching, so both
# times a human had to notice.
#
# An adapter with no VERSION file is not pinned yet and is skipped. But once a
# pin exists, a README without the sentence fails: deleting the statement must
# not be the cheapest way to a green check.
check_version_parity() {
  local vfile readme pinned stated
  for vfile in "$ROOT"/adapters/*/VERSION; do
    [[ -e "$vfile" ]] || continue
    readme="$(dirname "$vfile")/README.md"
    [[ -f "$readme" ]] || continue

    pinned="$(head -1 "$vfile" | tr -d '[:space:]')"
    [[ -n "$pinned" ]] || continue

    stated="$(/usr/bin/sed -n 's/.*現在: *\([0-9][0-9.]*\).*/\1/p' "$readme" | head -1)"
    if [[ -z "$stated" ]]; then
      err "${readme#"$ROOT"/}: no '現在: <version>' prose to check against ${vfile#"$ROOT"/} (pinned $pinned)"
    elif [[ "$stated" != "$pinned" ]]; then
      err "${vfile#"$ROOT"/} pins $pinned but ${readme#"$ROOT"/} says 現在: $stated"
    fi
  done
}

check_version_parity

if [[ "$FAILED" -eq 0 ]]; then
  echo "check-doc-parity: clean"
fi
exit "$FAILED"
