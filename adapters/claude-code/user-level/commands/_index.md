# user-level slash commands 索引

このディレクトリには Claude Code の **user-level slash command** を配置する。
Phase 10 で `~/.claude/commands/` にシンボリックリンクされる(`adapters/claude-code/README.md` の Phase 10 リンク表参照)。

slash command は Claude Code の `/<name>` 入力で発火する短いプロンプト。skill との違い:

- **skill** は段階的開示で起動条件 / 詳細手順を持ち、起動判断は LLM が行う
- **slash command** は明示的に `/<name>` で起動、引数(`$ARGUMENTS`)を取れる単純なプロンプト

旧 `~/ws/claude-settings/commands/` の 4 件はマイグレーションインベントリで A 分類(直接取り込み)とされていたが、Phase 4 で漏れていたため Phase 6 でバックフィルした。

## 全 command 一覧

(直近の更新は `git log` を参照)

| name | description | 旧資産との対応 |
|------|-------------|----------------|
| [`check`](./check.md) | lint + 型チェック + テストを一括実行 | 旧 `commands/check.md` を継承 |
| [`review`](./review.md) | 指定ファイルの簡易コードレビュー | 旧 `commands/review.md` を継承 + `code-reviewer` subagent への委譲条件を追加 |
| [`test`](./test.md) | テストを実行して結果を報告 | 旧 `commands/test.md` を継承 |
| [`update-check`](./update-check.md) | Claude Code の最新情報を調査し、設定の更新提案を行う | 旧 `commands/update-check.md` を継承 + `research-summarizer` subagent への委譲を推奨 |
| [`review-loop`](./review-loop.md) | レビュー→修正→レビューの反復ループ(立て直し + 最終ゲート) | **新規**(`practices/iterative-review.md` の実装) |
| [`team`](./team.md) | 委譲チェーン(計画→反証→実装→レビュー→ゲート)をメイン主導で回す | **新規**([ADR 0015](~/ws/claude-system/meta/decisions/0015-delegation-chain-and-mandatory-delegation.md) の実装) |

## frontmatter 規約

```markdown
  ---
  name        : <command-name>            # ファイル名(拡張子除く)と一致
  description : <50 字以内、改行禁止>      # /command help などで表示される
  ---
```

(上は例示のためインデント、実 command ファイルは行頭空白なし)

`recommended_model` / `tools` / `model` フィールドは slash command には不要(skill / subagent と異なる仕様)。
引数を取る場合は本文中で `$ARGUMENTS` を参照。

## command 責務の使い分け

### `/check` vs `/test`

| コマンド | 用途 | タイミング |
|---------|------|-----------|
| **`/check`** | lint + 型チェック + テストを一括実行 | コミット前の最終品質ゲート |
| **`/test`** | テストのみを即時実行 | TDD の赤・緑サイクルで頻用 |

`/test` は軽量で即座に実行でき、TDD ワークフローに適している。コミット直前に全項目を確認したいなら `/check` を使う。

## skill / subagent との使い分け

| 使い方 | 推奨 |
|--------|------|
| 「lint・型・test を回したい」(明示的・即時) | slash command `/check` |
| 「コードを書く方針を確認したい」(段階的開示) | skill(LLM が起動判断) |
| 「PR を別コンテキストで深掘りレビュー」(委譲、差分 100 行超 or 5 ファイル超) | subagent `code-reviewer` |
| 「変更コードに doc を追従させたい」(別コンテキストで適用) | subagent `doc-writer` |

## 自己検証

```bash
# frontmatter 必須フィールド
for cmd in adapters/claude-code/user-level/commands/*.md; do
  base=$(basename "$cmd")
  [ "$base" = "_index.md" ] && continue
  for field in name description; do
    head -10 "$cmd" | grep -q "^$field:" || echo "MISSING $field: $cmd"
  done
done

# description 50 字以内
for cmd in adapters/claude-code/user-level/commands/*.md; do
  base=$(basename "$cmd")
  [ "$base" = "_index.md" ] && continue
  desc=$(head -10 "$cmd" | grep "^description:" | sed 's/^description: //')
  chars=$(echo -n "$desc" | wc -m)
  [ "$chars" -gt 50 ] && echo "OVER ($chars): $cmd"
done

# ファイル名と name フィールド一致
for cmd in adapters/claude-code/user-level/commands/*.md; do
  base=$(basename "$cmd" .md)
  [ "$base" = "_index" ] && continue
  name_field=$(head -10 "$cmd" | grep "^name:" | cut -d: -f2 | tr -d ' ')
  [ "$base" != "$name_field" ] && echo "MISMATCH: file=$base vs name=$name_field"
done
```

## 関連

- [`adapters/claude-code/user-level/skills/_index.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/_index.md)
- [`adapters/claude-code/subagents/_index.md`](~/ws/claude-system/adapters/claude-code/subagents/_index.md)
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — Phase 10 で `~/.claude/commands/` にリンク
