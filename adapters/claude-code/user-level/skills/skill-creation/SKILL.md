---
name: skill-creation
description: 新しい skill を設計・作成する(メタ skill)
recommended_model: sonnet
---

# Skill Creation

新しい skill を `~/ws/claude-system/adapters/claude-code/user-level/skills/<name>/` 配下に作成するための meta skill。
設計指針は [`practices/skill-design-guide.md`](~/ws/claude-system/practices/skill-design-guide.md)、根拠原則は [`principles/03-skill-composition.md`](~/ws/claude-system/principles/03-skill-composition.md) と [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md)。

## 目的

新規 skill を一貫した構成で作成し、既存 skill 群との整合(命名 / 粒度 / 段階的開示 / クロスリファレンス)を担保する。

## いつ発動するか

- 同じ作業パターンが 3 回現れて共通化を検討するとき
- 既存 skill が肥大化して責務が複数になっていることに気付いたとき
- プロジェクト固有の能力が共通層に置かれていることに気付いたとき
- 新しい外部ツール / フレームワーク採用に伴い専用作法が必要なとき

## 手順

### 1. 必要性の判断

- 同じ作業パターンが**3 回**現れたか?(`principles/03-skill-composition.md`)
- 1 回や 2 回での先回り抽象化は**しない**(誤った抽象が固定化する)
- 既存 skill の章追加で済むなら新規作成しない

### 2. 命名

- **動詞ベース**(「ADR を書く」「依存をレビューする」「テストを設計する」)
- プロジェクト名・サービス名・対象固有名詞を冠さない(再利用先が固定される)
- ハイフン区切り英小文字、ファイル名は `<name>/SKILL.md`
- 既存 skill の `_index.md` で重複していないか確認

### 3. ディレクトリ構造

```
adapters/claude-code/user-level/skills/<name>/
├── SKILL.md           本体(200 行以内)
└── references/        詳細を分割する場合のみ作成
    └── <topic>.md
```

`SKILL.md` は段階的開示の入口とし、200 行を超えそうなら `references/` 配下に詳細を切り出す。

### 4. frontmatter

```markdown
  ---
  name              : <skill-name>              # ディレクトリ名と一致
  description       : <一行の起動条件説明>      # 50 字以内、改行禁止
  recommended_model : opus | sonnet | haiku
  ---
```

(上記は例示のため各行に 2 スペースのインデントを加えてある。実際の SKILL.md では行頭に空白を入れず、`name:` `description:` `recommended_model:` をそのまま書く)

`recommended_model` は [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) の判断基準で決める:

- `opus`: アーキテクチャ / セキュリティ / 原子性が問われる(`adr-writing` / `nextjs-supabase-rls` / `security-audit`)
- `sonnet`: 一般的な実装・レビュー・ドキュメント(多数派)
- `haiku`: 単純な取得・整形・列挙(該当 skill は現状少ない)

### 5. 本文の標準セクション

```markdown
# (Skill タイトル)

## 目的
## いつ発動するか
## 手順
## チェックリスト
## アンチパターン(任意)
## 関連
```

- **目的**: 1 文で何を達成するか
- **いつ発動するか**: トリガーを箇条書き(description で要約しきれない条件)
- **手順**: 番号付きステップ。各ステップは 1 動作
- **チェックリスト**: 完了判定に使えるチェックボックス
- **関連**: 他 skill / practice / principle / ADR への参照

### 6. クロスリファレンス

- 他層への参照は**絶対パス** `~/ws/claude-system/<layer>/<file>` 形式([`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) のパス規約参照)
- 同 skill 内の references/ は相対(`./references/foo.md`)
- 関連 skill / subagent には双方向リンクを張る(片方からだけだと辿れない)

### 7. `_index.md` の更新

- `~/ws/claude-system/adapters/claude-code/user-level/skills/_index.md` に新 skill 行を追加
- 既存の Tier 分類 / カテゴリ分類に従う

### 8. 自己検証

```bash
# frontmatter フィールド存在
head -10 SKILL.md | grep -E '^(name|description|recommended_model):'

# ディレクトリ名と name 一致
test "$(basename $(dirname SKILL.md))" = "$(grep '^name:' SKILL.md | cut -d: -f2 | tr -d ' ')"

# 行数(200 超なら references/ への分割を検討)
wc -l SKILL.md
```

### 9. コミット

```bash
git add adapters/claude-code/user-level/skills/<name>/ adapters/claude-code/user-level/skills/_index.md
git commit -m "feat(skills): add <name> skill"
```

## チェックリスト

- [ ] 同じ作業パターンが 3 回出現してから作成している(先回りでない)
- [ ] 命名が動詞ベース、プロジェクト名を冠していない
- [ ] frontmatter の `name` がディレクトリ名と一致
- [ ] `description` が 50 字以内・改行なし・起動条件を 1 行で表現
- [ ] `recommended_model` がタスク複雑度に整合
- [ ] 本文に「目的 / いつ発動するか / 手順 / チェックリスト / 関連」を含む
- [ ] 200 行以内(超えるなら `references/` に分割)
- [ ] クロスリファレンスが絶対パス `~/ws/claude-system/...` 形式
- [ ] `_index.md` に新 skill 行を追加
- [ ] frontmatter / 一致 / 行数の自己検証 pass
- [ ] 関連 principle / practice への参照を貼った

## アンチパターン

- 1 回出現でいきなり skill 化する(誤った抽象が固定化)
- 引数フラグで複数機能を切り替える 1 つの skill にまとめる(責務肥大)
- プロジェクト名 / サービス名で命名(再利用先が固定)
- frontmatter の `name` とディレクトリ名がずれる
- 200 行を超えても `references/` に分割せず 1 ファイルで肥大化させる
- 他層への参照を相対パスで深く書く(階層変更で壊れる、規約違反)
- `_index.md` 更新を忘れる

## 関連

- [`practices/skill-design-guide.md`](~/ws/claude-system/practices/skill-design-guide.md) — 能力単位の設計手順
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — `recommended_model` の判断基準
- [`principles/03-skill-composition.md`](~/ws/claude-system/principles/03-skill-composition.md) — 能力単位の合成と再利用
- [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md) — 段階的開示
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — クロスレイヤー参照のパス規約
