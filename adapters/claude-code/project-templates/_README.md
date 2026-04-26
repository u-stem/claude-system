# project-templates

新規プロジェクトの初期構成を提供する**テンプレート**を配置するディレクトリ。

## 配布方針

- テンプレートは**コピーされる**前提(参照ではない)
- Phase 7a で `tools/new-project.sh <project-name> <template-name>` 経由で展開予定
- 手動展開時は各テンプレートの `_TEMPLATE_USAGE.md` を参照
- プレースホルダ規約: `{{PLACEHOLDER_NAME}}` 形式(英大文字 + アンダースコア)

## テンプレート一覧

| name | 用途 | 状態 | 含まれるファイル |
|------|------|------|------------------|
| [`nextjs-supabase/`](./nextjs-supabase/) | Next.js + Supabase Web プロジェクト(主要スタック) | **完成** | `CLAUDE.md.template` / `README.md.template` / `.gitignore` / `.gitleaks.toml` / `.pre-commit-config.yaml` / `docs/adr/{README.md, 0001-architecture-overview.md.template}` / `_TEMPLATE_USAGE.md` |
| [`pixi-game/`](./pixi-game/) | ゲーム系プロジェクト(PixiJS / 他エンジンへの転用も可) | **skeleton** | `CLAUDE.md.template` / `.gitignore` / `.gitleaks.toml` / `_TEMPLATE_USAGE.md`(本格採用時に肉付け) |
| [`board-game-doc/`](./board-game-doc/) | 板ゲー設計プロジェクト(物理 / デジタル両用) | **完成** | `CLAUDE.md.template` / `.gitignore` / `.gitleaks.toml` / `docs/{rulebook,balance-tests,playtest-logs}/.gitkeep` / `_TEMPLATE_USAGE.md` |

## テンプレート選定ガイド

| やりたいこと | 推奨 template |
|-------------|---------------|
| Web アプリ(認証・DB あり) | `nextjs-supabase` |
| 静的サイト(認証・DB なし) | `nextjs-supabase` から Supabase 関連を削る、または将来の `nextjs-static` template を待つ |
| Web ゲーム(2D / 3D) | `pixi-game`(skeleton 状態、肉付け後使用) |
| ボードゲーム / カードゲームの設計 | `board-game-doc` |
| ネイティブゲーム(Rust / Go / native) | `pixi-game` を参考に新 template を `skill-creation` 手順で作成 |
| Python データ解析 / CLI | 将来の `python-cli` template を待つ、または手動構築 + 手で `python-style` skill 参照 |

## 共通の前提

すべてのテンプレートは以下を前提とする:

- `~/ws/claude-system/` に claude-system が配置されている(クロスレイヤー参照のパス規約、`adapters/claude-code/README.md`)
- ユーザーレベル CLAUDE.md (`~/.claude/CLAUDE.md`) が claude-system にリンクされている(Phase 10 以降)
- 各テンプレートの `CLAUDE.md.template` は冒頭で `@~/ws/claude-system/adapters/claude-code/project-fragments/<name>.md` を参照する形で共通基盤を取り込む

## 機械的ガードレール(全テンプレート共通)

- `.gitleaks.toml` で機密検出(allowlist + ダミー値 regex)
- `.gitignore` で `.env*` / Claude Code ランタイム生成物 / 中間アセットを除外
- 完成 template には `.pre-commit-config.yaml` で gitleaks + 言語別 typecheck/lint(`fragments/pre-commit-config.template.yaml` をベース)
- skeleton template は `.pre-commit-config.yaml` を肉付け時に追加

## テンプレート利用後の標準フロー

各テンプレートの `_TEMPLATE_USAGE.md` に詳細手順あり。共通の流れ:

1. `~/ws/<project-name>/` を作成し、テンプレートを `cp -r` でコピー
2. `.template` suffix を外してリネーム(`CLAUDE.md.template` → `CLAUDE.md` 等)
3. `_TEMPLATE_USAGE.md` を削除(利用後不要)
4. プレースホルダを `sed -i ''`(macOS BSD)で一括置換
5. `git init` + 初回 commit
6. 言語別の依存インストール(`bun install` 等)
7. `pre-commit install`(完成 template のみ)
8. `~/ws/claude-system/projects/<project-name>/` も作成し、fragment / 補助ノートを置く(gitignore 対象)

## 改訂時の注意

- テンプレートは**コピーされる**ため、変更は新規プロジェクトのみに影響する(既存プロジェクトには伝播しない)
- 既存プロジェクトに反映したい場合は、各プロジェクト側で手動マージ(または将来の `tools/sync-from-template.sh` を待つ)
- ADR 0001(本人呼称除去) / ADR 0002(Public→Private リンク禁止) / クロスレイヤー絶対パス規約を遵守
- skeleton 状態のものを完成させたら、本表の「状態」列を更新

## 関連

- [`adapters/claude-code/project-fragments/README.md`](../project-fragments/README.md) — fragment 側(参照される)
- [`practices/project-bootstrap.md`](~/ws/claude-system/practices/project-bootstrap.md) — 立ち上げ手順の抽象
- [`adapters/claude-code/user-level/skills/skill-creation/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/skill-creation/SKILL.md) — skeleton を肉付ける手順の準用元
- [`meta/TODO-for-phase-7a.md`](~/ws/claude-system/meta/TODO-for-phase-7a.md) — `tools/new-project.sh` 設計メモ
