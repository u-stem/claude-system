---
name: check
description: lint + 型チェック + テストを一括実行
---

プロジェクトの品質チェックを一括実行する。

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
