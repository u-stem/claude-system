# CLAUDE.md (claude-system 編集者向け)

このリポジトリは **メタリポジトリ** です。本人の AI 協働開発体験そのものを定義します。
ここに加える変更は他の全プロジェクトの開発体験に波及するため、慎重に扱ってください。

## 絶対ルール

- **principles 層に特定ツール名(Claude Code, Cursor 等)を出さない**。普遍的な原則だけを書く
- **機密情報を絶対にコミットしない**。`.gitleaks.toml` と Phase 7b の hooks/CI で多重防御するが、人間/LLM 側でも常に確認する
- **既存ファイルの破壊禁止**。旧 claude-settings (`~/ws/claude-settings/`) は読み取り専用扱い
- **指定範囲外のファイルを「ついで」で編集しない**。Phase 完了報告で git diff を必ず確認
- **冪等性**: 全スクリプトは再実行しても安全であること
- **shell スクリプトは bash 前提、`set -euo pipefail` を必ず付与**
- **macOS BSD コマンド前提**(GNU 互換不要、ただし bash は Homebrew 5.x を許容)

## 編集時の慎重度

| 層 | 慎重度 | 理由 |
|-----|--------|------|
| principles/ | 最大 | 全プロジェクトの根本原則。破壊的変更は MAJOR バージョンアップ |
| practices/ | 高 | 抽象パターン。複数プロジェクトに波及 |
| adapters/ | 中 | ツール固有。当該ツールユーザーに影響 |
| projects/ | 個別 | gitignore 済み、各プロジェクトの統合情報 |
| tools/ | 中〜高 | 自動化スクリプト。冪等性を厳守 |
| meta/ | 低 | 履歴・記録。事実を正確に書くこと |

## 言語規約

- README, CLAUDE.md, ドキュメント類: **日本語**
- コード/シェルスクリプト内のコメント: **英語**
- コミットメッセージ: **英語**(Conventional Commits)

## コミット規約

Conventional Commits:
- `feat:` 新機能、新しい principle/practice/skill 等
- `fix:` 修正
- `docs:` ドキュメントのみ
- `refactor:` リファクタリング
- `chore:` ビルド、CI、雑務
- `test:` テスト追加・修正

## ロールバック

各 Phase で 1 コミット以上残すこと。問題があれば `git revert <commit-id>` で対応。

## 詳細設計

各 Phase の設計と進行は `~/.claude-system-bootstrap/` 配下のドキュメントを参照。
