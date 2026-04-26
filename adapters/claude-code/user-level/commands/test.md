---
name: test
description: テストを実行して結果を報告
---

テストを実行する。

## 手順

1. プロジェクトの言語 / フレームワークを検出
2. 適切なテストコマンドを実行
3. 失敗したテストがあれば原因を分析
4. 修正案を提示(実行はしない、提案のみ)

## テストコマンド例

- TypeScript / JavaScript: `bun test` / `bunx vitest run` / `bunx jest`
- Python: `uv run pytest`
- Rust: `cargo test`
- Go: `go test ./...`

統合スクリプト(`bun run test` 等)があればそれを優先する。

## 出力

```
## テスト結果
- pass: <n>
- fail: <n>
- skip: <n>

### 失敗したテスト
1. <test-name> (<file:line>)
   - エラー: <message>
   - 推測される原因: <analysis>
   - 修正案: <suggestion>(実行はしない)
```

## 関連

- skill: `testing-typescript` / `testing-python`(TDD 設計)
- practice: `~/ws/claude-system/practices/testing-strategy.md`
- Phase 7b の post-edit / post-stop hook が将来は自動でテスト実行する
