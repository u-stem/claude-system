# user-level skills 索引

このディレクトリには Claude Code の **user-level skills** を配置する。
Phase 10 で `~/.claude/skills/` にシンボリックリンクされる。

skill は段階的開示で読み込まれる「能力単位」(根拠は [`principles/03-skill-composition.md`](~/ws/claude-system/principles/03-skill-composition.md) と [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md))。

## 全 skill 一覧(2026-04-26 時点)

### Tier 1: 必ず採用

| name | description | recommended_model | 旧資産との対応 |
|------|-------------|-------------------|----------------|
| [`adr-writing`](./adr-writing/SKILL.md) | ADR(意思決定記録)を起票・更新する | opus | 新規(`practices/adr-workflow.md` から派生) |
| [`commit-conventional`](./commit-conventional/SKILL.md) | Conventional Commits 規約に従ってコミットを切る | sonnet | 新規(旧資産の Git 章を抽象化した `practices/commit-conventions.md` から派生) |
| [`nextjs-supabase-base`](./nextjs-supabase-base/SKILL.md) | Next.js + Supabase の基本作法に従って実装する | sonnet | 新規(主要スタック向け) |
| [`typescript-strict`](./typescript-strict/SKILL.md) | TypeScript strict モード作法と型安全な実装パターン | sonnet | 旧 `rules/code-style.md` の TS 部分を昇華・拡張(言語別 style skill としても兼任) |

### Tier 2: 通常採用

| name | description | recommended_model | 旧資産との対応 |
|------|-------------|-------------------|----------------|
| [`nextjs-supabase-rls`](./nextjs-supabase-rls/SKILL.md) | Supabase RLS ポリシーを設計・レビューする | opus | 新規(セキュリティ系・原子性問われるため上位モデル) |
| [`security-audit`](./security-audit/SKILL.md) | 実装変更や依存追加に対するセキュリティ観点のレビュー | opus | 旧 `rules/security.md` を昇華・skill 化 |
| [`japanese-tech-writing`](./japanese-tech-writing/SKILL.md) | 日本語の技術文書を書く(README / ADR / docs) | sonnet | 新規(`practices/coding-style-conventions.md` の過剰装飾禁止と整合) |

### Tier 3: 必要時採用

| name | description | recommended_model | 旧資産との対応 |
|------|-------------|-------------------|----------------|
| [`dependency-review`](./dependency-review/SKILL.md) | 依存パッケージの追加・更新時のレビュー | sonnet | 旧 `rules/security.md` 依存関係章 + Phase 7b の `check-package-age.sh` と連動 |
| [`pr-description`](./pr-description/SKILL.md) | Pull Request の本文(Summary / Test plan)を書く | sonnet | 新規(旧 `skills/pr-review` のレビュー側に対する作成側) |
| [`skill-creation`](./skill-creation/SKILL.md) | 新しい skill を設計・作成する(メタ skill) | sonnet | 新規(`practices/skill-design-guide.md` の手順を skill 化) |

### 言語別 style skill(`practices/coding-style-conventions.md` 言語別具体化、TODO-for-phase-4 由来)

| name | description | recommended_model | 状態 | 旧資産との対応 |
|------|-------------|-------------------|------|----------------|
| (`typescript-strict` が兼任) | — | — | 完成 | TypeScript は Tier 1 の `typescript-strict` が strict モード + 構文の両方をカバー |
| [`python-style`](./python-style/SKILL.md) | Python の構文・整形・型ヒント運用 | sonnet | 完成 | 旧 `CLAUDE.md` 言語別スタイル Python 章 + `rules/code-style.md` |
| [`rust-style`](./rust-style/SKILL.md) | Rust の所有権・エラー・clippy 規約 | sonnet | **skeleton** | 旧 `CLAUDE.md` 言語別スタイル Rust 章(主要スタックではないため最小骨子) |
| [`go-style`](./go-style/SKILL.md) | Go の整形・エラー処理・インターフェース規約 | sonnet | **skeleton** | 旧 `CLAUDE.md` 言語別スタイル Go 章(主要スタックではないため最小骨子) |

### 言語別 testing skill(`practices/testing-strategy.md` 言語別具体化、TODO-for-phase-4 由来)

| name | description | recommended_model | 状態 | 旧資産との対応 |
|------|-------------|-------------------|------|----------------|
| [`testing-typescript`](./testing-typescript/SKILL.md) | TypeScript のテスト戦略(Vitest / Bun test / Jest) | sonnet | 完成 | 旧 `skills/tdd` + `rules/testing.md` を TS 具体化 |
| [`testing-python`](./testing-python/SKILL.md) | Python のテスト戦略(pytest) | sonnet | 完成 | 旧 `skills/tdd` + `rules/testing.md` を Python 具体化 |
| testing-rust(未作成) | — | — | **未着手** | 主要スタックではないため Phase 4 では着手せず。必要時に `skill-creation` 手順で追加 |
| testing-go(未作成) | — | — | **未着手** | 同上 |

## frontmatter 規約

```markdown
  ---
  name              : <skill-name>             # ディレクトリ名と一致
  description       : <一行の起動条件>          # 50 字以内、改行禁止
  recommended_model : opus | sonnet | haiku    # practices/model-selection.md の判断基準
  ---
```

(上は例示のためインデントしてある。実際の SKILL.md は行頭空白なし)

旧資産で使われていた `paths:` frontmatter(Glob ベースの自動マッチング)は、現行 Claude Code 2.1.x の skill 仕様では採用しない方針(skill は description ベースで起動判断される)。`paths:` が必要な「特定拡張子のファイル編集時のみ強制したいルール」は、Phase 7b の post-edit hook(プロジェクト側)で扱う。

## クロスレイヤー参照

skill から他層を参照するときは**絶対パス** `~/ws/claude-system/<layer>/<file>` 形式を使用する。
判断の根拠は [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) の「クロスレイヤー参照のパス規約」セクション参照。

## 自己検証

新規 skill 追加時、以下を通すこと:

```bash
# frontmatter 必須フィールド
for skill in adapters/claude-code/user-level/skills/*/SKILL.md; do
  for field in name description recommended_model; do
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
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — `recommended_model` 判断基準
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — Adapter 全体、パス規約
- [`adapters/claude-code/user-level/skills/skill-creation/SKILL.md`](./skill-creation/SKILL.md) — 新規 skill 作成手順
