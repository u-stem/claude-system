#!/usr/bin/env bash
# tools/_lib.sh — common helpers for claude-system shell scripts.
# Source this file from other scripts: `source "$(dirname "$0")/_lib.sh"`.
# macOS BSD-coreutils assumed. Idempotent helpers only — never mutate global state on source.

# Guard against double-sourcing.
if [[ -n "${_CLAUDE_SYSTEM_LIB_LOADED:-}" ]]; then
  return 0
fi
_CLAUDE_SYSTEM_LIB_LOADED=1

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

# Repo root resolved via this script's location (tools/_lib.sh -> ../).
# Use `realpath`/`readlink -f` is not portable on macOS without coreutils,
# so derive lexically from BASH_SOURCE.
_lib_self="${BASH_SOURCE[0]}"
CS_ROOT="$(cd "$(dirname "$_lib_self")/.." && pwd)"
export CS_ROOT

CS_BACKUP_ROOT="${CS_BACKUP_ROOT:-$HOME/.claude-system-backups}"
export CS_BACKUP_ROOT

CS_LOCK_DIR="${TMPDIR:-/tmp}"
export CS_LOCK_DIR

# ---------------------------------------------------------------------------
# Color output
# ---------------------------------------------------------------------------

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  CS_COLOR_RESET=$'\033[0m'
  CS_COLOR_RED=$'\033[31m'
  CS_COLOR_GREEN=$'\033[32m'
  CS_COLOR_YELLOW=$'\033[33m'
  CS_COLOR_BLUE=$'\033[34m'
  CS_COLOR_BOLD=$'\033[1m'
else
  CS_COLOR_RESET=""
  CS_COLOR_RED=""
  CS_COLOR_GREEN=""
  CS_COLOR_YELLOW=""
  CS_COLOR_BLUE=""
  CS_COLOR_BOLD=""
fi

cs_info()    { printf '%s[INFO]%s %s\n'    "$CS_COLOR_BLUE"   "$CS_COLOR_RESET" "$*"; }
cs_warn()    { printf '%s[WARN]%s %s\n'    "$CS_COLOR_YELLOW" "$CS_COLOR_RESET" "$*" >&2; }
cs_error()   { printf '%s[ERROR]%s %s\n'   "$CS_COLOR_RED"    "$CS_COLOR_RESET" "$*" >&2; }
cs_success() { printf '%s[OK]%s %s\n'      "$CS_COLOR_GREEN"  "$CS_COLOR_RESET" "$*"; }
cs_step()    { printf '\n%s==>%s %s%s%s\n' "$CS_COLOR_BLUE"   "$CS_COLOR_RESET" "$CS_COLOR_BOLD" "$*" "$CS_COLOR_RESET"; }

# ---------------------------------------------------------------------------
# Lock files
# ---------------------------------------------------------------------------
# Usage: cs_acquire_lock <name>; trap "cs_release_lock <name>" EXIT
# Lock is a directory created via mkdir (atomic on macOS).

cs_acquire_lock() {
  local name="$1"
  local lock="$CS_LOCK_DIR/claude-system.${name}.lock"
  if ! mkdir "$lock" 2>/dev/null; then
    cs_error "Lock '$name' is held by another process: $lock"
    cs_error "If stale, remove with: rmdir $lock"
    return 1
  fi
  echo "$lock"
}

cs_release_lock() {
  local name="$1"
  local lock="$CS_LOCK_DIR/claude-system.${name}.lock"
  rmdir "$lock" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Backups
# ---------------------------------------------------------------------------

cs_ensure_backup_dir() {
  mkdir -p "$CS_BACKUP_ROOT"
}

# Returns a unique backup path under $CS_BACKUP_ROOT for the given source path.
# Prints the destination path on stdout. Does NOT copy — caller decides cp/mv.
cs_backup_path_for() {
  local src="$1"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local base
  base="$(basename "$src")"
  echo "$CS_BACKUP_ROOT/${base}.backup-${stamp}"
}

# Returns a unique backup path scoped to a project name. The resulting filename
# is `<project>-<basename>.backup-<TIMESTAMP>` so adopt/unadopt/restore can
# locate "the backup of project X" without scanning every backup in the dir.
# Used by adopt-project.sh / unadopt-project.sh / restore-project.sh.
cs_backup_path_for_project() {
  local proj="$1"
  local src="$2"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  local base
  base="$(basename "$src")"
  echo "$CS_BACKUP_ROOT/${proj}-${base}.backup-${stamp}"
}

# Returns a glob pattern for finding backups of a specific project's file.
# Callers can use this with `ls -t` etc.
cs_backup_glob_for_project() {
  local proj="$1"
  local basename="$2"
  echo "$CS_BACKUP_ROOT/${proj}-${basename}.backup-*"
}

# cs_rotate_backups <glob-pattern> <keep-count> [--dry-run]
#
# Keeps the <keep-count> most-recently-modified files matching <glob-pattern>
# and removes the rest. <glob-pattern> is a literal directory + `-name` glob
# (e.g. "$CS_BACKUP_ROOT/settings.json.backup-*"), matched with `find
# -maxdepth 1` rather than shell globbing so an empty match doesn't leave a
# literal unexpanded pattern for the loop to choke on.
#
# Uses `stat -f %m` (BSD) rather than `ls -t`: `ls -t` output is meant for
# terminal display, not scripting (word-splits on whitespace in filenames and
# has no stable field separator for machine parsing).
#
# With --dry-run, prints what would be removed via cs_info and removes
# nothing — callers get an observable preview of the same selection logic
# that would run for real.
cs_rotate_backups() {
  local pattern="$1" keep="$2" dry_run="${3:-}"
  local dir base
  dir="$(dirname "$pattern")"
  base="$(basename "$pattern")"
  [[ -d "$dir" ]] || return 0

  local entries
  entries="$(find "$dir" -maxdepth 1 -type f -name "$base" -exec stat -f '%m %N' {} \; 2>/dev/null | sort -rn)"
  [[ -n "$entries" ]] || return 0

  local total
  total="$(printf '%s\n' "$entries" | wc -l | tr -d ' ')"
  [[ "$total" -gt "$keep" ]] || return 0

  local i=0 f line
  while IFS= read -r line; do
    i=$((i + 1))
    [[ "$i" -gt "$keep" ]] || continue
    f="${line#* }"
    if [[ "$dry_run" == "--dry-run" ]]; then
      cs_info "would remove old backup: $f"
    else
      rm -f "$f"
      cs_info "removed old backup: $f"
    fi
  done <<< "$entries"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

cs_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    cs_error "Required command not found: $cmd"
    return 1
  fi
}

cs_require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    cs_error "macOS only (BSD coreutils assumed). Detected: $(uname -s)"
    return 1
  fi
}

cs_require_root_dir() {
  if [[ ! -d "$CS_ROOT/principles" ]] || [[ ! -d "$CS_ROOT/adapters" ]]; then
    cs_error "Not inside a claude-system repo (CS_ROOT=$CS_ROOT)"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Interactive helpers (skip in CI / non-tty)
# ---------------------------------------------------------------------------

# cs_confirm "Proceed?" — returns 0 on y/Y, 1 otherwise. Defaults to N.
cs_confirm() {
  local prompt="${1:-Continue?}"
  if [[ ! -t 0 ]]; then
    cs_warn "Non-interactive shell, defaulting to 'no' for: $prompt"
    return 1
  fi
  local reply
  printf '%s [y/N]: ' "$prompt"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# cs_read_choice "Select:" "1" "2" "3" — prints chosen value on stdout.
cs_read_choice() {
  local prompt="$1"; shift
  local choices=("$@")
  if [[ ! -t 0 ]]; then
    cs_error "Non-interactive shell, cannot prompt for choice"
    return 1
  fi
  local reply
  while true; do
    printf '%s ' "$prompt"
    read -r reply
    for c in "${choices[@]}"; do
      if [[ "$reply" == "$c" ]]; then
        echo "$reply"
        return 0
      fi
    done
    cs_warn "Invalid choice. Options: ${choices[*]}"
  done
}

# cs_read_required "Project name: " — keeps asking until non-empty.
cs_read_required() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then
    cs_error "Non-interactive shell, cannot prompt: $prompt"
    return 1
  fi
  local reply
  while true; do
    printf '%s' "$prompt"
    read -r reply
    if [[ -n "$reply" ]]; then
      echo "$reply"
      return 0
    fi
    cs_warn "Value required, try again."
  done
}

# ---------------------------------------------------------------------------
# macOS BSD wrappers
# ---------------------------------------------------------------------------

# In-place sed that works on BSD without breaking GNU. Always pass an empty
# backup suffix on macOS (`-i ''`).
cs_sed_inplace() {
  sed -i '' "$@"
}

# Stat file mtime as Unix epoch (BSD `stat -f %m`).
cs_stat_mtime() {
  stat -f %m "$1"
}

# ---------------------------------------------------------------------------
# Locale-safe character counting
# ---------------------------------------------------------------------------

# cs_utf8_locale — print the name of a UTF-8 locale that exists here, or nothing.
#
# `wc -m` counts BYTES when the active locale is not UTF-8, which inflates every
# Japanese string to roughly three times its real length. Callers used to hard-
# code LC_ALL=en_US.UTF-8, which macOS ships but a CI image may not generate —
# and the failure is silent and wrong rather than loud: 12 of 16 skill
# descriptions would be reported as "over 50 chars" on a runner without it.
#
# Result is cached in the exported CS_UTF8_LOCALE env var, not a plain shell
# variable: callers invoke this via `$(...)` command substitution (see
# cs_str_chars below), which forks a subshell, so a local/global cache set
# inside that subshell never survives back to the caller — every skill re-ran
# `locale charmap` regardless. Exporting makes the cache visible to child
# processes too, so a whole `bash tools/doctor.sh` run pays the lookup once.
cs_utf8_locale() {
  if [[ -n "${CS_UTF8_LOCALE+x}" ]]; then
    printf '%s' "$CS_UTF8_LOCALE"
    return 0
  fi
  CS_UTF8_LOCALE=""
  local loc
  for loc in en_US.UTF-8 C.UTF-8 en_US.utf8 C.utf8; do
    if LC_ALL="$loc" locale charmap 2>/dev/null | grep -qi 'utf-\{0,1\}8'; then
      CS_UTF8_LOCALE="$loc"
      break
    fi
  done
  export CS_UTF8_LOCALE
  printf '%s' "$CS_UTF8_LOCALE"
}

# cs_str_chars <string> — print the character count on stdout.
# Returns 1 without printing when no UTF-8 locale exists, so callers can skip
# the check instead of acting on a fabricated length.
cs_str_chars() {
  local s="$1" loc
  loc="$(cs_utf8_locale)"
  [[ -n "$loc" ]] || return 1
  printf '%s' "$s" | LC_ALL="$loc" wc -m | tr -d ' '
}

# ---------------------------------------------------------------------------
# Help text helper — every script supports --help.
# ---------------------------------------------------------------------------

cs_show_help_if_requested() {
  case "${1:-}" in
    -h|--help)
      if declare -F cs_print_help >/dev/null 2>&1; then
        cs_print_help
      else
        echo "No help text defined."
      fi
      exit 0
      ;;
  esac
}
