# adapters/claude-code

Claude Code 向けの settings, skills, subagents, hooks, project templates 等を配置する。

## サブディレクトリ

| パス | 役割 |
|------|------|
| user-level/ | グローバル設定(CLAUDE.md, settings.json テンプレート, skills, hooks) |
| user-level/skills/ | ユーザレベル skill 定義 |
| user-level/hooks/ | ユーザレベル hook スクリプト |
| subagents/ | 共通 subagent 定義 |
| project-templates/ | 新規プロジェクト用のひな形(言語/フレームワーク別) |
| project-fragments/ | 既存プロジェクトの CLAUDE.md に追記する断片 |

詳細は Phase 3 以降で構築される。
