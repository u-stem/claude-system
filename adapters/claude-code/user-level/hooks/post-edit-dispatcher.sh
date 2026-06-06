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

hk_dispatch_project_hook post-edit
exit 0
