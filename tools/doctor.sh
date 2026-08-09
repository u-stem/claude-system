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
  tools/doctor.sh --fast      Skip the slow pre-commit-grade checks (see below)
  tools/doctor.sh --verbose   Show every passing check too
  tools/doctor.sh --help

Tiers:
  full (default)  Everything. Used by CI (.github/workflows/doctor.yml) and by
                  humans before committing.
  --fast          Skips shellcheck and the delegated test suite, which together
                  are ~85% of the runtime (measured 2026-08-09: 6.10s full,
                  3.86s tests + 1.34s shellcheck). Both are pre-commit concerns
                  already covered by CI, and the Stop hook re-runs this on every
                  turn under a 10s CPU ulimit — at 6.10s the full run sat at 61%
                  of that cap, where an overrun truncates last-doctor.log with
                  no error. Everything that detects *drift in the live machine
                  state* (symlinks, settings sync, plugin parity, secrets) stays
                  in the fast tier, because that is what a per-turn check is for.

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
  - subagent effort value validity and haiku+xhigh/max combination (ADR 0013)
  - settings auto-sync wiring and drift (tools/sync-settings.sh --check, ADR 0017)
  - machine-overrides file free of policy keys (model/effortLevel/fallbackModel, ADR 0022)
  - plugins enabled in the template are actually installed (ADR 0023)
EOF
}

cs_show_help_if_requested "${1:-}"

VERBOSE=0
FAST=0
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    --fast)    FAST=1 ;;
    *) cs_error "Unknown arg: $arg"; exit 2 ;;
  esac
done

cs_require_root_dir
cd "$CS_ROOT"

ERRORS=0
WARNINGS=0
CHECKS=0
SKIPPED=0

ok()    { CHECKS=$((CHECKS + 1)); [[ "$VERBOSE" == "1" ]] && cs_success "$*"; return 0; }
warn()  { CHECKS=$((CHECKS + 1)); WARNINGS=$((WARNINGS + 1)); cs_warn "$*"; }
fail()  { CHECKS=$((CHECKS + 1)); ERRORS=$((ERRORS + 1));   cs_error "$*"; }
# A tier-skipped check is neither passing nor failing. Counting it as ok would
# let a summary reader (or a future automated gate) read "60 ok" as "60 things
# verified" when --fast verified fewer.
skip()  { CHECKS=$((CHECKS + 1)); SKIPPED=$((SKIPPED + 1)); [[ "$VERBOSE" == "1" ]] && cs_info "$*"; return 0; }

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
  # `effort` is optional (ADR 0013); when present, validate its value and
  # flag the haiku + xhigh/max combination that ADR 0013 documents as
  # unsupported ("available levels are model-dependent").
  effort_field="$(head -10 "$sub" | grep '^effort:' | head -1 | cut -d: -f2 | tr -d ' ')"
  model_field="$(head -10 "$sub" | grep '^model:' | head -1 | cut -d: -f2 | tr -d ' ')"
  if [[ -n "$effort_field" ]]; then
    case "$effort_field" in
      low|medium|high|xhigh|max) : ;;
      *) fail "subagent invalid effort '$effort_field' (want low|medium|high|xhigh|max): $sub" ;;
    esac
    if [[ "$model_field" == "haiku" && ("$effort_field" == "xhigh" || "$effort_field" == "max") ]]; then
      warn "subagent effort '$effort_field' with model haiku (ADR 0013: xhigh/max unsupported on haiku): $sub"
    fi
  fi
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
if [[ $FAST -eq 1 ]]; then
  skip "shellcheck skipped (--fast; covered by CI shellcheck.yml)"
elif command -v shellcheck >/dev/null 2>&1; then
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
# Guard self-checks that are cheap enough to run every turn. Measured
# 2026-08-09: the identifier sync test is 0.13s, but test-pre-bash-guard.sh is
# 2.13s (35 hook invocations, each a bash + jq spawn) — that would undo most of
# the fast tier. It runs in tools/githooks/pre-push instead, which is the point
# where a broken guard actually matters, since this repo pushes to main.
FAST_TESTS=(tests/test-user-identifier-patterns.sh)
for t in "${FAST_TESTS[@]}"; do
  if [[ -x "$t" ]]; then
    set +e
    out="$("$t" 2>&1)"; rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then ok "$(basename "$t") pass"
    else fail "$(basename "$t") failed:"; printf '%s\n' "$out" >&2
    fi
  else
    warn "$t not present or not executable"
  fi
done

if [[ $FAST -eq 1 ]]; then
  skip "remaining delegated tests skipped (--fast; covered by CI doctor.yml)"
else
  for t in tests/lint-skills.sh tests/lint-principles-language.sh \
           tests/check-circular-refs.sh tests/validate-frontmatter.sh \
           tests/test-check-failure-patterns.sh tests/test-subagent-stop-record.sh \
           tests/test-subagent-stop-audit.sh tests/test-sync-settings.sh \
           tests/test-hooks-lib.sh tests/test-log-bash-failure.sh; do
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
fi

# ---------------------------------------------------------------------------
# 12. settings auto-sync state (informational on machines without deployment)
# ---------------------------------------------------------------------------
cs_step "settings auto-sync (ADR 0017)"
if [[ -f "$CLAUDE_HOME/settings.json" ]]; then
  hooks_path="$(git config --get core.hooksPath 2>/dev/null || true)"
  if [[ "$hooks_path" == "tools/githooks" ]]; then
    ok "core.hooksPath -> tools/githooks"
  else
    warn "core.hooksPath not wired (auto-sync inactive); run tools/setup.sh or: git config core.hooksPath tools/githooks"
  fi
  if [[ -x tools/sync-settings.sh ]]; then
    if tools/sync-settings.sh --check >/dev/null 2>&1; then
      ok "deployed settings.json in sync with template + overrides"
    else
      warn "settings drift detected; review tools/sync-settings.sh (dry-run diff), then --apply"
    fi
  else
    warn "tools/sync-settings.sh missing or not executable"
  fi
else
  ok "~/.claude/settings.json not deployed on this machine (informational)"
fi

# Policy keys (model / effortLevel / fallbackModel) belong in the repo
# template, not the machine-local overrides file — overriding them locally
# silently diverges from the committed policy (ADR 0017 merge model, ADR 0022).
OVERRIDES_FILE="$CLAUDE_HOME/settings.machine-overrides.json"
if [[ -f "$OVERRIDES_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    if jq -e '(has("model") or has("effortLevel") or has("fallbackModel"))' \
      "$OVERRIDES_FILE" >/dev/null 2>&1; then
      warn "policy key overridden locally; policy keys belong in the template (ADR 0022): $OVERRIDES_FILE"
    else
      ok "no policy keys in machine overrides: $OVERRIDES_FILE"
    fi
  else
    warn "jq not installed; skipping machine-overrides policy-key check"
  fi
else
  ok "no machine-overrides file present"
fi

# ---------------------------------------------------------------------------
# 13. enabledPlugins declared in the template vs actually installed (ADR 0023)
#
# Deliberately file-based: doctor.sh runs from the Stop hook every turn, so
# shelling out to `claude plugin list` would trigger marketplace refreshes and
# network waits on each turn. One-directional by design — installed-but-not-
# declared is a normal temporary trial and must not warn.
# ---------------------------------------------------------------------------
cs_step "declared plugins vs installed"
PLUGIN_STATE="$CLAUDE_HOME/plugins/installed_plugins.json"
PLUGIN_TEMPLATE="adapters/claude-code/user-level/settings.json.template"
if [[ ! -f "$CLAUDE_HOME/settings.json" ]]; then
  ok "~/.claude/settings.json not deployed; skipping plugin check (informational)"
elif ! command -v jq >/dev/null 2>&1; then
  warn "jq not installed; skipping declared-plugin check"
elif [[ ! -f "$PLUGIN_STATE" ]]; then
  warn "plugin state absent ($PLUGIN_STATE); declared plugins cannot be verified"
else
  plugin_schema="$(jq -r '.version // empty' "$PLUGIN_STATE" 2>/dev/null || true)"
  if [[ "$plugin_schema" != "2" ]]; then
    warn "unknown installed_plugins.json schema version '${plugin_schema:-none}'; skipping declared-plugin check"
  else
    declared_missing=""
    while IFS= read -r decl; do
      [[ -z "$decl" ]] && continue
      if ! jq -e --arg k "$decl" '.plugins | has($k)' "$PLUGIN_STATE" >/dev/null 2>&1; then
        declared_missing="$declared_missing $decl"
      fi
    done < <(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' \
               "$PLUGIN_TEMPLATE" 2>/dev/null || true)
    if [[ -n "$declared_missing" ]]; then
      warn "enabledPlugins declared but not installed:${declared_missing} (run tools/setup-plugins.sh)"
    else
      ok "every plugin enabled in the template is installed"
    fi

    # Plugins install unpinned (`claude plugin install <name@marketplace>` takes
    # no version), so the template records the version that was audited and this
    # compares against it. A mismatch is not a failure — it means the installed
    # payload was never reviewed, so re-run the ADR 0023 §3 inventory.
    while IFS=$'\t' read -r want_key want_ver; do
      [[ -z "$want_key" || -z "$want_ver" ]] && continue
      have_ver="$(jq -r --arg k "$want_key" '.plugins[$k][0].version // empty' "$PLUGIN_STATE" 2>/dev/null || true)"
      [[ -z "$have_ver" ]] && continue   # missing install already reported above
      if [[ "$have_ver" != "$want_ver" ]]; then
        warn "plugin $want_key is $have_ver but the template records $want_ver as audited; re-inventory hooks/MCP/agents/skills (ADR 0023 §3)"
      else
        ok "plugin $want_key matches the audited version ($want_ver)"
      fi
    done < <(jq -r '.["// auditedPluginVersions"] // {} | to_entries[] | "\(.key)\t\(.value)"' \
               "$PLUGIN_TEMPLATE" 2>/dev/null || true)
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
cs_step "Summary"
printf '  checks : %d\n' "$CHECKS"
printf '  ok     : %d\n' "$((CHECKS - WARNINGS - ERRORS - SKIPPED))"
[[ $SKIPPED -gt 0 ]] && printf '  skipped: %d (--fast tier; run without --fast or see CI)\n' "$SKIPPED"
printf '  warn   : %d\n' "$WARNINGS"
printf '  error  : %d\n' "$ERRORS"

if [[ $ERRORS -gt 0 ]]; then
  cs_error "doctor.sh: $ERRORS error(s)"
  exit 1
fi
cs_success "doctor.sh: clean (warnings: $WARNINGS)"
