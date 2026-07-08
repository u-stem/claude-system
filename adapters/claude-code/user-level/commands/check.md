---
name: check
description: コミット前の品質チェック(lint + 型 + テスト)
---

プロジェクトのコミット前品質チェックを一括実行する。lint・型チェック・テストを順に回し、すべてが通ることを確認する。

## 手順

1. プロジェクトの言語・ツールチェーンを検出する(`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod`)
2. 以下を順に実行し、各ステップの結果を報告する。設定ファイルが存在しないステップはスキップ。`bun run check` のような統合スクリプトがあればそれを優先する

### Step 1: Lint

- TypeScript / JavaScript: `bun run lint` または `bunx eslint .` または `bunx biome check`
- Python: `uv run ruff check .`
- Rust: `cargo clippy --all-targets --all-features -- -D warnings`
- Go: `go vet ./...`

### Step 2: 型チェック

- TypeScript: `bunx tsc --noEmit`
- Python: `uv run pyright` または `uv run mypy <pkg>`
- Rust: `cargo clippy` で兼用
- Go: `go vet` で兼用

### Step 3: テスト

- TypeScript / JavaScript: `bun test` または `bunx vitest run`
- Python: `uv run pytest`
- Rust: `cargo test`
- Go: `go test ./...`

## 修正ループ(エラーがあるとき)

エラーが出たら修正して再実行する。このループには収束構造を宣言してから入る([`practices/iterative-review.md`](../../../../practices/iterative-review.md) の「収束ループの一般形」の部分適用):

- **収束条件**: 全ステップ通過
- **主停止条件 = 振動・停滞の検出**: 同一エラーが 2 ラウンド連続で残った(= 進捗なし)、または修正が別の失敗を生んで元に戻った(振動)なら、ループを止めて方針転換する(原因の掘り下げ、`code-reviewer` への委譲、ユーザーへの相談)。固定ラウンド数を主条件にしない — 検査は決定論的で、エラーは正常なら単調に減る(5 個のエラーを 1 ラウンド 1 個ずつ潰すのは正常な進行)
- **ソフトな上限**: 進捗があっても 5 ラウンドに達したら一度立ち止まり、経過(ラウンド数・残エラー推移)を報告してから続行を判断する
- **停止時**: 残ったエラーを明示して止める。黙って再試行を続けない(silent retry 禁止)

なお失敗は PostToolUse hook(`log-bash-failure.sh`)が `.claude/failure-log.jsonl` に自動記録しており、繰り返しパターンは SessionStart で検出される。ループの失敗履歴を手で控える必要はない。

## 出力

各ステップの結果をまとめて報告:

- OK なら 1 行で済ませる
- エラーがあれば内容と修正案を示す
- 全 OK なら「全チェック通過」と報告

設定ファイルが存在するが実行できない場合(依存未インストール等)はその旨を明記する。

## 関連

- skill: `testing-typescript` / `testing-python`
- subagent: `code-reviewer`(エラー多数時に詳細レビューを委譲)
- practice: `~/ws/claude-system/practices/development-workflow.md`(検証なしで完了と言わない)
- practice: `~/ws/claude-system/practices/iterative-review.md`(収束ループの一般形 — 修正ループの設計元)
- ADR: `~/ws/claude-system/meta/decisions/0019-loop-engineering-phased-adoption.md`(収束構造の部分適用)
