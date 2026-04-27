#!/usr/bin/env bash
# post-stop-dispatcher.sh — Stop — delegate to the project-local
# .claude/hooks/post-stop.sh if present. Same rationale as post-edit-dispatcher.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

INPUT="$(hk_read_input)"
proj_hook="${PROJECT_ROOT}/.claude/hooks/post-stop.sh"

if [[ -x "$proj_hook" ]]; then
  printf '%s' "$INPUT" | "$proj_hook" || {
    rc=$?
    hk_log post-stop-dispatcher "project hook failed rc=$rc ($proj_hook)"
    exit "$rc"
  }
fi

exit 0
