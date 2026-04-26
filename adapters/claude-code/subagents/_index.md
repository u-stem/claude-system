# subagents 索引(プレースホルダ)

このディレクトリには Claude Code の **subagent**(補助エージェント)定義を配置する。
本体定義は **Phase 5** で作成される。本ファイルは Phase 3 時点のプレースホルダ。

## 配置場所と役割

- 配置先: `~/ws/claude-system/adapters/claude-code/subagents/<name>.md`
- Phase 10 で `~/.claude/agents/` にシンボリックリンクされる
- subagent は独立コンテキストを持つ専門タスク実行単位(`principles/01-context-economy.md` の委譲基準を参照)

## Phase 5 で作成予定の subagent(旧資産から取り込み)

旧資産棚卸し([`meta/migration-inventory.md`](../../../meta/migration-inventory.md))の `agents/` 行を参照。すべて分類「A: そのまま取り込み」。

| name | 役割 | tools(最小権限の指針) |
|------|------|------------------------|
| `code-reviewer` | コミット前のコードレビュー(セキュリティ・AI 生成コード検証・誤魔化し検出含む) | Read, Grep, 読み取り系 Bash のみ |
| `doc-writer` | コード変更に伴う doc 更新提案 | Read, Write(docs 配下), Grep |
| `explorer` | コードベース探索(必要最小限のファイルのみ読む) | Read, Grep, Glob |
| `refactor-planner` | リファクタリング計画立案(実装はしない) | Read, Grep |
| `security-reviewer` | セキュリティ特化レビュー | Read, Grep, Bash(npm audit 等) |
| `test-runner` | テスト実行と結果要約 | Bash(test runner), Read |

## frontmatter 形式

```markdown
---
name: <subagent-name>            # ファイル名(拡張子除く)と一致させる
description: いつこの subagent を呼ぶべきか
tools: [必要最小限のツールのみ列挙]
---
```

## v3 で追加する規約

- `tools` フィールドで**最小権限原則**を徹底する(Phase 5 の自己検証で目視確認)
- 親エージェントへの**返却フォーマット**を本文に明記する(特に `code-reviewer` は重大度別件数 + 指摘リスト形式)
- 1 ファイル 100〜300 行に収める

## 関連

- [`principles/01-context-economy.md`](../../../principles/01-context-economy.md) — 委譲の選択基準
- [`principles/05-separation-of-concerns.md`](../../../principles/05-separation-of-concerns.md) — 最小権限と境界
- [`practices/model-selection.md`](../../../practices/model-selection.md) — subagent ごとのモデル水準
- [`adapters/claude-code/README.md`](../README.md)
