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
