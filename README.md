# claude-system

個人用の AI 協働開発システム。
全プロジェクトに対して統一的かつ高パフォーマンスな開発体験を提供するメタリポジトリ。

## 設計思想

- **層構造**: principles(不変) → practices(抽象) → adapters(ツール固有) → projects(個別)
- **抽象と具体の分離**: ツールが変わっても principles 層は不変
- **段階的開示**: 必要なときに必要な情報だけロード
- **既存資産の保護**: 既存プロジェクトの暗黙知を破壊しない
- **機械的防御の優先**: 自制に頼らず機械で防げるものは機械で防ぐ
- **冪等性**: スクリプトは再実行可能
- **可観測性**: 何をやったか必ず記録する

## ディレクトリ構成

| パス | 役割 |
|------|------|
| principles/ | 不変の根本原則(ツール非依存) |
| practices/ | 抽象的な実践パターン |
| adapters/ | 各 AI 開発ツール固有の設定・拡張 |
| adapters/claude-code/ | Claude Code 向けの skills, subagents, hooks 等 |
| projects/ | プロジェクト個別の統合情報(gitignore 対象、中身は管理外) |
| tools/ | 同期・診断・セットアップスクリプト |
| tests/ | システム自体の自動テスト |
| meta/ | 変更履歴、設計決定記録、用語集 |
| .github/workflows/ | CI(機密検出など) |

## 現状

段階的に構築中(Phase 0 完了)。進捗は `meta/CHANGELOG.md` を参照。

旧設定 `~/ws/claude-settings/`(Opus 4.6 時代)は別途 GitHub に保全済み。
**Phase 10 まで `~/.claude/` のシンボリックリンクは旧設定を指したまま**維持される。

## バックアップ

専用ディレクトリ `~/.claude-system-backups/` に保管(保持期間 30 日)。

## ライセンス

MIT
