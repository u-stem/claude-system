#!/usr/bin/env bash
# tests/check-circular-refs.sh — detect cycles in @-references between markdown files.
# Currently scans:
#   - principles/*.md, practices/*.md
#   - adapters/claude-code/project-fragments/*.md
# Reports a cycle and exits 1 if found.

set -euo pipefail

# shellcheck source=../tools/_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../tools/_lib.sh"

cs_require_root_dir
cd "$CS_ROOT"

# Build adjacency: file -> [referenced files]
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

declare -a FILES
while IFS= read -r -d '' f; do
  FILES+=("$f")
done < <(find principles practices adapters/claude-code/project-fragments \
              -maxdepth 2 -type f -name '*.md' -print0 2>/dev/null)

# Extract @<path> references. Resolve them roughly — leading ./, ../, ~/ all collapse to a normalized key.
extract_refs() {
  local file="$1"
  grep -oE '@[~./[:alnum:]_/-]+\.md' "$file" 2>/dev/null \
    | sed -E 's|^@||; s|^~/ws/claude-system/||' \
    | sed -E "s|^\.\./||g; s|^\./||g" \
    | sort -u || true
}

# Build forward edges file: "from\tto"
EDGES="$TMPDIR_LOCAL/edges.txt"
: > "$EDGES"
for f in "${FILES[@]}"; do
  rel="$(echo "$f" | sed -E 's|^\./||')"
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    printf '%s\t%s\n' "$rel" "$ref" >> "$EDGES"
  done < <(extract_refs "$f")
done

# Cycle detection via DFS in awk.
# `set -e` would terminate the script the moment awk returned 1, so we drop
# it around the awk invocation in order to capture the exit status reliably
# (same pattern as tools/doctor.sh's shellcheck section).
set +e
awk -F'\t' '
function dfs(node,    i, nb, neighbors) {
  if (state[node] == 1) {
    print "CYCLE: " stack_path(node);
    cycles++;
    return;
  }
  if (state[node] == 2) return;
  state[node] = 1;
  stack[++sp] = node;
  if (node in adj) {
    n = split(adj[node], neighbors, "|");
    for (i = 1; i <= n; i++) {
      if (neighbors[i] != "") dfs(neighbors[i]);
    }
  }
  state[node] = 2;
  sp--;
}
function stack_path(target,    i, s) {
  s = "";
  for (i = 1; i <= sp; i++) {
    s = s stack[i] " -> ";
  }
  return s target;
}
{
  if ($1 in adj) adj[$1] = adj[$1] "|" $2;
  else adj[$1] = $2;
  nodes[$1] = 1; nodes[$2] = 1;
}
END {
  cycles = 0;
  for (n in nodes) if (state[n] == 0) dfs(n);
  exit (cycles > 0) ? 1 : 0;
}
' "$EDGES"
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  cs_error "circular reference(s) detected"
  exit 1
fi
cs_success "check-circular-refs: clean"
