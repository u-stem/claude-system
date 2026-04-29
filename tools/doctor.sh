#!/usr/bin/env bash
# tools/doctor.sh — repo integrity check.
# Reports OK / WARN / ERROR per check, then a summary. Exit 0 if no errors.
#
# Usage:
#   tools/doctor.sh [--verbose]
#   tools/doctor.sh --help

# Tildes in display strings here are intentional labels (~/.claude is the
# real, well-known path users recognise). They are not used as filesystem
# arguments — use $HOME for actual paths instead.
# shellcheck disable=SC2088

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
doctor.sh — claude-system integrity checks.

Usage:
  tools/doctor.sh             Run all checks
  tools/doctor.sh --verbose   Show every passing check too
  tools/doctor.sh --help

Checks:
  - ~/.claude symlink state (informational; expected unset until Phase 10)
  - skill / subagent / command frontmatter (name, description, recommended_model/tools)
  - skill directory name matches frontmatter `name`
  - SKILL.md / subagent body presence
  - @<file> reference targets exist
  - principles/ practices/ free of forbidden tool-specific words
  - VERSION file present
  - shellcheck on tools/ tests/ adapters/.../hooks (if installed)
  - JSON validity of settings.json.template / .gitleaks.toml (informational)
  - gitleaks scan of tracked content (if installed)
  - ADR draft TODO placeholders ({{TODO: ...}}) in *.md.draft files
EOF
}

cs_show_help_if_requested "${1:-}"

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    *) cs_error "Unknown arg: $arg"; exit 2 ;;
  esac
done

cs_require_root_dir
cd "$CS_ROOT"

ERRORS=0
WARNINGS=0
CHECKS=0

ok()    { CHECKS=$((CHECKS + 1)); [[ "$VERBOSE" == "1" ]] && cs_success "$*"; return 0; }
warn()  { CHECKS=$((CHECKS + 1)); WARNINGS=$((WARNINGS + 1)); cs_warn "$*"; }
fail()  { CHECKS=$((CHECKS + 1)); ERRORS=$((ERRORS + 1));   cs_error "$*"; }

# ---------------------------------------------------------------------------
# 1. ~/.claude symlink state (informational until Phase 10)
# ---------------------------------------------------------------------------
cs_step "~/.claude symlink state"
CLAUDE_HOME="$HOME/.claude"
if [[ -d "$CLAUDE_HOME" ]] && [[ ! -L "$CLAUDE_HOME" ]]; then
  for sub in CLAUDE.md skills hooks commands agents; do
    target="$CLAUDE_HOME/$sub"
    if [[ -L "$target" ]]; then
      dest="$(readlink "$target")"
      case "$dest" in
        *claude-system/*) ok "~/.claude/$sub -> claude-system" ;;
        *claude-settings/*) warn "~/.claude/$sub still points at claude-settings (expected during Phase 0-9): $dest" ;;
        *) warn "~/.claude/$sub -> $dest" ;;
      esac
    else
      ok "~/.claude/$sub not a symlink (informational)"
    fi
  done
else
  ok "~/.claude not yet provisioned (expected pre-Phase 10)"
fi

# ---------------------------------------------------------------------------
# 2. skill frontmatter / structure
# ---------------------------------------------------------------------------
cs_step "skill frontmatter and structure"
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  for field in name description recommended_model; do
    if ! head -10 "$skill" | grep -q "^${field}:"; then
      fail "skill missing $field: $skill"
    fi
  done
  dir_name="$(basename "$(dirname "$skill")")"
  name_field="$(grep '^name:' "$skill" | head -1 | cut -d: -f2 | tr -d ' ')"
  if [[ "$dir_name" != "$name_field" ]]; then
    fail "skill dir/name mismatch: dir=$dir_name name=$name_field ($skill)"
  fi
  desc="$(grep '^description:' "$skill" | head -1 | sed 's/^description: //')"
  # `wc -m` returns bytes when LC_ALL is unset on macOS BSD; force UTF-8 so
  # CJK descriptions are counted as characters.
  chars="$(printf '%s' "$desc" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')"
  if [[ "$chars" -gt 50 ]]; then
    warn "skill description over 50 chars ($chars): $skill"
  fi
  lines="$(wc -l < "$skill" | tr -d ' ')"
  if [[ "$lines" -gt 200 ]]; then
    warn "skill exceeds 200 lines ($lines): $skill (consider references/)"
  fi
  ok "skill structure: $skill"
done

# ---------------------------------------------------------------------------
# 3. subagent frontmatter
# ---------------------------------------------------------------------------
cs_step "subagent frontmatter"
for sub in adapters/claude-code/subagents/*.md; do
  [[ -f "$sub" ]] || continue
  case "$(basename "$sub")" in
    _index.md|README.md) continue ;;
  esac
  for field in name description tools model; do
    if ! head -10 "$sub" | grep -q "^${field}:"; then
      fail "subagent missing $field: $sub"
    fi
  done
  ok "subagent frontmatter: $sub"
done

# ---------------------------------------------------------------------------
# 4. slash command frontmatter
# ---------------------------------------------------------------------------
cs_step "slash command frontmatter"
for cmd in adapters/claude-code/user-level/commands/*.md; do
  [[ -f "$cmd" ]] || continue
  case "$(basename "$cmd")" in
    _index.md|README.md) continue ;;
  esac
  for field in name description; do
    if ! head -10 "$cmd" | grep -q "^${field}:"; then
      fail "command missing $field: $cmd"
    fi
  done
  ok "command frontmatter: $cmd"
done

# ---------------------------------------------------------------------------
# 5. forbidden words in principles/ practices/
# ---------------------------------------------------------------------------
cs_step "forbidden words in principles/ practices/"
if [[ -f meta/forbidden-words.txt ]]; then
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    case "$word" in \#*) continue ;; esac
    matches="$(grep -ril "$word" principles/ practices/ 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
      while IFS= read -r m; do
        fail "forbidden word '$word' found in $m"
      done <<<"$matches"
    fi
  done < meta/forbidden-words.txt
  ok "forbidden words check complete"
else
  warn "meta/forbidden-words.txt not found"
fi

# ---------------------------------------------------------------------------
# 6. VERSION file
# ---------------------------------------------------------------------------
cs_step "VERSION file"
if [[ -f adapters/claude-code/VERSION ]]; then
  ok "VERSION = $(cat adapters/claude-code/VERSION)"
else
  fail "adapters/claude-code/VERSION missing"
fi

# ---------------------------------------------------------------------------
# 7. JSON validity (settings.json.template, .gitleaks.toml is TOML so skip)
# ---------------------------------------------------------------------------
cs_step "JSON validity"
if command -v jq >/dev/null 2>&1; then
  declare -a JSON_FILES=(
    adapters/claude-code/user-level/settings.json.template
    adapters/claude-code/user-level/mcp/servers.template.json
  )
  for json in "${JSON_FILES[@]}"; do
    [[ -f "$json" ]] || { warn "$json not found"; continue; }
    if jq empty "$json" >/dev/null 2>&1; then
      ok "valid JSON: $json"
    else
      fail "invalid JSON: $json"
    fi
  done
else
  warn "jq not installed; skipping JSON validity"
fi

# ---------------------------------------------------------------------------
# 8. shellcheck
# ---------------------------------------------------------------------------
cs_step "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  set +e
  # Note: `tools/*.sh` does not recurse, so subdirectories under tools/
  # (currently `tools/migrate/`) need to be added explicitly.
  shellcheck_targets=(tools/*.sh tools/migrate/*.sh tests/*.sh)
  if [[ -d adapters/claude-code/user-level/hooks ]]; then
    while IFS= read -r -d '' f; do
      shellcheck_targets+=("$f")
    done < <(find adapters/claude-code/user-level/hooks -name '*.sh' -print0 2>/dev/null)
  fi
  # `-S warning` filters out info-level (SC1091 source-following, SC2012 ls vs find,
  # SC2015 A&&B||C). We accept those as stylistic/informational; warnings and errors
  # block the build.
  out="$(shellcheck -S warning "${shellcheck_targets[@]}" 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    ok "shellcheck pass on ${#shellcheck_targets[@]} files (warning level)"
  else
    fail "shellcheck warnings/errors:"
    printf '%s\n' "$out" >&2
  fi
else
  warn "shellcheck not installed"
fi

# ---------------------------------------------------------------------------
# 9. gitleaks (informational)
# ---------------------------------------------------------------------------
cs_step "gitleaks scan"
if command -v gitleaks >/dev/null 2>&1; then
  set +e
  out="$(gitleaks detect --source . --no-git --redact 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    ok "gitleaks: no leaks found"
  else
    fail "gitleaks reported issues:"
    printf '%s\n' "$out" | tail -20 >&2
  fi
else
  warn "gitleaks not installed"
fi

# ---------------------------------------------------------------------------
# 10. ADR draft TODO placeholders
# ---------------------------------------------------------------------------
cs_step "ADR draft placeholders ({{TODO: ...}})"
draft_files=()
while IFS= read -r -d '' f; do
  draft_files+=("$f")
done < <(find . -path ./.git -prune -o -name '*.md.draft' -print0 2>/dev/null)

if [[ ${#draft_files[@]} -eq 0 ]]; then
  ok "no *.md.draft files in repo"
else
  for f in "${draft_files[@]}"; do
    if grep -q '{{TODO:' "$f"; then
      warn "$f has unresolved {{TODO: ...}} placeholders"
    else
      ok "draft has no TODO placeholders: $f"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 11. Optional sub-tests if present
# ---------------------------------------------------------------------------
cs_step "delegated lint scripts"
for t in tests/lint-skills.sh tests/lint-principles-language.sh \
         tests/check-circular-refs.sh tests/validate-frontmatter.sh; do
  if [[ -x "$t" ]]; then
    set +e
    out="$("$t" 2>&1)"
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      ok "$(basename "$t") pass"
    else
      fail "$(basename "$t") failed:"
      printf '%s\n' "$out" >&2
    fi
  else
    warn "$t not present or not executable"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
cs_step "Summary"
printf '  checks : %d\n' "$CHECKS"
printf '  ok     : %d\n' "$((CHECKS - WARNINGS - ERRORS))"
printf '  warn   : %d\n' "$WARNINGS"
printf '  error  : %d\n' "$ERRORS"

if [[ $ERRORS -gt 0 ]]; then
  cs_error "doctor.sh: $ERRORS error(s)"
  exit 1
fi
cs_success "doctor.sh: clean (warnings: $WARNINGS)"
