# Phase 7a への申し送り TODO

このファイルは Phase 0.5 / Phase 6 で判明した「Phase 7a(ツール群)実装時に取り込み判断 / 設計判断が必要なもの」を記録する場所。

## 旧 setup 系スクリプトの取り込み方針(Phase 6 で確認済み)

旧 `~/ws/claude-settings/` の setup 系スクリプトは migration-inventory で **B 分類(抽象化して取り込み)** とされている。Phase 7a で `tools/` 配下に再構築する際の方針を以下に記録。

### 1. `setup.sh`(旧 42 行)→ `tools/setup.sh`

**旧の責務**: `~/.claude/` への symlink を `claude-settings/` に張り直す(既存をバックアップしてから)

**新システムでの再設計**:

- **Phase 10 の symlink 切替と統合**: 旧 setup.sh は単純な symlink 作成だったが、新版は Phase 10 で claude-system 側へ切り替えるため、`tools/sync.sh`(別スクリプト、Phase 7a 仕様)に「symlink 配布」責務を分離する
- **`tools/setup.sh` の責務**: 新環境(別マシン等)の初期化。前提ツール(git / gh / bun / uv / gitleaks 等)の存在確認、不足分は `brew install <pkg>` の実行コマンドを提示(自動実行はしない、ユーザー判断を残す)
- **chezmoi 連携**: chezmoi がインストール済みなら post-hook として呼ばれる前提。chezmoi 未導入でも単独動作する
- **冪等性**: 再実行しても安全(既存ファイルの上書き判断は明示)
- **最後に `doctor.sh` を実行**して整合性確認
- 旧版の「設定ファイル一覧の echo」は新版では `doctor.sh` の出力に統合

### 2. `setup-mcp.sh`(旧 67 行)→ `tools/setup-mcp.sh`(Phase 7a)

**旧の責務**: GitHub MCP / sequential-thinking / playwright / context7 を `claude mcp add` で追加。github は対話式トークン入力

**新システムでの再設計**:

- **MCP 一覧を adapter 層に宣言的に管理**: `adapters/claude-code/user-level/mcp/servers.json.template` のようなファイル(将来作成)に「採用 MCP のリスト」を持つ
- **setup-mcp.sh はそれを読むだけ**(DRY、リスト追加時にスクリプト改修不要)
- **API キー必須 MCP(github 等)はテンプレートに含めず、TODO コメントで誘導**(Phase 6 で確認: ADR 0001/0002 と secrets-handling 原則)
- **対話式入力は維持**(github のトークン取得は手動が安全)
- 既存 MCP の検出は `claude mcp list` で行い、idempotent に
- 旧版の context7 は採用判断未定(現行 settings.json.template には含めていない)— 採用する場合は本リストに追加

### 3. `setup-plugins.sh`(旧 82 行)→ `tools/setup-plugins.sh`(Phase 7a)

**旧の責務**: superpowers-marketplace 追加 + superpowers / typescript-lsp / pyright-lsp / gopls-lsp / rust-analyzer-lsp / frontend-design / code-review / commit-commands / elements-of-style / episodic-memory のインストール

**新システムでの再設計**:

- **プラグイン一覧を adapter 層に宣言的に管理**: `adapters/claude-code/user-level/plugins.json.template` のようなファイル(将来作成)に「採用プラグインのリスト」を持つ
- **現行 settings.json.template の `enabledPlugins`** は `elements-of-style` / `episodic-memory` / `superpowers` の 3 件のみを **enabled = true** にしている。LSP / frontend-design / code-review / commit-commands は旧版にあったが新版では採用判断未確定 — Phase 7a で `update-check` フローと整合させて確定させる
- **memory MCP は ADR 0003 で不採用確定**(本 setup-plugins.sh の対象外)
- 旧版の冪等な `|| echo "（既にインストール済み）"` パターンは継承
- マーケットプレイス追加(`obra/superpowers-marketplace`)は維持

### 4. 旧 `mcp/servers.template.json` / `mcp/README.md`

**旧の責務**: MCP サーバー設定の機械可読テンプレート + 手動セットアップガイド

**新システムでの再設計**:

- **A 分類(直接取り込み)**: `mcp/servers.template.json` は新システムの `adapters/claude-code/user-level/mcp/servers.template.json` に取り込む(API キー必須のものは TODO コメントで誘導、ADR 0001/0002)
- 旧 README に含まれる `memory MCP` 記述は削除(ADR 0003 で不採用確定)
- `setup-mcp.sh` から本 template を読み込む方式に再設計

## Phase 7a で新規作成する script 一覧(再確認用)

Phase 6 時点で確定している予定(Phase 7a 仕様の 16 script):

| # | script | 用途 |
|---|--------|------|
| 1 | `tools/_lib.sh` | 共通ライブラリ(色付き出力 / ロック / バックアップパス / バリデーション / macOS BSD ラッパー) |
| 2 | `tools/sync.sh` | `~/.claude/` symlink 配布(Phase 10 まで `--dry-run` のみ) |
| 3 | `tools/doctor.sh` | 整合性チェック(symlink / frontmatter / @参照 / 禁止語 / VERSION / 循環参照 / SKILL.md / 前提ツール / バックアップ / gitignore / shellcheck) |
| 4 | `tools/setup.sh` | 新環境初期化(本 TODO 1 を参照) |
| 5 | `tools/new-project.sh` | `<project-name> <template-name>` でプロジェクト初期化(本 Phase の template / fragment / プレースホルダ規約と整合) |
| 6 | `tools/adopt-project.sh` | 既存プロジェクトを取り込み |
| 7 | `tools/unadopt-project.sh` | 取り込み撤回 |
| 8 | `tools/restore-project.sh` | プロジェクトの CLAUDE.md をバックアップから復元 |
| 9 | `tools/new-skill.sh` | 新 skill 作成(本 Phase の `skill-creation` skill 手順と整合) |
| 10 | `tools/new-adr.sh` | 新 ADR 作成(本 Phase の `adr-template.md` を雛形に使用) |
| 11 | `tools/cleanup-backups.sh` | `~/.claude-system-backups/` の古いバックアップ削除 |
| 12 | `tools/check-claude-version.sh` | Claude Code バージョン取得 + `adapters/claude-code/VERSION` との差分表示 |
| 13 | `tools/migrate/README.md` | 将来の migration script 置き場の説明 |
| 14 | `tests/lint-skills.sh` | skill の構造チェック(`skills/_index.md` / `subagents/_index.md` の自己検証スクリプトを統合) |
| 15 | `tests/lint-principles-language.sh` | principles 層への禁止語混入を検出(`forbidden-words.txt` を真実源とする) |
| 16 | `tests/check-circular-refs.sh` / `tests/validate-frontmatter.sh` | @参照循環チェック / frontmatter YAML 構文 |

## new-project.sh の設計補足(Phase 6 で確定)

Phase 6 で確定したテンプレート / fragment 構造に基づき、`tools/new-project.sh` は以下の流れで実装する:

1. `<project-name>` と `<template-name>` を引数で受ける
2. `<template-name>` が `adapters/claude-code/project-templates/<template-name>/` に存在することを確認
3. `~/ws/<project-name>/` を作成(既存の場合エラーで停止、上書きしない)
4. `cp -r adapters/claude-code/project-templates/<template-name>/. ~/ws/<project-name>/`
5. `.template` suffix を除去(`*.template` → 拡張子なし版にリネーム)
6. `_TEMPLATE_USAGE.md` を削除
7. プレースホルダ置換: `{{PROJECT_NAME}}` は引数の値、その他は対話式 or 引数オプションで受ける
   - 対話式の場合、空入力ならプレースホルダを残して後で手動置換を促す
8. `~/ws/claude-system/projects/<project-name>/` を作成(`.gitkeep` 配置)
9. `git init` を実行(任意、`--no-git` フラグで skip 可)
10. `pre-commit install` を提示(自動実行はしない、ユーザー判断)
11. 完了時に `_TEMPLATE_USAGE.md` の「利用後のチェックリスト」を出力で表示

skeleton 状態のテンプレート(`pixi-game` 等)を選んだ場合、最後に「本テンプレートは skeleton 状態です。本格採用時に `_TEMPLATE_USAGE.md` の肉付け候補を参照してください」と案内する。

## チェックリスト(Phase 7a 完了時)

- [ ] `tools/setup.sh` が前提ツール検出 + chezmoi 連携 + doctor.sh 起動を含む
- [ ] `tools/setup-mcp.sh` が adapter 層の MCP テンプレートを読む方式に再設計されている
- [ ] `tools/setup-plugins.sh` が adapter 層のプラグインリストを読む方式に再設計されている
- [ ] `adapters/claude-code/user-level/mcp/servers.template.json` が作成されている(API キー必須は除外、TODO コメント)
- [ ] `tools/new-project.sh` が Phase 6 のテンプレート / fragment / プレースホルダ規約と整合している
- [ ] このファイル `meta/TODO-for-phase-7a.md` 自体を削除する(Phase 7a 終了時)
