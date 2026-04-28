# Phase 9 への申し送り TODO

このファイルは Phase 1 / Phase 2 / Phase 3 等での運用・整理判断のうち、
Phase 9(検証・レトロ・整備)で一括判断・整理すべきものを記録する場所。

## kairous 取り込み: rules/*.md 重複削除(案 X、Phase 8 由来)

### 検討事項

Phase 8 の kairous 取り込みは案 Y(`CLAUDE.md` 冒頭への `@web-apps-common.md` 追加のみ)で実施した。共通基盤と重複している rules を削減する案 X は将来検討。

| 対象ファイル | 削減方針 |
|--------------|----------|
| `~/ws/kairous/.claude/rules/code-quality.md` | 汎用部(コメント日本語、TODO 禁止、握りつぶし禁止、DRY 2/3)を削除し、kairous 固有(`constants.ts` / `database.ts` SSoT)のみ残す。冒頭で user-level CLAUDE.md を `@` 参照 |
| `~/ws/kairous/.claude/rules/security.md` | env / Supply Chain 汎用部を削除し、`@~/ws/claude-system/adapters/claude-code/user-level/skills/security-audit/SKILL.md` を `@` 参照。kairous 固有(Supabase RLS / Edge Functions service_role / `src/middleware.ts` CSP / `src/lib/env.ts`)は残す |
| `~/ws/kairous/.claude/rules/testing.md` | TDD 汎用部を削除し、`@~/ws/claude-system/adapters/claude-code/user-level/skills/testing-typescript/SKILL.md` を `@` 参照。Small/Medium/Large 分類 + CI flake / TZ / E2E ルールは残す |
| `~/ws/kairous/.claude/rules/workflow.md` | エージェント委譲基準(5 クエリ超 / Opus 4.7 1M)を削除。PR 運用 / worktree / PBI 管理は残す |

### トリガー

以下のいずれかが満たされたら検討開始:

- Phase 9 検証で重複が実害になっていると確認できた時
- kairous 運用が安定して共通基盤への信頼が確立した時(目安: 取り込みから 2-4 週間)

### 注意事項(順序の罠)

`rules/workflow.md` の「PBI 管理」「ブランチ戦略」「PR ルール」は GitHub Issue 駆動運用と密接に結びついているため、部分削除は文脈を失うリスクがある。`AGENTS.md`(役割定義)も同様。

**案 X に進む前の前提**: 後述「Phase 8 で発見された skill 化候補」の中優先候補(特に `issue-driven-pbi-management` / `retrospective-to-action` / `pr-action-to-issue`)を先に skill 化し、Issue 駆動運用全体を共通基盤側に持ち上げてから rules を削減する順序を守る。

## Phase 8 で発見された skill 化候補(kairous 取り込みから)

### 中優先候補(sugara への応用可能性: 高)

| 候補名 | 用途 | 出所 |
|--------|------|------|
| `supabase-edge-functions-placement` | Edge Function vs Server Action vs Client の配置判断、`service_role` bypass の使いどころ | kairous の `rules/security.md`、FSRS Edge Functions 配置パターン |
| `test-taxonomy-bun-vitest` | Small / Medium / Large 3 層テスト分類、モック禁止判定、Supabase ローカル前提の Medium 切り分け | kairous の `rules/testing.md` |
| `playwright-testid-policy` | E2E セレクタ規約(`data-testid` / `role` / `label` 限定、CSS class セレクタ禁止) | kairous の `rules/testing.md` E2E 章 |
| `timezone-aware-tests` | `setHours()` ローカル TZ 依存、`toJstDateString()`、CI(UTC)とローカル(JST)の差を吸収するテスト | kairous の `rules/testing.md` TZ 章 |
| `issue-driven-pbi-management` | GitHub Issues / Projects / Milestones を使った PBI / Epic 管理パターン | kairous の `rules/workflow.md`、`AGENTS.md`、運用慣習 |
| `retrospective-to-action` | マイルストーン閉じ / Epic 終了時の振り返り、Discussion でアクション抽出、Issue/PR 化 | kairous の運用慣習(2026-04-28 補足情報)|
| `pr-action-to-issue` | PR 内で発見されたアクションを Issue 化するか PR 内対応するかの判断 | kairous の運用慣習(2026-04-28 補足情報)|

### 低優先候補(kairous 固有度高、再利用性低)

- `learning-science-fsrs`(FSRS / spaced repetition の Edge Functions 配置判断、コンソリデーション間隔設計)
- `active-recall-design`(active recall を促す UI 設計、流暢性錯覚回避)
- `lighthouse-coverage-check`(`lighthouserc.json` 連動、`bun run check:lighthouse-coverage`)
- `worktree-migration-numbering`(`bun run worktree:create` の予約番号方式)
- `agent-team-roles-scrum`(Developer / Reviewer / PO / Tester / User の役割定義パターン)

### トリガー

- sugara 取り込み(次セッション)で同じパターンが発見された時、共通化判断を行う
- 発見されなくても Phase 9 のレトロで kairous 単体での skill 化判断は可能

### 判断軸

- 2 プロジェクト以上で同じパターンが見られたら共通化(skill 化)
- 1 プロジェクトのみなら、当該プロジェクト内の `.claude/skills/` で保持

## kairous AGENTS.md の扱い

### 検討事項

kairous は `AGENTS.md`(120 行)を Codex CLI 互換のために保持している。Claude Code が直接これを読むかは現時点で不確定だが、kairous の運用記述(Developer/Reviewer/PO/Tester/User 役割定義、Scrum ワークフロー、ブランチ戦略、PR ルール、PBI 管理)が集約されている重要文書。

### 将来の検討

| シナリオ | 方針 |
|---------|------|
| Codex CLI を使わなくなった場合 | `AGENTS.md` の内容を `CLAUDE.md` または `.claude/rules/agents.md` に統合し、`AGENTS.md` を削除 |
| Codex CLI を併用し続ける場合 | `AGENTS.md` と `CLAUDE.md` の整合運用ルールを定める。`@` 参照で重複を避けるか、両方が同期するスクリプトを `tools/` に追加 |
| 内容が乖離して混乱が発生した場合 | 即座に整合確認、ADR で統合方針を決定 |

### トリガー

- Codex CLI を使わなくなった時
- `AGENTS.md` と `CLAUDE.md` の内容が乖離して混乱が発生した時

## claude-system 自身の Issue 駆動運用検討

### 経緯

kairous の GitHub Native Scrum 運用(GitHub Issues / Projects / Discussions / Milestones)が claude-system に欠けている領域として 2026-04-28 に発見された。v3 マスタープランは完全に見落としていた。

### 現状

| 機能 | claude-system 現状 | kairous の対応物 |
|------|--------------------|------------------|
| TODO 管理 | ファイルベース(`meta/TODO-for-phase-N.md`)| GitHub Issues + Projects |
| 振り返り | `meta/retrospectives/` 未活用 | GitHub Discussions(マイルストーン閉じ / Epic 終了時)|
| ADR | `meta/decisions/0NNN-*.md` で永続記録のみ(議論プロセス未記録)| Discussion で議論 → 確定で ADR ファイル化 |
| Phase / Epic 管理 | ファイル(`PHASE-*.md`)| GitHub Milestones |

### 検討する移行案

- `TODO-for-phase-N.md` → GitHub Issue
- `meta/retrospectives/` → GitHub Discussions
- ADR 起案 → Discussion で議論 → 確定で ADR ファイル化
- Phase 単位で GitHub Milestones 化

### 判断軸

- 個人プロジェクトのためフル運用は過剰の可能性
- ただし ADR 議論プロセスを Discussion で記録する価値は高い
- Issue 駆動導入なら kairous の運用パターンを skill 化(上述の `issue-driven-pbi-management` / `retrospective-to-action` / `pr-action-to-issue`)してから適用するのが筋

### トリガー

- claude-system v0.2 開発開始時(Phase 9 完了後)
- ファイルベース TODO 管理に限界を感じた時

## drawzzz の Phase 8 スキップ判断

### 経緯

Phase 8 当初計画では drawzzz も取り込み対象だったが、以下の理由でスキップ:

- drawzzz は中断中(再開未定)
- `games-common.md` / `pixi-game` template の実戦経験が薄い状態で取り込んでも、検証材料にならない
- 再開時に取り込む方が、実戦経験ベースで `games-common` を進化させる機会になる

### Phase 9 での確認事項

- drawzzz スキップが claude-system の動作確認に支障をきたしていないか
- Web 系 2 プロジェクト(kairous, sugara)で十分な検証ができているか

### 将来のトリガー

drawzzz 再開時:

1. `tools/adopt-project.sh` で取り込み
2. `games-common.md` の検証
3. 不足部分を fragment / skill にフィードバック

## テンプレート構造の階層化深化(Phase 4.5 追加)

### 検討事項

- 現状: `adapters/claude-code/project-templates/` 配下が技術固有の独立テンプレート(`nextjs-supabase`, `pixi-game`, `board-game-doc`)
- 検討: 4 つ目以降のテンプレート追加時、共通骨格(技術非依存)+ オーバーレイ(技術固有)の二層化を判断するか

### トリガー

以下のいずれかが満たされたら検討開始:

- 4 つ目のテンプレート追加要求が発生
- 既存テンプレート間で重複コード(`.gitignore` / `.gitleaks.toml` / fragment 参照部分等)が顕著に増えた
- 「技術スタックの固定化」が実害として顕在化(新規プロジェクトが既存テンプレートに引きずられる事例)

### 判断軸

- 共通化できる部分が増えてきたら階層化、そうでなければ現状維持
- 過剰抽象化の罠を避ける([`principles/05-separation-of-concerns.md`](../principles/05-separation-of-concerns.md) — 実態がないのに抽象化しない)
- 階層化する場合、既存テンプレートを破壊しない移行手順を ADR で定める

## テンプレート成熟度の昇格基準(Phase 4.5 追加)

### 検討事項

- `pixi-game`(skeleton)と `board-game-doc`(暫定)の昇格判断基準
- 実プロジェクトでテンプレートを使った後、何をもって「完成」と判断するか

### トリガー

- ゲーム実装プロジェクトの開始(`pixi-game` の検証機会)
- 新規ボードゲームプロジェクトのデジタル化着手時(`board-game-doc` の検証機会)
- 同じテンプレートを 2 プロジェクト以上で使い、フィードバックが揃った時点

### 判断軸

- 実プロジェクトで使ってみて、テンプレートにフィードバックすべき学びがあるか
- 学びを反映した上で「完成」へ昇格、ADR として記録
- 「成熟度の定義」(`adapters/claude-code/project-templates/_README.md`)を満たすか:
  - **完成**: 実プロジェクトで運用された経験があり、抽象化の根拠が経験ベース
  - **暫定**: 部分的な実戦経験あり、未検証部分がある
  - **skeleton**: 最小骨子、実戦経験なし

## 「旧資産からの継承」セクションの整理判断

`principles/` および `practices/` の各ファイルに **「旧資産からの継承」** セクションを設けているが、価値の濃淡が混在している:

- 意味のあるもの: 旧資産で個別 heuristic として表現されていたものを抽象化した経緯を残し、後から「この原則の根拠は何か」を辿れる
- プレースホルダ的なもの: 「旧資産には対応する独立章がなかった」「同居していた」のような事実記述のみで、後から読んでも judgment が働かない

Phase 9 のレトロで以下を一括判断する:

- [ ] 各ファイルの「旧資産からの継承」セクションを目視レビュー
- [ ] 削除する / 「該当なし」と明記する / 別ファイルに外出しする(例: `meta/migration-from-claude-settings.md` への集約)を選ぶ
- [ ] 整合した方針に従って一括書き換え

### 判断時の補助情報

- Phase 1.5 として独立フェーズ化する案もあったが、即時の作業影響なしとして見送り済み(Phase 3 時点)
- Phase 9 で他の整理タスクと並行実施する想定
- 「旧資産」の具体的な参照は ADR 0002(Public/Private 境界)に従い、URL・git remote を含めない記述になっているか確認する

### 関連

- [`principles/00-meta.md`](../principles/00-meta.md) — 共通フォーマット 6 セクションの定義(うち 1 つが「旧資産からの継承」)
- [`meta/migration-inventory.md`](./migration-inventory.md) — 旧 claude-settings の取り込み判断台帳
- [`meta/migration-from-claude-settings.md`](./migration-from-claude-settings.md) — 旧資産との関係を集約するファイル
