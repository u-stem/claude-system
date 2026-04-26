# tools

セットアップ・同期・診断・プロジェクトライフサイクル管理スクリプト群。

## 規約

- 全スクリプトは bash で書き、冒頭に `set -euo pipefail` を付与
- 冪等性を必須とする(再実行しても安全)
- macOS BSD コマンド前提(GNU 互換不要)
- `tools/_lib.sh` を source して共通ヘルパー(色付き出力 / ロック / バックアップパス / 対話ヘルパー)を利用
- すべて `--help` オプションで使い方を表示
- 失敗時は exit 非 0 + stderr に明確なメッセージ
- 成功時は silent または最小限の出力(`cs_success`)

## スクリプト一覧

| script | 用途 | 冪等 | ロック |
|--------|------|------|--------|
| [`_lib.sh`](./_lib.sh) | 共通ライブラリ(source 専用) | — | — |
| [`sync.sh`](./sync.sh) | `~/.claude/` シンボリックリンク配布(Phase 0-9 は `--dry-run` のみ) | ◯ | sync |
| [`doctor.sh`](./doctor.sh) | リポジトリ整合性チェック(skill / subagent / command frontmatter / 禁止語 / shellcheck / gitleaks / ADR draft) | ◯ | — |
| [`setup.sh`](./setup.sh) | 新環境セットアップ(前提ツール検出 / バックアップディレクトリ作成 / doctor.sh 実行) | ◯ | — |
| [`new-project.sh`](./new-project.sh) | 新規プロジェクト立ち上げ(対話 / 引数 / ゼロから始めるモード) | ◯(既存ディレクトリは拒否) | — |
| [`adopt-project.sh`](./adopt-project.sh) | 既存プロジェクトを claude-system 管理下に取り込み(対話、CLAUDE.md バックアップ) | ◯ | — |
| [`unadopt-project.sh`](./unadopt-project.sh) | 取り込み撤回(バックアップから CLAUDE.md 復元) | ◯ | — |
| [`restore-project.sh`](./restore-project.sh) | 任意のバックアップから CLAUDE.md を復元 | ◯ | — |
| [`new-skill.sh`](./new-skill.sh) | 新規 skill のスキャフォールド作成 | ◯(既存名は拒否) | — |
| [`new-adr.sh`](./new-adr.sh) | プロジェクト内 `docs/adr/` に新 ADR を起票(自動連番) | ◯ | — |
| [`cleanup-backups.sh`](./cleanup-backups.sh) | `~/.claude-system-backups/` の古いファイルを削除(デフォルト 30 日) | ◯ | — |
| [`check-claude-version.sh`](./check-claude-version.sh) | インストール済み Claude Code と `adapters/.../VERSION` の差分を表示 | ◯ | — |
| [`setup-mcp.sh`](./setup-mcp.sh) | `adapters/.../mcp/servers.template.json` を読んで MCP を登録(secret 必須は skip) | ◯ | — |
| [`cleanup-claude-code-runtime.sh`](./cleanup-claude-code-runtime.sh) | `~/.claude/` のランタイム生成物(projects/ telemetry/ history.jsonl 等)を削除。**手動実行のみ** | ◯ | — |

## 検証スクリプト(別ディレクトリ)

`doctor.sh` から呼ばれる細粒度のリント:

| script | 用途 |
|--------|------|
| [`../tests/lint-skills.sh`](../tests/lint-skills.sh) | skill の構造チェック(frontmatter / セクション / dir-name 一致) |
| [`../tests/lint-principles-language.sh`](../tests/lint-principles-language.sh) | principles / practices への禁止語混入検出 |
| [`../tests/check-circular-refs.sh`](../tests/check-circular-refs.sh) | `@<file>` 参照の循環検出 |
| [`../tests/validate-frontmatter.sh`](../tests/validate-frontmatter.sh) | YAML frontmatter の構文検証 |

## サブディレクトリ

| dir | 用途 |
|-----|------|
| [`migrate/`](./migrate/) | Claude Code のバージョン更新に伴う移行スクリプト置き場(命名: `from-vA.B-to-vC.D.sh`) |

## 重要な制約

- **`sync.sh` の実行**: Phase 0-9 では `--dry-run` のみ。`--force` は `CLAUDE_SYSTEM_ALLOW_SYNC=1` を要求するセーフガード付き。Phase 10 で初めて実切替する
- **`cleanup-claude-code-runtime.sh` の実行頻度**: 手動実行のみ(SessionStart hook や定期実行には組み込まない、Phase 7a 設計判断 A1)
- **`setup.sh` の chezmoi 連携**: 検出のみ(Phase 7a 設計判断 A2)。chezmoi との深い連携は将来検討
- **`new-project.sh` の skill 連携**: `project-tech-stack-decision` skill の起動はユーザに案内するメッセージで促す(スクリプトから skill を直接起動はできない、Phase 7a 設計判断 A3)

## 関連

- [`adapters/claude-code/README.md`](../adapters/claude-code/README.md) — 移行プレイブック、影響範囲マップ
- [`tools/migrate/README.md`](./migrate/README.md) — 移行スクリプト規約
- [`adapters/claude-code/user-level/mcp/servers.template.json`](../adapters/claude-code/user-level/mcp/servers.template.json) — MCP 宣言テンプレート
