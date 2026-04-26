# adapters

各 AI 開発ツール固有の設定・拡張を配置する層。
principles と practices をそのツールの語彙に翻訳して具体化する。

## 想定アダプタ

- `claude-code/` — Claude Code (Anthropic CLI)
- `codex/` — OpenAI Codex CLI 等

特定ツール名・固有概念(skill, subagent, hook 等)が登場するのは**この層以下のみ**。
