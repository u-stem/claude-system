# project-fragments

プロジェクト横断で参照される**断片**を配置するディレクトリ。

## 配布方針

- fragment は**コピーされず参照される**(プロジェクト側の `CLAUDE.md` から `@~/ws/claude-system/adapters/claude-code/project-fragments/<name>.md` で取り込み)
- fragment 自体を更新すれば、参照している全プロジェクトに即座に反映される
- 一方向依存: fragment は `principles/` `practices/` を参照してよいが、特定プロジェクトに依存しない

## ファイル一覧(2026-04-26 時点)

| ファイル | 用途 | 主な参照元 |
|---------|------|-----------|
| `web-apps-common.md` | Web 系プロジェクト共通指針(SSR/CSR 判断、a11y、Web Vitals 等のフレームワーク独立部分) | `project-templates/nextjs-supabase/CLAUDE.md.template` |
| `games-common.md` | ゲーム系共通(loop / 状態管理 / アセット / 入力、2D・3D 独立) | `project-templates/pixi-game/CLAUDE.md.template` |
| `board-game-design-common.md` | 板ゲー設計共通(物理・デジタル両用、コンポーネント / バランス / プレイテスト) | `project-templates/board-game-doc/CLAUDE.md.template` |
| `adr-template.md` | ADR の標準テンプレート(Phase 4 `adr-writing` skill と整合) | `project-templates/*/docs/adr/0001-*.md.template`、`tools/new-adr.sh`(Phase 7a 予定) |
| `pre-commit-config.template.yaml` | pre-commit hook の共通基盤(gitleaks + プロジェクト側で言語別 hook を上書き) | 各 `project-templates/*/.pre-commit-config.yaml` |
| `README.md` | 本ファイル | — |

## 改訂時の注意

- fragment は**参照されている**ため、変更は全参照元に伝播する。**互換性破壊を伴う変更は避ける**(命名変更・セクション削除等)
- 互換性破壊が必要なら、新 fragment を別名で追加し、旧 fragment は `@deprecated` コメントを付けて当面残す
- 1 fragment 1500 字以内目安(`@参照` で取り込まれるため過剰な情報量はメインコンテキストを圧迫する、`principles/01-context-economy.md`)
- 言語規約: 日本語(参照元プロジェクトが日英いずれでも、運用者向けの指示は日本語で統一)
- 特定ツール用語(skill / subagent / hook / settings 等)を使ってよいのは adapter 配下のため OK だが、fragment 内では**最小限**に留め、ツール非依存の表現を優先
- ADR 0001(本人呼称除去)/ ADR 0002(Public→Private リンク禁止)を遵守

## 関連

- [`principles/04-progressive-disclosure.md`](~/ws/claude-system/principles/04-progressive-disclosure.md) — 必要時に必要な情報だけロード
- [`practices/project-bootstrap.md`](~/ws/claude-system/practices/project-bootstrap.md) — 共通基盤を参照する形で始める
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — クロスレイヤー参照のパス規約
- [`adapters/claude-code/project-templates/_README.md`](~/ws/claude-system/adapters/claude-code/project-templates/_README.md) — テンプレート側の使い方
