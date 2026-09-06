# user-level skills 索引

このディレクトリには Claude Code の **user-level skills** を配置する。
`~/.claude/skills/` にシンボリックリンクされている。

skill は段階的開示で読み込まれる「能力単位」(根拠は [`principles/03-skill-composition.md`](~/ws/claude-system/principles/03-skill-composition.md) と [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md))。

## 全 skill 一覧

(直近の更新は `git log` を参照)

### Tier 1: 必ず採用

| name | description | 旧資産との対応 |
|------|-------------|----------------|
| [`adr-writing`](./adr-writing/SKILL.md) | ADR(意思決定記録)を起票・更新する | 新規(`practices/adr-workflow.md` から派生) |
| [`commit-conventional`](./commit-conventional/SKILL.md) | Conventional Commits 規約に従ってコミットを切る | 新規(旧資産の Git 章を抽象化した `practices/commit-conventions.md` から派生) |
| [`nextjs-supabase-base`](./nextjs-supabase-base/SKILL.md) | Next.js + Supabase の基本作法に従って実装する | 新規(主要スタック向け) |
| [`typescript-strict`](./typescript-strict/SKILL.md) | TypeScript strict モード作法と型安全な実装パターン | 旧 `rules/code-style.md` の TS 部分を昇華・拡張(言語別 style skill としても兼任) |

### Tier 2: 通常採用

| name | description | 旧資産との対応 |
|------|-------------|----------------|
| [`nextjs-supabase-rls`](./nextjs-supabase-rls/SKILL.md) | Supabase RLS ポリシーを設計・レビューする | 新規(セキュリティ系・原子性問われるため上位モデル運用を想定) |
| [`japanese-tech-writing`](./japanese-tech-writing/SKILL.md) | 日本語の技術文書を書く(README / ADR / docs) | 新規(`practices/coding-style-conventions.md` の過剰装飾禁止と整合) |

### Tier 3: 必要時採用

| name | description | 旧資産との対応 |
|------|-------------|----------------|
| [`dependency-review`](./dependency-review/SKILL.md) | 依存パッケージの追加・更新時のレビュー | 旧 `rules/security.md` 依存関係章 + `check-package-age.sh` と連動 |
| [`pr-description`](./pr-description/SKILL.md) | Pull Request の本文(Summary / Test plan)を書く | 新規(旧 `skills/pr-review` のレビュー側に対する作成側) |

### プロジェクト立ち上げ

| name | description | 旧資産との対応 |
|------|-------------|----------------|
| [`project-tech-stack-decision`](./project-tech-stack-decision/SKILL.md) | 新規プロジェクトの技術スタックを選定する | 新規(`practices/project-bootstrap.md` のステップ前段を skill 化、テンプレート選択の形骸化を防ぐ) |

連動 skill: [`adr-writing`](./adr-writing/SKILL.md)(選定理由の ADR 化で連携)。
連動 tool: [`~/ws/claude-system/tools/new-project.sh`](~/ws/claude-system/tools/new-project.sh)(本 skill 通過後の初期化を担う)。

### 言語別 testing skill(`practices/testing-strategy.md` 言語別具体化)

| name | description | 状態 | 旧資産との対応 |
|------|-------------|------|----------------|
| [`testing-typescript`](./testing-typescript/SKILL.md) | TypeScript のテスト戦略(Vitest / Bun test / Jest) | 完成 | 旧 `skills/tdd` + `rules/testing.md` を TS 具体化 |

主要スタック外の言語(Python / Rust / Go)向け skill は現状未採用。必要になったら [`tools/new-skill.sh`](~/ws/claude-system/tools/new-skill.sh) でスキャフォールドを作成する。

## frontmatter 規約

```markdown
  ---
  name        : <skill-name>             # ディレクトリ名と一致
  description : <一行の起動条件>          # 50 字以内、改行禁止
  ---
```

(上は例示のためインデントしてある。実際の SKILL.md は行頭空白なし)

必須フィールドは `name` / `description` の 2 つのみ。モデル選択は `adapters/claude-code/subagents/` の `model` フィールド運用と異なり、skill は起動されたセッションのモデルをそのまま使うため frontmatter に持たない。

旧資産で使われていた `paths:` frontmatter(Glob ベースの自動マッチング)は、現行 Claude Code 2.1.x の skill 仕様では採用しない方針(skill は description ベースで起動判断される)。`paths:` が必要な「特定拡張子のファイル編集時のみ強制したいルール」は、プロジェクト側の post-edit hook で扱う。

## クロスレイヤー参照

skill から他層を参照するときは**絶対パス** `~/ws/claude-system/<layer>/<file>` 形式を使用する。
判断の根拠は [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) の「クロスレイヤー参照のパス規約」セクション参照。

## 自己検証

新規 skill 追加時、以下を通すこと:

```bash
# frontmatter 必須フィールド
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  for field in name description; do
    head -10 "$skill" | grep -q "^$field:" || echo "MISSING $field: $skill"
  done
done

# ディレクトリ名と name 一致
for skill_dir in adapters/claude-code/user-level/skills/*/; do
  dir_name=$(basename "$skill_dir")
  name_field=$(head -10 "$skill_dir/SKILL.md" | grep "^name:" | cut -d: -f2 | tr -d ' ')
  [ "$dir_name" != "$name_field" ] && echo "MISMATCH: dir=$dir_name name=$name_field"
done

# description 50 字以内
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  desc=$(head -10 "$skill" | grep "^description:" | sed 's/^description: //')
  chars=$(echo -n "$desc" | wc -m)
  [ "$chars" -gt 50 ] && echo "OVER ($chars): $skill"
done

# 行数 200 超なら references/ 検討
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  lines=$(wc -l < "$skill")
  [ "$lines" -gt 200 ] && echo "WARN $skill is $lines lines, split to references/"
done
```

## 関連

- [`principles/03-skill-composition.md`](~/ws/claude-system/principles/03-skill-composition.md) — 能力の合成と再利用
- [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md) — 段階的開示
- [`practices/skill-design-guide.md`](~/ws/claude-system/practices/skill-design-guide.md) — 能力単位の切り方
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — モデル選択の判断基準(subagent の `model` フィールドに反映)
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — Adapter 全体、パス規約
- [`~/ws/claude-system/tools/new-skill.sh`](~/ws/claude-system/tools/new-skill.sh) — 新規 skill のスキャフォールド作成
