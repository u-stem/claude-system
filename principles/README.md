# principles

このシステムの**根本原則**を定義する層。
特定 AI 開発ツールに依存しない普遍的な原則だけを記述する。

ここに書かれた原則は他の全層 (practices, adapters, projects) の前提となる。

## 制約

- 特定 AI 開発ツールのプロダクト名、特定の文書ファイル名、特定の概念名、特定のパス・設定ファイル名、特定の入力プレフィックスは出してはならない(機械検出される)
- 抽象度は最高。具体的な手順や設定値は practices 以下に書く
- 変更は MAJOR バージョンアップとして扱う
- 機械検出される具体的な禁止語リストは `../meta/forbidden-words.txt` に保管される

## 構成

| ファイル | テーマ |
|----------|--------|
| `00-meta.md` | 本層自体の編集規約 |
| `01-context-economy.md` | コンテキスト経済の原則 |
| `02-decision-recording.md` | 意思決定の保存 |
| `03-skill-composition.md` | 能力の合成と再利用 |
| `04-progressive-disclosure.md` | 段階的開示 |
| `05-separation-of-concerns.md` | 関心の分離 |
| `06-evolution-strategy.md` | 変化への適応戦略 |

## 共通フォーマット

各原則ファイルは以下のセクションを必ず備える:

- 公理
- 帰結
- 運用への落とし込み
- アンチパターン
- 関連する practices
- 旧資産からの継承
