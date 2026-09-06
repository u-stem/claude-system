#!/usr/bin/env bash
# tests/test-doc-parity.sh — tests for tests/check-doc-parity.sh.
#
# The checks under test exist because every drift they detect was found by hand
# on 2026-08-09, months after it appeared. So the property that matters most
# here is the negative one: the checks must pass on the real repository. A
# parity check that cries wolf gets disabled, and then it protects nothing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/tests/check-doc-parity.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cs-test-doc-parity.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

pass_case() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (expected exit 0)" >&2
  fi
}

fail_case() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (expected non-zero exit)" >&2
  else
    PASS=$((PASS + 1))
  fi
}

# Build a minimal repo skeleton that satisfies every check, then break one
# thing per case. Starting from a clean fixture keeps each case independent.
make_fixture() {
  local d="$1"
  rm -rf "$d"
  mkdir -p "$d/tests" "$d/tools" "$d/adapters/claude-code/user-level/hooks" \
           "$d/meta/decisions" "$d/principles"

  printf '%s\n' '#!/usr/bin/env bash' > "$d/tests/alpha.sh"
  printf '%s\n' '# tests index' '- `alpha.sh` — does a thing' > "$d/tests/README.md"

  printf '%s\n' '#!/usr/bin/env bash' > "$d/tools/beta.sh"
  mkdir -p "$d/tools/githooks"
  printf '%s\n' '#!/usr/bin/env bash' > "$d/tools/githooks/delta"
  printf '%s\n' '# tools index' '- `beta.sh` — does a thing' \
    '- `githooks/delta` — a versioned git hook' > "$d/tools/README.md"

  printf '%s\n' '#!/usr/bin/env bash' > "$d/adapters/claude-code/user-level/hooks/gamma.sh"
  printf '%s\n' '# hooks index' '- `gamma.sh` — does a thing' \
    > "$d/adapters/claude-code/user-level/hooks/_README.md"

  printf '%s\n' '9.9.999' > "$d/adapters/claude-code/VERSION"
  printf '%s\n' '# claude-code adapter' '' \
    '[`./VERSION`](./VERSION) を参照(現在: 9.9.999)。' \
    > "$d/adapters/claude-code/README.md"

  printf '%s\n' '# ADR 0001: First' '' '- **Status**: Accepted' '' '## Context' 'x' \
    > "$d/meta/decisions/0001-first.md"
  printf '%s\n' '# ADR 0002: Second' '' '- **Status**: Accepted' '' '## Context' 'x' \
    > "$d/meta/decisions/0002-second.md"
}

FIX="$TMP/repo"

# --- the property that matters most: no false positives on the real repo ------
pass_case "real repository passes every parity check" "$CHECK"

# --- index parity -------------------------------------------------------------
make_fixture "$FIX"
pass_case "complete fixture passes" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '#!/usr/bin/env bash' > "$FIX/tests/orphan.sh"
fail_case "test script missing from tests/README.md is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '#!/usr/bin/env bash' > "$FIX/tools/orphan.sh"
fail_case "tool script missing from tools/README.md is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '#!/usr/bin/env bash' > "$FIX/adapters/claude-code/user-level/hooks/orphan.sh"
fail_case "hook missing from hooks/_README.md is caught" "$CHECK" --root "$FIX"

# tools/githooks/* carries no .sh suffix (versioned git hooks), so the tools/*.sh
# glob alone never reaches it. It needs its own sweep of the same directory.
make_fixture "$FIX"
printf '%s\n' '#!/usr/bin/env bash' > "$FIX/tools/githooks/orphan"
fail_case "extensionless githook missing from tools/README.md is caught" "$CHECK" --root "$FIX"

# The failure message must name the offending file, or the operator has to
# diff two listings by hand to find out what is missing.
make_fixture "$FIX"
printf '%s\n' '#!/usr/bin/env bash' > "$FIX/tests/orphan.sh"
# Capture rather than pipe: under `set -o pipefail` the checker's non-zero exit
# would fail the whole pipeline even when grep matched.
msg="$("$CHECK" --root "$FIX" 2>&1 || true)"
if printf '%s' "$msg" | /usr/bin/grep -q 'orphan.sh'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: failure message names the missing script" >&2
fi

# --- stale phase wording -------------------------------------------------------
make_fixture "$FIX"
printf '%s\n' '# guide' 'Phase 10 で `~/.claude/` に切り替える。' > "$FIX/principles/guide.md"
fail_case "stale 'Phase 10 で' wording is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# tools index' '- `beta.sh` — Phase 0-9 では --dry-run のみ' > "$FIX/tools/README.md"
fail_case "stale 'Phase 0-9' wording is caught" "$CHECK" --root "$FIX"

# Historical records must stay exempt. CHANGELOG and ADR bodies describe what
# was true when written; flagging them would force rewriting history to get a
# green check, which is the opposite of what the record is for.
make_fixture "$FIX"
printf '%s\n' '# changelog' 'Phase 10 で切り替えた(2026-05-04)。' > "$FIX/meta/CHANGELOG.md"
pass_case "CHANGELOG is exempt from stale wording" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0003: Third' '' '- **Status**: Accepted' '' '## Context' \
  'Phase 10 で切り替える予定。' > "$FIX/meta/decisions/0003-third.md"
pass_case "ADR bodies are exempt from stale wording" "$CHECK" --root "$FIX"

# --- adapter VERSION vs the prose that repeats it --------------------------------
# The pin and the sentence naming it drifted twice: ADR 0022 raised VERSION and
# left the README at the older value, and ADR 0023 had to fix both at once. Two
# places holding one fact is exactly what a textual check can hold together.
make_fixture "$FIX"
printf '%s\n' '9.9.1000' > "$FIX/adapters/claude-code/VERSION"
fail_case "adapter VERSION ahead of the README prose is caught" "$CHECK" --root "$FIX"

# Dropping the sentence must not be a way to pass. Otherwise the cheapest fix
# for a red check is deleting the statement the check exists to protect.
make_fixture "$FIX"
printf '%s\n' '# claude-code adapter' '' '前提バージョンは VERSION を参照。' \
  > "$FIX/adapters/claude-code/README.md"
fail_case "adapter README without the version prose is caught" "$CHECK" --root "$FIX"

# An adapter with no VERSION file is not yet pinned (adapters/codex is a bare
# directory today) and must not be dragged into the check.
make_fixture "$FIX"
rm -f "$FIX/adapters/claude-code/VERSION"
pass_case "adapter without a VERSION file is skipped" "$CHECK" --root "$FIX"

# The message must carry both values, or the operator still has to open two
# files to learn which one is stale.
make_fixture "$FIX"
printf '%s\n' '9.9.1000' > "$FIX/adapters/claude-code/VERSION"
msg="$("$CHECK" --root "$FIX" 2>&1 || true)"
if printf '%s' "$msg" | /usr/bin/grep -q '9.9.1000' \
   && printf '%s' "$msg" | /usr/bin/grep -q '9.9.999'; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: version parity message names both the pin and the prose" >&2
fi

# --- ADR status vocabulary -----------------------------------------------------
make_fixture "$FIX"
printf '%s\n' '# ADR 0003: Third' '' '- **Status**: Accepted(層 A のみ)' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0003-third.md"
fail_case "free-form ADR status is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0001: First' '' '- **Status**: Superseded by 0002' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0001-first.md"
printf '%s\n' '# ADR 0002: Second' '' '- **Status**: Accepted' '' '## Context' \
  'ADR 0001 を置き換える。' > "$FIX/meta/decisions/0002-second.md"
pass_case "supersede with a back-reference passes" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0001: First' '' '- **Status**: Partially superseded by 0002' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0001-first.md"
printf '%s\n' '# ADR 0002: Second' '' '- **Status**: Accepted' '' '## Context' \
  'ADR 0001 の一部を置き換える。' > "$FIX/meta/decisions/0002-second.md"
pass_case "partial supersede with a back-reference passes" "$CHECK" --root "$FIX"

# A status pointing at an ADR that does not exist is the failure mode ADR 0005
# actually hit: it reserved 0006 for a switchover record, and 0006 went to a
# different topic.
make_fixture "$FIX"
printf '%s\n' '# ADR 0001: First' '' '- **Status**: Superseded by 0099' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0001-first.md"
fail_case "supersede pointing at a nonexistent ADR is caught" "$CHECK" --root "$FIX"

# The successor must actually mention the ADR it replaces, otherwise the trail
# is one-directional and unreadable from the other end.
make_fixture "$FIX"
printf '%s\n' '# ADR 0001: First' '' '- **Status**: Superseded by 0002' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0001-first.md"
fail_case "supersede without a back-reference is caught" "$CHECK" --root "$FIX"

# --- argument handling ----------------------------------------------------------
pass_case "--help works" "$CHECK" --help
fail_case "unknown argument is rejected" "$CHECK" --bogus

# --- summary ---------------------------------------------------------------------
echo "test-doc-parity: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
