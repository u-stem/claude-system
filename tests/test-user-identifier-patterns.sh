#!/usr/bin/env bash
# tests/test-user-identifier-patterns.sh — keep the two identifier defenses in sync.
#
# The operator's username reaches disk in more than one shape. The warn layer
# (post-edit-validate.sh, user-level so it runs in EVERY project) and the block
# layer (.gitleaks.toml, claude-system only) each need every shape. They are
# written in different languages and cannot share code, so they drifted: the
# flattened form `-Users-<name>-` was added to the toml on 2026-08-09 while the
# shell layer still checked only `/Users/<name>/`. Two such paths had sat in
# meta/integration-trace.md since the 2026-04-29 bootstrap.
#
# This test is the mechanical guarantee that the drift cannot recur (ADR 0008
# Update 2026-08-09). If it fails, add the pattern to BOTH sides.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/adapters/claude-code/user-level/hooks/_lib.sh"
TOML="$ROOT/.gitleaks.toml"

PASS=0
FAIL=0
err() { FAIL=$((FAIL + 1)); echo "FAIL: $*" >&2; }
okay() { PASS=$((PASS + 1)); }

# shellcheck source=../adapters/claude-code/user-level/hooks/_lib.sh
source "$LIB"

# --- 1. the shell layer defines patterns at all --------------------------------
if [[ "${#HK_USER_IDENTIFIER_PATTERNS[@]}" -ge 2 ]]; then
  okay
else
  err "expected >=2 patterns in HK_USER_IDENTIFIER_PATTERNS, got ${#HK_USER_IDENTIFIER_PATTERNS[@]}"
fi

# --- 2. every shell pattern also exists as a gitleaks rule ---------------------
# gitleaks rule bodies are `regex = '''<pattern>'''`.
toml_patterns="$(/usr/bin/grep -oE "^regex = '''.*'''" "$TOML" | sed "s/^regex = '''//; s/'''$//")"
for pat in "${HK_USER_IDENTIFIER_PATTERNS[@]}"; do
  # `--` is required: patterns begin with `-` and grep would read them as flags.
  if printf '%s\n' "$toml_patterns" | /usr/bin/grep -qxF -- "$pat"; then
    okay
  else
    err "pattern '$pat' is in _lib.sh but has no matching gitleaks rule in .gitleaks.toml"
  fi
done

# --- 3. every identifier-ish gitleaks rule exists in the shell layer -----------
# Scoped to the Users-shaped rules; unrelated secret rules are out of scope.
while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  case "$pat" in *Users*) ;; *) continue ;; esac
  hit=0
  for shellpat in "${HK_USER_IDENTIFIER_PATTERNS[@]}"; do
    [[ "$shellpat" == "$pat" ]] && hit=1
  done
  if [[ $hit -eq 1 ]]; then
    okay
  else
    err "gitleaks rule '$pat' has no counterpart in HK_USER_IDENTIFIER_PATTERNS (_lib.sh)"
  fi
done <<< "$toml_patterns"

# --- 4. each pattern actually catches its real-world shape ---------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cs-test-ident.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

probe() { printf '%s\n' "$2" > "$TMP/probe.md"; hk_scan_user_identifiers "$TMP/probe.md" | /usr/bin/grep -q . && echo hit || echo miss; }


[[ "$(probe slash '/Users/someone/ws/proj/file.md')" == "hit" ]] \
  && okay || err "absolute path form not detected"
[[ "$(probe flat '.claude/projects/-Users-someone-ws-proj/memory/')" == "hit" ]] \
  && okay || err "flattened project-dir form not detected (the 2026-08-09 gap)"

# --- 5. documented placeholders must not trip ----------------------------------
[[ "$(probe ph1 '.claude/projects/-Users-<user>-ws-proj/memory/')" == "miss" ]] \
  && okay || err "placeholder '-Users-<user>-' false-positived"
[[ "$(probe ph2 'path is /Users/<name>/ws/proj')" == "miss" ]] \
  && okay || err "placeholder '/Users/<name>/' false-positived"

# --- 6. the tree itself is clean ------------------------------------------------
# Tracked files only: ignored paths (.claude/ logs) legitimately hold real paths.
leaked="$(git -C "$ROOT" ls-files -z 2>/dev/null \
  | xargs -0 /usr/bin/grep -lE '(-Users-[a-zA-Z0-9._]+-|/Users/[a-zA-Z0-9._-]+/)' 2>/dev/null \
  | /usr/bin/grep -vE '(^adapters/claude-code/user-level/hooks/|^\.gitleaks\.toml$|^tests/test-user-identifier-patterns\.sh$)' || true)"
if [[ -z "$leaked" ]]; then
  okay
else
  err "tracked files contain operator-identity paths: $leaked"
fi

echo "test-user-identifier-patterns: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
