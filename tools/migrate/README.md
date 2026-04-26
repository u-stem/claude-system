# tools/migrate/

Claude Code のバージョン更新時に必要となる移行スクリプトの置き場。

## 命名規則

`from-vA.B-to-vC.D.sh` の形式で配置する。例:

- `from-v2.1-to-v2.2.sh`
- `from-v2.x-to-v3.0.sh`

## いつ作るか

`tools/check-claude-version.sh` で installed > pinned が検出され、かつ以下のいずれかに該当するとき:

- `settings.json` の `permissions` / `hooks` 構文に破壊的変更がある
- skill / subagent / command の frontmatter 仕様が変わった
- `~/.claude/` のディレクトリ構造が変わった
- 利用している MCP サーバー / プラグインの API が変わった

## スクリプトの規約

- shebang: `#!/usr/bin/env bash`
- `set -euo pipefail`
- `tools/_lib.sh` を source して共通ユーティリティを利用
- 冪等(再実行しても安全)
- `--dry-run` オプションを必ず実装
- 破壊的操作の前に `~/.claude-system-backups/` へバックアップ
- 完了後に `tools/doctor.sh` を呼んで整合性を確認
- 移行内容を `meta/CHANGELOG.md` に追記

## 関連

- [`adapters/claude-code/README.md`](../../adapters/claude-code/README.md) — 「移行プレイブック」セクション
- [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) — 現行 pinned バージョン
- [`tools/check-claude-version.sh`](../check-claude-version.sh) — 差分検出
