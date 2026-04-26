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

## テンプレート成熟度

| テンプレート | 成熟度 | 実戦経験 | 利用時の注意 |
|---|---|---|---|
| `nextjs-supabase` | 完成 | 高(複数の実プロジェクトで運用中) | 通常利用可、想定外の問題は少ない |
| `pixi-game` | skeleton | 低(デジタルゲーム実装の成功例なし) | 試行錯誤前提で肉付けすること。実装経験を積んだ後に「完成」へ昇格判断 |
| `board-game-doc` | 暫定 | 中(物理ボードゲームのプレイテスト経験あり、デジタル化未着手) | 物理ゲーム設計の運用は実証済み。デジタル化要素は未検証のため要注意 |

### 成熟度の定義

- **完成**: 実プロジェクトで運用された経験があり、抽象化の根拠が経験ベース
- **暫定**: 部分的な実戦経験あり、未検証部分がある
- **skeleton**: 最小骨子、実戦経験なし。利用時に大幅な肉付けが必要

成熟度の昇格は実プロジェクトでの利用後、その学びを反映した時点で実施する。
判断は ADR として記録すること([`adr-writing`](~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md) skill 参照)。

なお上の「テンプレート一覧」表の「状態」列は本表の「成熟度」と同義であり、片方を更新したらもう片方も更新する。

## テンプレート選択の注意

このディレクトリにテンプレートがあるからといって、新規プロジェクトでこれらを必ず使う必要はない。
技術スタック選定は形骸化しがちなので、新規プロジェクト立ち上げ時は以下を推奨:

1. [`project-tech-stack-decision`](~/ws/claude-system/adapters/claude-code/user-level/skills/project-tech-stack-decision/SKILL.md) skill で候補を網羅的に検討する
2. ADR として選定理由を記録する([`adr-writing`](~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md))
3. テンプレートを使う場合: 上記「成熟度」表で実戦経験を確認
4. テンプレートを使わない場合: `tools/new-project.sh` の「ゼロから始める」モード(Phase 7a で実装予定)を使う

「主要スタックだから」「テンプレートにあるから」で機械的に選ぶことを避ける。

## テンプレート選定ガイド

| やりたいこと | 推奨 template |
|-------------|---------------|
| Web アプリ(認証・DB あり) | `nextjs-supabase` |
| 静的サイト(認証・DB なし) | `nextjs-supabase` から Supabase 関連を削る、または将来の `nextjs-static` template を待つ |
| Web ゲーム(2D / 3D) | `pixi-game`(skeleton 状態、肉付け後使用) |
| ボードゲーム / カードゲームの設計 | `board-game-doc` |
| ネイティブゲーム(Rust / Go / native) | `pixi-game` を参考に新 template を `skill-creation` 手順で作成 |
| Python データ解析 / CLI | 将来の `python-cli` template を待つ、または手動構築 + 手で `python-style` skill 参照 |

ただし**この表に該当するからといってテンプレート利用が最善とは限らない**。前述のとおり `project-tech-stack-decision` skill で候補を比較した上で判断すること。

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
