#!/usr/bin/env bash
# tools/new-project.sh — bootstrap a new project under ~/ws/<name>/.
# Supports three modes:
#   1. Argumented:  new-project.sh <name> <template>
#   2. Interactive: new-project.sh                 (prompts for name + template)
#   3. From-scratch: interactive mode with template choice "0" / "none"
#                    creates a minimal skeleton (no template copy)

set -euo pipefail

# shellcheck source=./_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

cs_print_help() {
  cat <<'EOF'
new-project.sh — create a new project under ~/ws/<name>/.

Usage:
  tools/new-project.sh                       Interactive mode
  tools/new-project.sh <name> <template>     Direct mode
  tools/new-project.sh <name> none           From-scratch (no template)
  tools/new-project.sh --help

In interactive mode, the script first asks whether you have completed tech
stack selection (with ADR). If not, it nudges you to run the
project-tech-stack-decision skill first.

Templates are auto-discovered from
  $CS_ROOT/adapters/claude-code/project-templates/
Any directory containing _TEMPLATE_USAGE.md is considered a usable template.
Template maturity (完成 / 暫定 / skeleton / 不明) is read from _README.md.
EOF
}

cs_show_help_if_requested "${1:-}"

cs_require_macos
cs_require_root_dir

TEMPLATE_ROOT="$CS_ROOT/adapters/claude-code/project-templates"
WORKSPACE_ROOT="$HOME/ws"

# ---------------------------------------------------------------------------
# Template discovery
# ---------------------------------------------------------------------------

discover_templates() {
  local d
  for d in "$TEMPLATE_ROOT"/*/; do
    [[ -d "$d" ]] || continue
    local name
    name="$(basename "$d")"
    case "$name" in
      _*) continue ;;
    esac
    if [[ -f "$d/_TEMPLATE_USAGE.md" ]]; then
      echo "$name"
    fi
  done
}

# Read the maturity column for a given template from _README.md.
template_maturity() {
  local tname="$1"
  local readme="$TEMPLATE_ROOT/_README.md"
  if [[ ! -f "$readme" ]]; then
    echo "不明"
    return
  fi
  # Match the row in the maturity table: "| `tname` | maturity | ..."
  local line
  line="$(grep -E "^\| \`?${tname}\`? \|" "$readme" 2>/dev/null | head -1)"
  if [[ -z "$line" ]]; then
    echo "不明"
    return
  fi
  # Extract second column.
  echo "$line" | awk -F '|' '{gsub(/^ +| +$/, "", $3); print $3}' | head -1
}

# ---------------------------------------------------------------------------
# Interactive flow
# ---------------------------------------------------------------------------

interactive_flow() {
  cs_step "Interactive project bootstrap"

  PROJECT_NAME="$(cs_read_required 'プロジェクト名を入力してください: ')"

  echo
  echo "技術スタックの選定は完了していますか?"
  echo "  [1] はい(ADR を書いた、または明確な根拠がある)"
  echo "  [2] いいえ(これから検討)"
  STACK_DECIDED="$(cs_read_choice '選択:' 1 2)"

  if [[ "$STACK_DECIDED" == "2" ]]; then
    echo
    cs_warn "技術スタック選定が未完です。"
    cat <<EOF
   以下を実施してから new-project.sh を再実行することを推奨します:

   1. project-tech-stack-decision skill を起動して候補を網羅的に検討
      (Claude Code セッションで「project-tech-stack-decision skill を呼んでください」と依頼)
   2. ADR を docs/adr/0001-tech-stack.md として記録
   3. このスクリプトを再度実行

EOF
    if ! cs_confirm "それでも今すぐ進めますか?"; then
      cs_info "中止しました。"
      exit 0
    fi
  fi

  echo
  echo "利用可能なテンプレート:"
  local i=1
  local tlist=()
  while IFS= read -r t; do
    tlist+=("$t")
    local mat
    mat="$(template_maturity "$t")"
    printf '  %d. %-20s [%s]\n' "$i" "$t" "$mat"
    i=$((i + 1))
  done < <(discover_templates)
  printf '  %d. %-20s %s\n' "$i" "(なし、ゼロから始める)" "テンプレート未使用、最小骨格のみ作成"

  local zero_choice=$i
  local choices=()
  for ((j=1; j<=zero_choice; j++)); do choices+=("$j"); done
  CHOICE="$(cs_read_choice '選択:' "${choices[@]}")"

  if [[ "$CHOICE" == "$zero_choice" ]]; then
    TEMPLATE_NAME="none"
  else
    TEMPLATE_NAME="${tlist[$((CHOICE - 1))]}"
  fi
}

# ---------------------------------------------------------------------------
# Skeleton (from-scratch) creation
# ---------------------------------------------------------------------------

create_zero_skeleton() {
  local proj_dir="$1"
  local proj_name="$2"

  mkdir -p "$proj_dir/docs/adr"

  cat > "$proj_dir/CLAUDE.md" <<EOF
# CLAUDE.md ($proj_name)

このプロジェクト固有の指示を記述する。共通指示は \`~/.claude/CLAUDE.md\`(claude-system 由来)に従う。

## 技術スタック

(project-tech-stack-decision skill の結果を反映する欄)

- 採用スタック: TODO
- 主要バージョン: TODO
- 関連 ADR: \`docs/adr/0001-tech-stack.md\`

## 開発フロー

TODO: ローカル開発、テスト、デプロイの主要コマンドを記述。
EOF

  cat > "$proj_dir/README.md.template" <<EOF
# $proj_name

{{PROJECT_DESCRIPTION}}

## 開発

\`\`\`bash
# TODO: install / dev / test / build commands
\`\`\`
EOF

  cat > "$proj_dir/.gitignore" <<'EOF'
.DS_Store
*.log
node_modules/
dist/
.next/
.env
.env.*
!.env.example
.cache/
coverage/
EOF

  cat > "$proj_dir/.gitleaks.toml" <<'EOF'
[allowlist]
description = "Allow common false positives"
paths = [
  '''node_modules/''',
  '''\.next/''',
  '''dist/''',
  '''docs/adr/''',
]
EOF

  cat > "$proj_dir/docs/adr/README.md" <<'EOF'
# Architecture Decision Records

このディレクトリにはプロジェクト固有の重要な意思決定を ADR として記録する。

- 連番(0001 から)、欠番禁止、撤回しても番号は残す
- ファイル名: `NNNN-kebab-case-title.md`
- テンプレート: `~/ws/claude-system/adapters/claude-code/project-fragments/adr-template.md`
- 起票手順: `~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md`
EOF

  cat > "$proj_dir/docs/adr/0001-tech-stack.md.draft" <<EOF
# 0001. 技術スタック: (未確定)

- **Status**: Draft
- **Date**: $(date +%Y-%m-%d)
- **Decider**: プロジェクトオーナー

## Context

{{TODO: プロジェクトの目的・要件を記入}}

## Decision

{{TODO: 採用する技術スタックと根拠を記入}}

## Alternatives Considered

{{TODO: 検討した他の選択肢を記入}}

- 候補 1:
- 候補 2:

## Consequences

{{TODO: メリット / デメリット / トレードオフを記入}}

### Positive
-

### Negative
-

### Neutral
-

## 関連

- project-tech-stack-decision skill: ~/ws/claude-system/adapters/claude-code/user-level/skills/project-tech-stack-decision/SKILL.md
- adr-writing skill: ~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md
EOF
}

# ---------------------------------------------------------------------------
# Template-based creation
# ---------------------------------------------------------------------------

create_from_template() {
  local proj_dir="$1"
  local proj_name="$2"
  local template="$3"

  local src="$TEMPLATE_ROOT/$template"
  if [[ ! -d "$src" ]]; then
    cs_error "Template not found: $template"
    cs_error "Available templates:"
    discover_templates | sed 's/^/  - /'
    exit 2
  fi

  cs_info "Copying template '$template' -> $proj_dir"
  cp -R "$src/." "$proj_dir/"

  # Strip .template suffix.
  while IFS= read -r -d '' f; do
    mv "$f" "${f%.template}"
  done < <(find "$proj_dir" -name '*.template' -type f -print0)

  # Remove _TEMPLATE_USAGE.md from copy.
  rm -f "$proj_dir/_TEMPLATE_USAGE.md"

  # Replace {{PROJECT_NAME}}.
  while IFS= read -r -d '' f; do
    cs_sed_inplace "s|{{PROJECT_NAME}}|${proj_name}|g" "$f"
  done < <(find "$proj_dir" -type f \( -name '*.md' -o -name '*.json' -o -name '*.yaml' -o -name '*.yml' -o -name '*.toml' \) -print0)

  # Auto-generate ADR draft 0001-tech-stack.md.draft (does not overwrite existing 0001-*.md).
  local adr_dir="$proj_dir/docs/adr"
  if [[ -d "$adr_dir" ]] && [[ ! -f "$adr_dir/0001-tech-stack.md" ]] && [[ ! -f "$adr_dir/0001-tech-stack.md.draft" ]]; then
    cat > "$adr_dir/0001-tech-stack.md.draft" <<EOF
# 0001. 技術スタック: $template

- **Status**: Draft
- **Date**: $(date +%Y-%m-%d)
- **Decider**: プロジェクトオーナー

## Context

{{TODO: プロジェクトの目的・要件を記入}}

## Decision

\`$template\` テンプレートを使用する。
内訳: {{TODO: テンプレートの技術スタック内訳を記入}}

## Alternatives Considered

{{TODO: 検討した他の選択肢を記入}}

- 候補 1:
- 候補 2:

## Consequences

{{TODO: メリット / デメリット / トレードオフを記入}}

### Positive
-

### Negative
-

### Neutral
-

## 関連

- project-tech-stack-decision skill: ~/ws/claude-system/adapters/claude-code/user-level/skills/project-tech-stack-decision/SKILL.md
EOF
    cs_info "Drafted ADR: $adr_dir/0001-tech-stack.md.draft (rename to .md and fill TODOs)"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
  interactive_flow
elif [[ $# -eq 2 ]]; then
  PROJECT_NAME="$1"
  TEMPLATE_NAME="$2"
else
  cs_error "Usage: tools/new-project.sh [<name> <template>|none]"
  exit 2
fi

# Validate project name (basic).
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  cs_error "Invalid project name (allowed: A-Za-z0-9_-): $PROJECT_NAME"
  exit 2
fi

PROJ_DIR="$WORKSPACE_ROOT/$PROJECT_NAME"
if [[ -e "$PROJ_DIR" ]]; then
  cs_error "$PROJ_DIR already exists. Refusing to overwrite."
  exit 2
fi

cs_step "Creating project at $PROJ_DIR (template=$TEMPLATE_NAME)"
mkdir -p "$PROJ_DIR"

if [[ "$TEMPLATE_NAME" == "none" ]] || [[ "$TEMPLATE_NAME" == "0" ]]; then
  if cs_confirm "ゼロから始めるモードで最小骨格を作成しますか?"; then
    create_zero_skeleton "$PROJ_DIR" "$PROJECT_NAME"
  else
    rmdir "$PROJ_DIR" 2>/dev/null || true
    cs_info "中止しました。"
    exit 0
  fi
else
  create_from_template "$PROJ_DIR" "$PROJECT_NAME" "$TEMPLATE_NAME"
fi

# Companion projects/ entry in claude-system (gitignored).
PROJECTS_ENTRY="$CS_ROOT/projects/$PROJECT_NAME"
mkdir -p "$PROJECTS_ENTRY"
touch "$PROJECTS_ENTRY/.gitkeep"
cs_info "Project notes dir (gitignored): $PROJECTS_ENTRY"

cs_step "Done"
cs_success "Project created: $PROJ_DIR"
cat <<EOF

Next steps:
  cd $PROJ_DIR
  git init && git add . && git commit -m "chore: initial commit"

Recommendations:
  - Fill {{TODO: ...}} placeholders in docs/adr/0001-tech-stack.md.draft,
    then rename to 0001-tech-stack.md.
  - Run \`pre-commit install\` if .pre-commit-config.yaml is present.
  - Verify integrity: $CS_ROOT/tools/doctor.sh
EOF
