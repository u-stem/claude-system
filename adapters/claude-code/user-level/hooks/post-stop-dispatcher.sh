#!/usr/bin/env bash
# post-stop-dispatcher.sh — Stop — delegate to the project-local
# .claude/hooks/post-stop.sh if present. Same rationale as post-edit-dispatcher.

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

hk_dispatch_project_hook post-stop
exit 0
