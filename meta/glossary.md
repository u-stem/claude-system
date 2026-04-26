# 用語集

このリポジトリで用いる用語の定義。各 Phase で更新される。

## 層

- **principles** — ツール非依存の根本原則。最も抽象度が高い
- **practice** — principles を踏まえた抽象的な実践パターン
- **adapter** — 特定 AI 開発ツール向けに principles/practices を具体化したもの
- **fragment** — 既存プロジェクトの設定ファイルに追記される断片
- **template** — 新規プロジェクト用のひな形

## 抽象構成要素(principles / practices で使う層非依存の語)

- **能力単位** — 特定タスクを支援する単一責務の抽象単位。適応層では `skill` として実体化される
- **補助エージェント** — 専門タスクを担う独立コンテキストの実行単位の抽象。適応層では `subagent` として実体化される
- **意思決定記録** — 後から経緯を辿りたくなる判断の保存。`meta/decisions/` 配下の連番ファイル(ADR)として運用される
- **設定階層 / 不変層 / 適応層** — 層構造の運用語。各層の役割は本表「層」セクションを参照

## Claude Code 関連(adapters/claude-code/ 配下でのみ使用)

- **skill** — 段階的開示で読み込まれる、特定タスクを支援する定義(能力単位の実体)
- **subagent** — 専門タスクを担う独立コンテキストのエージェント(補助エージェントの実体)
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
