#!/usr/bin/env bash
# tools/archive-failure-log.sh — human-triggered helper to archive a
# project's failure-log.jsonl, replacing the manual `mkdir -p ... && mv`
# advice previously given by check-failure-patterns.sh.
#
# Per ADR 0019 decision 4 ("hooks notify only, humans execute"), this script
# is never invoked automatically by a hook; the operator runs it by hand
# after addressing recurring failures.
#
# Moves <project>/.claude/failure-log.jsonl to
# <project>/.claude/failure-log.archive/YYYY-MM.jsonl. If an archive file for
# that month already exists, the live log is appended to it (never
# clobbered) so measurement continuity (loop-report.sh trend analysis) is
# preserved across repeated archiving in the same month.
#
# The append path narrows the interruption window: the live log is first
# `mv`'d to a pending file inside failure-log.archive/ (atomic within the
# same filesystem, so a crash before/after the mv never loses or duplicates
# data), then appended to the archive and removed. If the process is
# interrupted after the mv, re-running this script recovers the leftover
# pending file (append it, then remove it) before touching anything new, so
# the entire live-log content is never re-appended on retry -- unlike the
# previous single `cat live >> archive; rm live` step, where any
# interruption before the `rm` caused the *whole* live log to be
# double-appended on the next run. The one residual gap (a crash strictly
# between the pending file's append and its removal) is a single-syscall
# window with no realistic exposure for a human-triggered command.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
archive-failure-log.sh — archive failure-log.jsonl to failure-log.archive/.

Usage:
  tools/archive-failure-log.sh                       Archive $PWD's log for the current month
  tools/archive-failure-log.sh --project <dir>       Archive a specific project's log
  tools/archive-failure-log.sh --all                 Archive every ~/ws/*/.claude project's log
  tools/archive-failure-log.sh --month YYYY-MM        Archive under a specific month (default: current)
  tools/archive-failure-log.sh --dry-run              Print what would happen, change nothing
  tools/archive-failure-log.sh --help

Behavior:
  - <project>/.claude/failure-log.jsonl is moved to
    <project>/.claude/failure-log.archive/<month>.jsonl.
  - If that month's archive file already exists, the live log is appended
    to it (never overwritten) via a crash-safe move-then-append; a leftover
    *.jsonl.tmp file in failure-log.archive/ from an interrupted run is
    recovered automatically on the next invocation.
  - If there is no live log, nothing happens (exit 0).
  - --project and --all are mutually exclusive.
  - Not invoked by any hook; this is a human-run maintenance step (ADR 0019).
EOF
}

cs_show_help_if_requested "${1:-}"

PROJECT_ARG=""
ALL=0
DRY_RUN=0
MONTH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_ARG="$2"; shift 2 ;;
    --all) ALL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --month) MONTH="$2"; shift 2 ;;
    -h|--help) cs_print_help; exit 0 ;;
    *) cs_error "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -n "$PROJECT_ARG" && "$ALL" == "1" ]]; then
  cs_error "--project and --all are mutually exclusive"
  exit 2
fi

if [[ -z "$MONTH" ]]; then
  MONTH="$(date +%Y-%m)"
fi

# Validate YYYY-MM shape (BSD `date -jf` first, GNU `date -d` fallback, same
# pattern as loop-report.sh's --since validation).
if ! date -jf "%Y-%m" "$MONTH" +%s >/dev/null 2>&1 \
  && ! date -d "${MONTH}-01" +%s >/dev/null 2>&1; then
  cs_error "--month must be YYYY-MM: $MONTH"
  exit 2
fi

PROJECTS=()
if [[ "$ALL" == "1" ]]; then
  shopt -s nullglob
  for dir in "$HOME"/ws/*/.claude; do
    # Skip symlinked .claude entries: --all should only ever touch real
    # project directories, not a path an operator (or something else) has
    # pointed elsewhere. Reported in both --dry-run and real runs, since
    # discovery happens before either branch.
    if [[ -L "$dir" ]]; then
      cs_warn "skipping symlinked .claude entry (not a real directory): $dir"
      continue
    fi
    PROJECTS+=("$(dirname "$dir")")
  done
  shopt -u nullglob
  if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    cs_warn "no ~/ws/*/.claude directories found"
  fi
else
  PROJECTS+=("${PROJECT_ARG:-$PWD}")
fi

archive_one() {
  local proj="$1"
  local claude_dir="$proj/.claude"
  local live="$claude_dir/failure-log.jsonl"
  local archive_dir="$claude_dir/failure-log.archive"
  local archive_file="$archive_dir/${MONTH}.jsonl"
  local pending="$archive_dir/${MONTH}.jsonl.tmp"

  cs_step "Project: $proj"

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ -f "$pending" ]]; then
      cs_info "found leftover $pending from an interrupted run; would append it to $archive_file and remove it"
    fi
    if [[ ! -f "$live" ]]; then
      cs_info "no live failure-log.jsonl (nothing to archive)"
      return 0
    fi
    if [[ -f "$archive_file" || -f "$pending" ]]; then
      cs_info "would move: $live -> $pending (atomic), then append $pending -> $archive_file, then remove $pending"
    else
      cs_info "would move: $live -> $archive_file"
    fi
    return 0
  fi

  if [[ -f "$pending" || -f "$live" ]]; then
    mkdir -p "$archive_dir"
  fi

  # Recover a pending file left over from a previous interrupted run before
  # doing anything else, so retries stay idempotent (see header comment).
  if [[ -f "$pending" ]]; then
    cat "$pending" >> "$archive_file"
    rm -f "$pending"
    cs_info "recovered leftover $pending into $archive_file"
  fi

  if [[ ! -f "$live" ]]; then
    cs_info "no live failure-log.jsonl (nothing to archive)"
    return 0
  fi

  if [[ -f "$archive_file" ]]; then
    mv "$live" "$pending"
    cat "$pending" >> "$archive_file"
    rm -f "$pending"
    cs_success "appended to existing archive: $archive_file"
  else
    mv "$live" "$archive_file"
    cs_success "archived: $archive_file"
  fi
}

for proj in "${PROJECTS[@]}"; do
  archive_one "$proj"
done
