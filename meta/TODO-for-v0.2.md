# v0.2 への持ち越し TODO

Phase 9(`v0.1.0-rc1` リリース候補化)で消化しきれなかった、または時間軸的に v0.2 以降が妥当な検討事項を集約する。

このファイルは `meta/TODO-for-phase-9.md` を継承する。Phase 9 で実施した項目は本ファイルに記載しない([`CHANGELOG.md`](./CHANGELOG.md) Phase 9 セクションを参照)。

## ステータス区分

各項目を鮮度で仕分ける。「解決済み」はクローズ記録(末尾)へ移動済み。

| # | 項目 | 状態 |
|---|------|------|
| 1 | 「旧資産からの継承」節の整理判断 | 継続保留 |
| 2 | テンプレート構造の階層化深化 | トリガー待ち |
| 3 | テンプレート成熟度の昇格基準 | トリガー待ち |
| 4 | kairous `rules/*.md` の重複削除(案 X) | トリガー待ち(順序依存) |
| 5 | Phase 8 で発見された skill 化候補 | トリガー待ち |
| 6 | AGENTS.md の扱い | 条件待ち(Codex CLI 動向) |
| 7 | claude-system 自身の Issue 駆動運用 | v0.2 開発開始時 |
| 8 | drawzzz 取り込み | トリガー待ち(再開時) |
| 9 | マシン横断のメモリ同期 | 検討(別マシン時) |
| 10 | レトロ連動の自動化 | トリガー待ち(月次レトロ 3 ヶ月後) |
| 11 | principles / practices 層の見直し履歴 | 継続保留(四半期見直し定例化後) |
| 12 | migrate スクリプトの壊れた symlink 耐性 | **解決済み** → クローズ記録 |
| 13 | settings.json 配置の責務整合 | **解決済み** → クローズ記録 |
| 14 | ADR 0011 実装(委譲オーケストレーション) | **解決済み** → クローズ記録 |
| 15 | ADR 0012 実装(トークン経済の機械化) | **解決済み** → クローズ記録 |
| 16 | VERSION pin を実インストール版へ同期 | **解決済み** → クローズ記録 |
| 17 | MCP 登録経路(インライン / 宣言)の二重管理整理 | トリガー待ち(次の MCP 更新機会) |

---

## 1. 「旧資産からの継承」セクションの整理判断(継続保留)

### 検討事項

`principles/` および `practices/` の各ファイルにある「旧資産からの継承」セクションの価値の濃淡。

- 意味のあるもの: 抽象化の経緯を残し、後から原則の根拠を辿れる
- プレースホルダ的なもの: 「対応する独立章がなかった」のような事実記述のみで judgment が働かない

Phase 9 では実施せず継続保留(他の整理タスク優先)。v0.2 で再判断する。

### 判断時の補助情報

- `meta/migration-from-claude-settings.md` への集約案
- 別ファイル(`meta/derivation-records.md`)への外出し案
- ADR 0002 に従い、URL や git remote を含めない記述になっているか確認

### 関連

- [`principles/00-meta.md`](../principles/00-meta.md) — 共通フォーマット 6 セクションの定義
- [`migration-inventory.md`](./migration-inventory.md)
- [`migration-from-claude-settings.md`](./migration-from-claude-settings.md)

---

## 2. テンプレート構造の階層化深化

### トリガー(以下のいずれか)

- 4 つ目のテンプレート追加要求
- 既存テンプレート間で重複コード(`.gitignore` / `.gitleaks.toml` / fragment 参照部分等)が顕著に増えた
- 「技術スタックの固定化」が実害として顕在化(新規プロジェクトが既存テンプレートに引きずられる事例)

### 判断軸

- 共通化できる部分が増えてきたら階層化、そうでなければ現状維持
- 過剰抽象化を避ける([`principles/05-separation-of-concerns.md`](../principles/05-separation-of-concerns.md))
- 階層化する場合は ADR 起票

---

## 3. テンプレート成熟度の昇格基準

### トリガー

- ゲーム実装プロジェクト開始(`pixi-game` 検証機会)
- 新規ボードゲームプロジェクト着手(`board-game-doc` 検証機会)
- 同じテンプレートを 2 プロジェクト以上で使い、フィードバックが揃った時点

### 判断軸

[`adapters/claude-code/project-templates/_README.md`](../adapters/claude-code/project-templates/_README.md) の成熟度定義に従う:

- **完成**: 実プロジェクトで運用された経験あり、抽象化の根拠が経験ベース
- **暫定**: 部分的な実戦経験あり、未検証部分がある
- **skeleton**: 最小骨子、実戦経験なし

実プロジェクトでの使用 → フィードバック反映 → ADR 起票 → 昇格、の流れ。

---

## 4. kairous `rules/*.md` の重複削除判断(案 X)

### 経緯

Phase 8 では案 Y(`@web-apps-common.md` 追加のみ、`rules/` は無編集)で取り込み完了。
Phase 9 検証では重複の実害は確認できなかったため継続保留。

### 削減方針(将来の参考)

| 対象ファイル | 削減方針 |
|---|---|
| `~/ws/kairous/.claude/rules/code-quality.md` | 汎用部削除、kairous 固有(`constants.ts` / `database.ts` SSoT)のみ残す |
| `~/ws/kairous/.claude/rules/security.md` | env / Supply Chain 汎用部削除、`security-audit` skill を `@` 参照。kairous 固有(Supabase RLS / Edge Functions service_role / `src/middleware.ts` CSP / `src/lib/env.ts`)は残す |
| `~/ws/kairous/.claude/rules/testing.md` | TDD 汎用部削除、`testing-typescript` skill を `@` 参照。Small/Medium/Large 分類 + CI flake / TZ / E2E ルールは残す |
| `~/ws/kairous/.claude/rules/workflow.md` | エージェント委譲基準の Sonnet 期記述削除。PR 運用 / worktree / PBI 管理は残す |

### トリガー

- kairous 運用安定 + 共通基盤への信頼確立(目安: 取り込みから 2-4 週間)
- 重複が実害になっていると確認できた時

### 注意事項(順序の罠)

`rules/workflow.md` の「PBI 管理」「ブランチ戦略」「PR ルール」は GitHub Issue 駆動運用と密接で、部分削除は文脈を失うリスクがある。

**案 X に進む前の前提**: 後述の中優先 skill 化候補(特に `issue-driven-pbi-management` / `retrospective-to-action` / `pr-action-to-issue`)を先に skill 化し、Issue 駆動運用全体を共通基盤側に持ち上げてから rules を削減する順序を守る。

---

## 5. Phase 8 で発見された skill 化候補(高優先 4 件 + 他多数)

### Phase 9 での判断

高優先 4 件(sugara 由来)について、いずれも「sugara 単独で確立、kairous には適用外」または「適用余地はあるが kairous 側で実害未確認」状態。Phase 9 での skill 化はしない判断。
理由: 共通基盤側の skill は両プロジェクトで実害を防ぐ価値が確認できてから昇格させる方が、過剰投資 + 後で剥がす負荷を避けられる。

### sugara 由来高優先 4 件(transplant 候補としてラベル)

| 候補名 | 用途 | kairous 応用可能性 |
|---|---|---|
| `drizzle-vercel-buildcommand-migration` | Vercel buildCommand で migration 自動実行(Pattern A)、`db:push` 禁止 | ✗(kairous は Supabase migration を別管理) |
| `tauri-v2-3files-version-sync` | tauri.conf.json + Cargo.toml の手動同期、desktop-tag.yml → desktop-build.yml | ✗(kairous にデスクトップ無し) |
| `supabase-realtime-channel-cleanup` | `removeChannel` 二重呼び出しガード | ?(kairous Realtime 採用未確認) |
| `next-intl-cookie-i18n-sync` | next-intl Cookie ベース、ja/en 同時更新義務 | ✗(kairous に i18n 無し) |

→ 4 件のうち 3 件は kairous 適用外で「sugara 単独」運用が妥当。共通基盤化は v0.2 以降で判断。

### kairous 由来 transplant 候補(sugara で未到達)

| 候補名 | sugara への transplant トリガー |
|---|---|
| `test-taxonomy-bun-vitest`(Small/Medium/Large 3 層分類) | sugara のテスト数増加 + フレーキネス顕在化時 |
| `playwright-testid-policy`(E2E `data-testid` 規約) | sugara で E2E 保守性が問題化した時 |
| `timezone-aware-tests`(`toJstDateString()`、CI UTC vs ローカル JST 吸収) | テスト数増加 + フレーキネス顕在化時 |
| `issue-driven-pbi-management`(GitHub Issues / Projects / Milestones) | sugara がチーム開発に移行した時 |
| `retrospective-to-action`(Discussion でアクション抽出 → Issue/PR 化) | 同上 |
| `pr-action-to-issue`(PR 内発見アクションの Issue 化判断) | 同上 |

**先回り導入は避ける**(過剰投資の罠)。

### branch-protection-solo-flow(Phase 9 で kairous 該当性確認)

- sugara: `release-flow.md` / `lefthook.yml` に「main 直 push 禁止 + squash merge + linear history 強制」の運用あり
- kairous: `~/ws/kairous/.claude/rules/workflow.md`(2026-04-29 確認時点)に同等の記述存在
  - 130 行目: 「main への直接コミット禁止 (例外なし)」
  - 138 行目: `gh pr merge <N> --auto --squash` + branch protection の required status checks
  - 129 行目: 「PR 経由必須。cherry-pick で main 直接取り込み禁止」

両プロジェクトで実態として運用されているため、新基準(両方の実態に適用可能)で skill 化候補として有力。
ただし v0.2 で次の項目とまとめて判断する:

- skill 名・粒度(branch-protection-solo-flow / linear-history-policy / pr-required-flow など複数案)
- どの能力単位として切り出すか(skill / fragment / practice)
- 「solo-flow」の語が将来チーム運用に移行したときに混乱しないか

### 低優先候補

低優先候補リストは `meta/TODO-for-phase-9.md`(Phase 9 完了とともに retire 済み)に記載されていた。必要があれば `git log -- meta/TODO-for-phase-9.md` から復元する。中優先候補も同様に v0.2 で再評価。

---

## 6. AGENTS.md の扱い

### 経緯

kairous は `AGENTS.md`(120 行)を Codex CLI 互換のために保持。
Claude Code が直接これを読むかは現時点で不確定。

### 将来の検討

| シナリオ | 方針 |
|---|---|
| Codex CLI を使わなくなった場合 | `AGENTS.md` の内容を `CLAUDE.md` または `.claude/rules/agents.md` に統合し、`AGENTS.md` を削除 |
| Codex CLI を併用し続ける場合 | `AGENTS.md` と `CLAUDE.md` の整合運用ルールを定める。`@` 参照で重複を避けるか、両方を同期するスクリプトを `tools/` に追加 |
| 内容が乖離して混乱が発生した場合 | 即座に整合確認、ADR で統合方針を決定 |

### トリガー

- Codex CLI を使わなくなった時
- `AGENTS.md` と `CLAUDE.md` の内容が乖離して混乱が発生した時

---

## 7. claude-system 自身の Issue 駆動運用検討

### 現状ギャップ

| 機能 | claude-system 現状 | kairous の対応物 |
|---|---|---|
| TODO 管理 | ファイルベース(`meta/TODO-for-*.md`) | GitHub Issues + Projects |
| 振り返り | `meta/retrospectives/` | GitHub Discussions(マイルストーン閉じ / Epic 終了時)|
| ADR | `meta/decisions/0NNN-*.md` で永続記録のみ | Discussion で議論 → 確定で ADR ファイル化 |
| Phase / Epic 管理 | ファイル(`PHASE-*.md`)| GitHub Milestones |

### 判断軸

- 単独運用のためフル運用は過剰の可能性
- ADR 議論プロセスを Discussion で記録する価値は高い
- Issue 駆動導入なら kairous の運用パターンを skill 化(`issue-driven-pbi-management` / `retrospective-to-action` / `pr-action-to-issue`)してから適用するのが筋

### トリガー

- claude-system v0.2 開発開始時(Phase 10 完了後)
- ファイルベース TODO 管理に限界を感じた時

---

## 8. drawzzz 取り込み

### 経緯

Phase 8 でスキップ。理由: 中断中、再開未定、`games-common.md` / `pixi-game` template の実戦経験が薄い状態で取り込んでも検証材料にならない。

### Phase 9 での確認

- Web 系 2 プロジェクト(kairous, sugara)で十分な検証ができている
- drawzzz スキップは claude-system の動作確認に支障なし

### 将来のトリガー

drawzzz 再開時:

1. `tools/adopt-project.sh` で取り込み
2. `games-common.md` の検証
3. 不足部分を fragment / skill にフィードバック

---

## 9. マシン横断のメモリ同期

### 検討事項

別マシンセットアップ時、`auto memory` / `episodic-memory` の同期をどう扱うか。

### 候補案

- `episodic-memory` SQLite DB を rsync / iCloud Drive 同期
- `auto memory` Markdown ファイルを git 管理(Public 化リスクに注意)
- 同期せず、各マシンで独立運用

### 判断軸

- 同期する場合の Public 化リスク(個人情報・プロジェクト固有情報がメモリに含まれる可能性)
- 同期しない場合の利便性低下

[`multi-device-setup.md`](./multi-device-setup.md) の「マシン横断のメモリ同期」を参照。

---

## 10. レトロ連動の自動化

### 検討事項

`failure-log.jsonl` の集計や週次/月次レトロ起動を `/loop` skill や routine で自動化するか。

### トリガー

- 月次レトロを 3 ヶ月続けて手動運用した後、定型部分が見えてきたら検討

---

## 11. principles / practices 層の見直し履歴

四半期見直しの定例が運用されたら、見直し記録の保存方針を整理する。
現状は `meta/CHANGELOG.md` + `meta/decisions/<NNNN>-*.md` で十分だが、四半期見直し独自のフォーマットが必要なら `meta/quarterly-review/<YYYY-Q>.md` 案も検討。

## 17. MCP 登録経路の二重管理整理(トリガー待ち)

### 検討事項

MCP の pin が 2 系統に分散している(ADR 0018 の code review で顕在化):

- インライン: `settings.json.template` の `mcpServers`(Claude Code が起動時に直接読む)— 現在 playwright(`npx`)
- 宣言: `mcp/servers.template.json`(`tools/setup-mcp.sh` が `claude mcp add` で登録)— sequential-thinking / playwright(`bunx`)/ chrome-devtools

playwright が両系統に重複し、runner も `npx` / `bunx` で不一致(user-level/CLAUDE.md §5 の bun 優先と齟齬)。

### 判断時の論点

- どちらを正とするか(インライン一本化 / 宣言一本化 / 役割分担の明文化)
- 重複解消時に既存の配置済み環境で MCP が二重登録されていないかの確認手順
- runner を `bunx` に統一(bun 優先規約との整合)

### トリガー

次に MCP の pin / 構成を触る機会。それまではバージョン更新時に両系統の pin を同一に保つ運用で凌ぐ(README「MCP 登録経路」節に明記済み)。

---

## 解決済み(クローズ記録)

以下は v0.2 を待たず Phase 10 後続作業で解決済み。経緯の全文は ADR と `git show` を参照。

| 旧# | 項目 | 解決内容 |
|---|---|---|
| 12 | migrate スクリプトの壊れた symlink 耐性 | [ADR 0007](./decisions/0007-phase10-migration-script-robustness-and-boundary.md) + commit `8e2ed0d`。`from-claude-settings.sh` に preflight の dangling symlink 検出・除去を追加し、Step 4 のバックアップを `cp -L -R` から `find -print0` ベースの個別判定コピーへ置換(dangling は skip + warn)。再実行可能性を確保 |
| 13 | settings.json 配置の責務整合 | 同 ADR 0007 + commit `8e2ed0d`。`from-claude-settings.sh` を「1 回限りの構造変更」、`sync.sh` を「再実行可能な値配置」と責務分離し、Step 7 の文言を「`tools/sync.sh` に委譲」へ書き換え。挙動と文言を一致させた |
| 14 | ADR 0011 実装(委譲オーケストレーション) | [ADR 0011](./decisions/0011-delegation-orchestration-protocol.md)(Accepted)。`practices/delegation-orchestration.md` 新設 + `subagents/_index.md` に委譲プロトコル節を追加。役割分離 / 委譲トリガーの定量基準 / 返却スキーマ / 段階を明文化 |
| 15 | ADR 0012 実装(トークン経済の機械化) | [ADR 0012](./decisions/0012-token-economy-mechanization.md)(Accepted)。`practices/token-economy.md` 新設 + 出力キャップ hook `pre-bash-output-cap.sh`(PreToolUse + `updatedInput`)を導入・結線。`subagent-log.jsonl` を計測点に位置づけ |
| 16 | VERSION pin を実インストール版へ同期 | [ADR 0016](./decisions/0016-fable-5-harness-settings-sync.md)(Accepted)。Fable 5 GA / Claude Code 2.1.170 への harness 同期と同一作業で `VERSION` を `2.1.170` へ、model pin を `claude-fable-5` へ更新。`fallbackModel` 新設、MCP pin・gitleaks-action v3 も併せて更新 |

---

## 関連

- [`CHANGELOG.md`](./CHANGELOG.md) — Phase 0-10 完了履歴
- [`decisions/`](./decisions/) — ADR
- [`integration-trace.md`](./integration-trace.md) — Phase 9 統合テストシミュレーション
