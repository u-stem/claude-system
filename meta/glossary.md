# 用語集

このリポジトリで用いる用語の定義。各 Phase で更新される。

## 層

- **principles** — ツール非依存の根本原則。最も抽象度が高い
- **practice** — principles を踏まえた抽象的な実践パターン
- **adapter** — 特定 AI 開発ツール向けに principles/practices を具体化したもの
- **fragment** — 既存プロジェクトの CLAUDE.md に追記される断片
- **template** — 新規プロジェクト用のひな形

## Claude Code 関連 (adapters/claude-code/ 配下でのみ使用)

- **skill** — 段階的開示で読み込まれる、特定タスクを支援する定義
- **subagent** — 専門タスクを担う独立コンテキストのエージェント
- **hook** — ツール実行前後やイベント発生時に呼ばれるシェルスクリプト
- **guardrail** — hooks / CI / permissions による機械的防御の総称

## 運用

- **bootstrap** — 新環境にこのシステムを展開する初期化処理
- **adopt** — 既存プロジェクトを claude-system に取り込むこと
- **fragment 配信** — projects/ 経由で各プロジェクトに断片を渡すこと
- **idempotent (冪等)** — 同じ操作を何度実行しても結果が同じであること

## バージョニング

- SemVer に従う
- **MAJOR** — principles 層の破壊的変更
- **MINOR** — skill / subagent / practice の追加
- **PATCH** — 修正、調整
