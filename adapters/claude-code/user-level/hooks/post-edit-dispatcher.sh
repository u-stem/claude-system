#!/usr/bin/env bash
# post-edit-dispatcher.sh — PostToolUse(Edit|Write) — delegate to the
# project-local .claude/hooks/post-edit.sh if present.
#
# Rationale: the global hook stays language-agnostic. Project owners place
# language-specific lint/typecheck logic at .claude/hooks/post-edit.sh
# (see adapters/claude-code/project-fragments/post-edit-*.sh examples).

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

# Forward stdin to the project hook so it sees the same JSON payload.
INPUT="$(hk_read_input)"
proj_hook="${PROJECT_ROOT}/.claude/hooks/post-edit.sh"

if [[ -x "$proj_hook" ]]; then
  printf '%s' "$INPUT" | "$proj_hook" || {
    rc=$?
    hk_log post-edit-dispatcher "project hook failed rc=$rc ($proj_hook)"
    exit "$rc"
  }
fi

exit 0
