# user-level hooks(プレースホルダ)

このディレクトリには Claude Code のグローバル hook 用シェルスクリプトを配置する。
本体実装は **Phase 7b**(Guardrails 層)で行う。本ファイルは Phase 3 時点のプレースホルダ。

## 配置場所と役割

- 配置先: `~/ws/claude-system/adapters/claude-code/user-level/hooks/<name>.sh`
- Phase 10 で `~/.claude/hooks/` にシンボリックリンクされる
- 実行可能ビット(`chmod +x`)を必ず付ける
- 全スクリプトは `#!/usr/bin/env bash` + `set -euo pipefail` を必須とする(`CLAUDE.md` 絶対ルール)

## Phase 7b で実装予定の hook

詳細は [`meta/TODO-for-phase-7b.md`](../../../../meta/TODO-for-phase-7b.md) を参照。以下は概要:

### 必ず取り込む高価値資産(旧資産棚卸しで「A: そのまま取り込み」分類)

| ファイル | hook 種別 | 役割 |
|---------|-----------|------|
| `check-package-age.sh` | PreToolUse(Bash) | typosquatting / 侵害バージョン防御。`PACKAGE_MIN_AGE_DAYS`(既定 7)以内のパッケージを deny |
| `check-failure-patterns.sh` | SessionStart | `failure-log.jsonl` から繰り返し失敗を検出して通知(自己参照ループの起点) |
| `log-bash-failure.sh` | PostToolUse(Bash) | 終了コード ≠ 0 を category(test/check-types/check)判定して `log-failure.sh` に渡す |
| `log-failure.sh` | (補助) | `.claude/failure-log.jsonl` への JSONL 追記 |
| `filter-test-output.sh` | PreToolUse(Bash) | テストコマンドを `tail -150` でラップしてコンテキスト圧縮 |
| `require-review-before-commit.sh` | PreToolUse(Bash) | `REQUIRE_REVIEW_BEFORE_COMMIT=1` 時のみ動作する opt-in ゲート |

### 新規追加検討

- ADR 0001(個人特定情報)/ ADR 0002(Public/Private 境界)を機械検出する hook(`gitleaks` の custom rule または別 lint と相乗り)
- `--no-verify` / 破壊的 git コマンドの検出(現行 settings.json テンプレートで PreToolUse(Bash) のインライン jq として枠を確保済み)

### post-edit / post-stop dispatcher パターン

- グローバル hook は `if [ -x .claude/hooks/post-edit.sh ]; then .claude/hooks/post-edit.sh; fi` の形式で**プロジェクト側スクリプトに委譲**する
- 言語固有処理(biome / tsc / ruff / mypy / cargo clippy / go vet 等)は `adapters/claude-code/project-templates/`(Phase 6)に配置

## 設計指針

- 成功時は **silent**、失敗時は **stderr に出力 + exit 2**
- 失敗ログは `${CLAUDE_PROJECT_DIR:-.}/.claude/failure-log.jsonl` に集約しプロジェクト内に閉じる
- macOS BSD コマンド前提(GNU 互換不要、ただし bash は Homebrew 5.x を許容)
- 冪等であること(同じ入力で何度呼んでも同じ結果)

## 関連

- [`meta/TODO-for-phase-7b.md`](../../../../meta/TODO-for-phase-7b.md) — 取り込み対象の詳細
- [`adapters/claude-code/user-level/settings.json.template`](../settings.json.template) — hook の結線箇所
- [`adapters/claude-code/README.md`](../../README.md)
