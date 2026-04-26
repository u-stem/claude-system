# 旧 claude-settings からの移行記録

## 旧設定

- パス: `~/ws/claude-settings/`
- 時代: Opus 4.6 期に構築
- GitHub リモート: `git@github.com:<github-user>/claude-settings.git`
- 既存コミット数: 90+ (Phase 0 時点で `91 commits` を含む `main` ブランチ)

## 移行日

2026-04-26

## 機密情報スキャン結果

- 実施日: 2026-04-26
- ツール: gitleaks v8 系
- **git 履歴ベース** (`gitleaks detect --source .`): **clean (no leaks found, 92 commits scanned)**
- **作業ツリー全体** (`gitleaks detect --no-git`): 232 件検出。ただし**全て `.gitignore` 対象**の Claude Code ランタイムファイル
  - `projects/*.jsonl` (会話ログ): 174 件
  - `telemetry/*.json`, `history.jsonl`, `backups/.claude.json.backup.*`, `file-history/`, `statsig/`, `plugins/cache`, `ide/*.lock` 等
- 結論: **GitHub に push されている範囲は安全**

## 方針

1. 旧 claude-settings は **読み取り専用** として保全
2. Phase 0.5 で内容を棚卸しし、新システムへ取り込むものを判別
3. Phase 10 で `~/.claude/` のシンボリックリンクを新システムに切り替えたあと、旧リポジトリは GitHub 側で archive モードへ

## 未 push の差分(2026-04-26 時点)

旧 claude-settings には以下の未 push コミット・未 stage 変更あり(claude-settings 側の判断で扱う):

- `9db569f chore: Opus 4.7 向けに harness 設定を最適化` (CLAUDE.md, hooks/filter-test-output.sh, hooks/require-review-before-commit.sh, settings.json)
- 作業ツリーに `CLAUDE.md`, `settings.json` の未 stage 変更(現在運用中の Claude Code セッションによるもの)

これらに機密は含まれていない(gitleaks --source . で検証済み)。
