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
  - ~/.claude symlink state (expected to point at claude-system)
  - skill / subagent / command frontmatter (name, description, tools)
  - skill directory name matches frontmatter `name`
  - SKILL.md / subagent body presence
  - @<file> reference cycles (not target existence — see check-circular-refs.sh)
  - principles/ practices/ free of forbidden tool-specific words
  - VERSION file present
  - shellcheck on tools/ tests/ adapters/.../hooks (if installed)
  - JSON validity of settings.json.template / .gitleaks.toml (informational)
  - Betterleaks scan of tracked content, reading .gitleaks.toml (if installed)
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
# 1. ~/.claude symlink state
# ---------------------------------------------------------------------------
# The switchover completed on 2026-05-04, so these links are the expected steady
# state rather than a future step. A missing or non-symlink entry means this
# machine never ran tools/sync.sh, or something replaced the link since — worth
# a warning, not the "ok (informational)" this reported while the switch was
# still pending.
cs_step "~/.claude symlink state"
CLAUDE_HOME="$HOME/.claude"
if [[ -d "$CLAUDE_HOME" ]] && [[ ! -L "$CLAUDE_HOME" ]]; then
  for sub in CLAUDE.md skills hooks commands agents; do
    target="$CLAUDE_HOME/$sub"
    if [[ -L "$target" ]]; then
      dest="$(readlink "$target")"
      case "$dest" in
        *claude-system/*) ok "~/.claude/$sub -> claude-system" ;;
        *claude-settings/*) warn "~/.claude/$sub still points at the legacy claude-settings: $dest" ;;
        *) warn "~/.claude/$sub -> $dest (not claude-system)" ;;
      esac
    elif [[ -e "$target" ]]; then
      warn "~/.claude/$sub is not a symlink; review with tools/sync.sh --dry-run"
    else
      warn "~/.claude/$sub missing; review with tools/sync.sh --dry-run"
    fi
  done
else
  warn "$CLAUDE_HOME not provisioned; run tools/setup.sh, then tools/sync.sh"
fi

# ---------------------------------------------------------------------------
# 2. skill frontmatter / structure
# ---------------------------------------------------------------------------
cs_step "skill frontmatter and structure"
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  [[ -f "$skill" ]] || continue
  for field in name description; do
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
  # cs_str_chars resolves a UTF-8 locale that exists on this machine instead of
  # assuming en_US.UTF-8. Where none does, `wc -m` counts bytes and every CJK
  # description looks ~3x too long.
  if chars="$(cs_str_chars "$desc")"; then
    if [[ "$chars" -gt 50 ]]; then
      warn "skill description over 50 chars ($chars): $skill"
    fi
  else
    warn "no UTF-8 locale available; skipped description length check: $skill"
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
  base_name="$(basename "$cmd" .md)"
  name_field="$(head -10 "$cmd" | grep '^name:' | head -1 | cut -d: -f2 | tr -d ' ')"
  if [[ -n "$name_field" && "$base_name" != "$name_field" ]]; then
    fail "command file/name mismatch: file=$base_name name=$name_field ($cmd)"
  fi
  desc="$(head -10 "$cmd" | grep '^description:' | head -1 | sed 's/^description: //')"
  if chars="$(cs_str_chars "$desc")"; then
    if [[ "$chars" -gt 50 ]]; then
      warn "command description over 50 chars ($chars): $cmd"
    fi
  else
    warn "no UTF-8 locale available; skipped description length check: $cmd"
  fi
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
  # Versioned git hooks carry no .sh suffix, so no glob above reaches them.
  # They were the only executable shell in the repo outside every shellcheck
  # gate — including pre-push, which ADR 0024 §2a calls the one push guard that
  # holds no matter who invokes git.
  for gh in tools/githooks/*; do
    [[ -f "$gh" ]] && shellcheck_targets+=("$gh")
  done
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
# 9. Betterleaks (informational; gitleaks' local-layer successor, ADR pending)
# ---------------------------------------------------------------------------
cs_step "Betterleaks scan"
if command -v betterleaks >/dev/null 2>&1; then
  set +e
  out="$(betterleaks dir "$CS_ROOT" --config "$CS_ROOT/.gitleaks.toml" --redact --no-banner 2>&1)"
  rc=$?
  set -e
  if [[ $rc -eq 0 ]]; then
    ok "betterleaks: no leaks found"
  else
    fail "betterleaks reported issues:"
    printf '%s\n' "$out" | tail -20 >&2
  fi
else
  warn "betterleaks not installed"
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
           tests/check-doc-parity.sh \
           tests/test-check-failure-patterns.sh tests/test-subagent-stop-record.sh \
           tests/test-subagent-stop-audit.sh tests/test-sync-settings.sh \
           tests/test-hooks-lib.sh tests/test-log-bash-failure.sh \
           tests/test-guardrails-dry-run.sh tests/test-doc-parity.sh \
           tests/test-record-rework-signal.sh; do
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
    # Not only auto-sync: core.hooksPath also carries tools/githooks/pre-push,
    # which is the one push guard that works no matter who invokes git
    # (ADR 0024 §2a). Unwired means this machine can push unguarded.
    warn "core.hooksPath not wired: settings auto-sync AND the pre-push guard are both inactive; run tools/setup.sh or: git config core.hooksPath tools/githooks"
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
