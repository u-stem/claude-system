# CHANGELOG

このリポジトリの変更履歴。

## [Unreleased]

### 2026-04-26 — Phase 0 完了

- リポジトリ初期化(v3 マスタープランに基づく)
- ディレクトリ構造作成: `principles/`, `practices/`, `adapters/{claude-code,codex}/`, `projects/`, `tools/migrate/`, `tests/`, `meta/{decisions,retrospectives}/`, `.github/workflows/`
- ルートに `README.md`, `CLAUDE.md`, `LICENSE` (MIT), `.gitignore`, `.gitleaks.toml`, `VERSION` (0.1.0) を配置
- 各層に骨子の README を配置
- `meta/` 配下に `CHANGELOG.md`, `claude-version-log.md`, `migration-from-claude-settings.md`, `glossary.md` を配置
- バックアップ専用ディレクトリ `~/.claude-system-backups/` 作成
- gitleaks スキャン: 旧 claude-settings の git 履歴は clean を確認(232 件の検出はすべて gitignore 対象のランタイムログ)
