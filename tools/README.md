# tools

セットアップ・同期・診断スクリプト群。

## 規約

- 全スクリプトは bash で書き、冒頭に `set -euo pipefail` を付与
- 冪等性を必須とする(再実行しても安全)
- macOS BSD コマンド前提(GNU 互換不要)
- 失敗時は exit 2 + stderr に明確なメッセージ
- 成功時は silent または最小限の出力

詳細は Phase 7a で構築される(`sync.sh`, `doctor.sh`, `setup.sh`, `cleanup-backups.sh` など)。
