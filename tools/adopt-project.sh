#!/usr/bin/env bash
# tools/adopt-project.sh — bring an existing project under claude-system management.
# Non-destructive: backs up any existing CLAUDE.md before any modification.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
adopt-project.sh — adopt an existing project.

Usage:
  tools/adopt-project.sh <project-path>
  tools/adopt-project.sh --help

Steps:
  1. Inventory existing CLAUDE.md, .cursor/, docs/.
  2. Back up CLAUDE.md to ~/.claude-system-backups/ (if present).
  3. Interactively choose which project-fragments/ files to @-reference.
  4. Append a fragments-import block to CLAUDE.md (skip if already present).
  5. Create $CS_ROOT/projects/<name>/ for project-local notes (gitignored).
EOF
}

cs_show_help_if_requested "${1:-}"

if [[ $# -ne 1 ]]; then
  cs_error "Usage: tools/adopt-project.sh <project-path>"
  exit 2
fi

cs_require_macos
cs_require_root_dir

PROJ_PATH="$1"
if [[ ! -d "$PROJ_PATH" ]]; then
  cs_error "Not a directory: $PROJ_PATH"
  exit 2
fi
PROJ_PATH="$(cd "$PROJ_PATH" && pwd)"
PROJ_NAME="$(basename "$PROJ_PATH")"

cs_step "Adopting project: $PROJ_NAME ($PROJ_PATH)"

cs_ensure_backup_dir

# 1. Inventory
cs_step "Inventory"
[[ -f "$PROJ_PATH/CLAUDE.md" ]]   && cs_info "found CLAUDE.md"   || cs_info "no CLAUDE.md"
[[ -d "$PROJ_PATH/.cursor" ]]     && cs_info "found .cursor/"    || cs_info "no .cursor/"
[[ -d "$PROJ_PATH/docs" ]]        && cs_info "found docs/"       || cs_info "no docs/"
[[ -d "$PROJ_PATH/docs/adr" ]]    && cs_info "found docs/adr/"   || cs_info "no docs/adr/"

# 2. Backup CLAUDE.md (project-scoped naming so unadopt/restore can locate
# this project's backup without scanning every project's backups).
if [[ -f "$PROJ_PATH/CLAUDE.md" ]]; then
  bk="$(cs_backup_path_for_project "$PROJ_NAME" "$PROJ_PATH/CLAUDE.md")"
  cp "$PROJ_PATH/CLAUDE.md" "$bk"
  cs_success "Backed up CLAUDE.md -> $bk"
fi

# 3. Choose fragments
cs_step "Available fragments"
FRAG_DIR="$CS_ROOT/adapters/claude-code/project-fragments"
mapfile -t fragments < <(find "$FRAG_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' ! -name 'adr-template.md' | sort)
if [[ ${#fragments[@]} -eq 0 ]]; then
  cs_warn "No fragments found in $FRAG_DIR"
  exit 0
fi

i=1
for f in "${fragments[@]}"; do
  printf '  %d. %s\n' "$i" "$(basename "$f")"
  i=$((i + 1))
done
printf '  %d. (none, skip fragment selection)\n' "$i"

cs_info "Enter space-separated indices to import (e.g. \"1 3\"). Empty for none."
if [[ ! -t 0 ]]; then
  cs_warn "Non-interactive shell; skipping fragment selection."
  selected=()
else
  printf 'Selection: '
  read -r raw
  selected=()
  for n in $raw; do
    if [[ "$n" =~ ^[0-9]+$ ]] && [[ "$n" -ge 1 ]] && [[ "$n" -le "${#fragments[@]}" ]]; then
      selected+=("${fragments[$((n - 1))]}")
    fi
  done
fi

# 4. Append fragments-import block to CLAUDE.md
if [[ ${#selected[@]} -gt 0 ]]; then
  marker="<!-- claude-system: fragments-import -->"
  if [[ -f "$PROJ_PATH/CLAUDE.md" ]] && grep -q "$marker" "$PROJ_PATH/CLAUDE.md"; then
    cs_warn "fragments-import block already present; skipping append."
  else
    {
      echo
      echo "$marker"
      echo "## 共通基盤の参照(claude-system project-fragments)"
      echo
      for f in "${selected[@]}"; do
        rel="$(basename "$f")"
        echo "@~/ws/claude-system/adapters/claude-code/project-fragments/$rel"
      done
    } >> "$PROJ_PATH/CLAUDE.md"
    cs_success "Appended fragments-import block to $PROJ_PATH/CLAUDE.md"
  fi
fi

# 5. Companion projects/ entry
PROJECTS_ENTRY="$CS_ROOT/projects/$PROJ_NAME"
mkdir -p "$PROJECTS_ENTRY"
touch "$PROJECTS_ENTRY/.gitkeep"
cs_success "Created $PROJECTS_ENTRY (gitignored)"

cs_step "Done"
cs_success "Adoption complete. Run tools/doctor.sh to verify."
