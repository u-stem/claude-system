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

  # meta/decisions/README.md is the decision index ADR 0027 introduced: every
  # ADR file must be listed in its "ADR 一覧" table, and every 出典 named in
  # its "現行の決定" tables must resolve to a real ADR file.
  printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
    '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
    '| x | y | z | w | 0001 |' '' \
    '## ADR 一覧(0001〜0002 は凍結)' '' \
    '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
    '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
    '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
    > "$d/meta/decisions/README.md"
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
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0003 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0003](./0003-third.md) | Third | Accepted | 2026-01-01 |' \
  > "$FIX/meta/decisions/README.md"
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

# --- decision index parity (meta/decisions/README.md, ADR 0027) ----------------
# Every ADR file must be listed in the README's "ADR 一覧" table, or the index
# can silently fall behind the files it claims to catalog.
make_fixture "$FIX"
printf '%s\n' '# ADR 0003: Third' '' '- **Status**: Accepted' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0003-third.md"
fail_case "ADR missing from the README's ADR 一覧 table is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0003: Third' '' '- **Status**: Accepted' '' '## Context' 'x' \
  > "$FIX/meta/decisions/0003-third.md"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0003 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0003](./0003-third.md) | Third | Accepted | 2026-01-01 |' \
  > "$FIX/meta/decisions/README.md"
pass_case "ADR listed in the README's ADR 一覧 table passes" "$CHECK" --root "$FIX"

# --- 覆す決定 back-reference (ADRs numbered 0027 and later) ---------------------
# ADR 0027 replaced Status-based supersession with a "## 覆す決定" section that
# names the ADR it overturns. The overturned ADR's row in the index must name
# the new ADR back, the same acknowledgement rule the old Status chain enforced.
make_fixture "$FIX"
printf '%s\n' '# ADR 0027: Overturn' '' '- **Status**: Accepted' '' '## 決定' 'x' '' \
  '## 覆す決定' '' 'ADR 0001 を覆す。' \
  > "$FIX/meta/decisions/0027-overturn.md"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0002 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0027](./0027-overturn.md) | Overturn | Accepted | 2026-09-06 |' \
  > "$FIX/meta/decisions/README.md"
fail_case "覆す決定 without a back-reference in the overturned ADR's row is caught" \
  "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0027: Overturn' '' '- **Status**: Accepted' '' '## 決定' 'x' '' \
  '## 覆す決定' '' 'ADR 0001 を覆す。' \
  > "$FIX/meta/decisions/0027-overturn.md"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0002 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First(0027 が覆す) | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0027](./0027-overturn.md) | Overturn | Accepted | 2026-09-06 |' \
  > "$FIX/meta/decisions/README.md"
pass_case "覆す決定 with a back-reference in the overturned ADR's row passes" \
  "$CHECK" --root "$FIX"

# --- README 現行の決定 出典 column must name an existing ADR --------------------
make_fixture "$FIX"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0099 |' '' \
  '## ADR 一覧(0001〜0002 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  > "$FIX/meta/decisions/README.md"
fail_case "README 出典 column naming a nonexistent ADR is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
pass_case "README 出典 column naming an existing ADR passes" "$CHECK" --root "$FIX"

# --- ADRs numbered 0027 and later must stay within the 60-line cap -------------
make_fixture "$FIX"
{
  printf '%s\n' '# ADR 0027: Long' '' '- **Status**: Accepted' '' '## 決定'
  for ((i = 0; i < 60; i++)); do printf 'line %d\n' "$i"; done
} > "$FIX/meta/decisions/0027-long.md"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0002 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0027](./0027-long.md) | Long | Accepted | 2026-09-06 |' \
  > "$FIX/meta/decisions/README.md"
fail_case "ADR numbered 0027+ over the 60-line cap is caught" "$CHECK" --root "$FIX"

make_fixture "$FIX"
printf '%s\n' '# ADR 0027: Short' '' '- **Status**: Accepted' '' '## 決定' 'x' \
  > "$FIX/meta/decisions/0027-short.md"
printf '%s\n' '# 決定索引' '' '## 現行の決定' '' \
  '| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |' '|---|---|---|---|---|' \
  '| x | y | z | w | 0001 |' '' \
  '## ADR 一覧(0001〜0002 は凍結)' '' \
  '| # | タイトル | Status | 日付 |' '|---|---|---|---|' \
  '| [0001](./0001-first.md) | First | Accepted | 2026-01-01 |' \
  '| [0002](./0002-second.md) | Second | Accepted | 2026-01-01 |' \
  '| [0027](./0027-short.md) | Short | Accepted | 2026-09-06 |' \
  > "$FIX/meta/decisions/README.md"
pass_case "ADR numbered 0027+ within the 60-line cap passes" "$CHECK" --root "$FIX"

# --- argument handling ----------------------------------------------------------
pass_case "--help works" "$CHECK" --help
fail_case "unknown argument is rejected" "$CHECK" --bogus

# --- summary ---------------------------------------------------------------------
echo "test-doc-parity: pass=$PASS fail=$FAIL"
[[ "$FAIL" -eq 0 ]]
