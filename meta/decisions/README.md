# Architecture Decision Records (ADR)

claude-system における設計上の重大な意思決定を記録する場所。

ここに記録するのは「後から経緯を辿りたくなる判断」のみ。日々の細かい変更は `meta/CHANGELOG.md` に書く。

## 連番ルール

- ファイル名: `NNNN-kebab-case-title.md`(4 桁ゼロ埋め、ハイフン区切りの英小文字タイトル)
- 番号は **意思決定が確定した順** に **連続して** 採番する
- **欠番禁止**: ADR を取り下げる場合でも番号は残し、Status を `Rejected` または `Withdrawn` にして本文を残す
- 同一トピックの後続判断で前の決定を覆す場合は、新規 ADR を採番し前 ADR の Status を `Superseded by NNNN` にする(古い番号の削除はしない)

## 命名規則

| 例 | 意味 |
|----|------|
| `0001-anonymity-policy.md` | 第 1 号 ADR、匿名性ポリシー(実在) |
| `0099-some-future-policy.md` | 仮想例: 将来の新規 ADR は連番末尾に追加 |
| `0099-supersede-anonymity-policy.md` | 仮想例: 0001 を上書きする新方針(Status は Accepted、0001 の Status は Superseded by 0099) |

実在 ADR の一覧は本ファイル末尾「既存 ADR」表を参照。

## Status の語彙

| Status | 意味 |
|--------|------|
| `Proposed` | 提案中、まだ採択されていない |
| `Accepted` | 採択済み、現に運用されている |
| `Rejected` | 提案されたが採択されなかった(本文は議論記録として残す) |
| `Withdrawn` | 一度採択されたが、別 ADR で置き換えられたわけでもなく単に取り下げた |
| `Deprecated` | 採択時の前提が崩れたため非推奨。後継 ADR への参照を Related に書く |
| `Superseded by NNNN` | 後続の ADR `NNNN` で置き換えられた |
| `Partially superseded by NNNN` | 決定の**一部だけ**が後続 ADR `NNNN` で置き換えられ、残りは現に運用されている。置換された範囲を本文の `## Update` に必ず明記する。置換が複数世代にわたる場合は最新の ADR 番号を指し、経緯は `## Update` で辿れるようにする |

`Status` 行は本文冒頭の bullet に置き、現状を必ず正確に保つ。

**Status 行に語彙外の注記を書かない。** 実装状況や適用範囲など Status では表せない情報は、別の bullet(例: `- **実装状況**: ...`)か本文に置く。Status 行が自由記述になると、どれが現行方針かを機械にも人間にも一意に判定できなくなる。

## 必須セクション

各 ADR は以下のセクションを最低限備える(`0001-anonymity-policy.md` を参照モデルとする):

```markdown
# ADR NNNN: <短いタイトル>

- **Status**: <上記語彙のいずれか>
- **Date**: YYYY-MM-DD(初回採択日。後で Status を変えても Date は元のまま、変更経緯は本文末尾に追記)
- **Decider**: <意思決定者>(個人特定情報の制約は ADR 0001 を参照)

## Context

なぜこの判断が必要になったか。背景・制約・関係者・代替案の事情を、後から読んでも経緯が辿れるように書く。

## Decision

何を決めたか。曖昧さなく記述する。条件分岐があるなら表で示す。

## Consequences

決定の結果として起きること:
- **Positive**: 良くなる点
- **Negative**: 副作用・コスト
- **Neutral**: 中立的な影響、注意点

## Related

- 関連 ADR(番号で参照)
- 関連 Phase / コミット / ファイル
- 外部参照(必要なら URL)
```

任意セクションとして、複雑な決定では `Alternatives Considered`(検討した他案)、`Implementation Notes`(実装メモ)を追加してよい。

## 既存 ADR

| 番号 | タイトル | Status | 概要 |
|------|----------|--------|------|
| [0001](./0001-anonymity-policy.md) | Anonymity Policy for claude-system Outputs | Accepted (2026-04-26) | 個人特定情報(本名・呼称・新規 email 等)を成果物に焼き込まない方針。GitHub handle と既露出 personal email は条件付き許容 |
| [0002](./0002-public-private-boundary.md) | Public/Private Boundary in claude-system | Accepted (2026-04-26) | Public claude-system から Private リソース(旧 claude-settings 等)への直接リンクを作らない。Private 情報の存在に言及する場合も URL を含めず事実のみ記載する |
| [0003](./0003-memory-architecture.md) | Memory Architecture for claude-system | Accepted (2026-04-26) | `auto memory` + `episodic-memory` の 2 層に統一し、`Memory MCP` は採用しない。各層の用途分担と振り分けルールを規定 |
| [0004](./0004-system-architecture-summary.md) | System Architecture Summary | Accepted (2026-04-29) | 4 層構造 / forbidden-words 機械検出 / 絶対パス参照規約 / 機械的ガードレール 5 層 / Public 運用 + 機密自動排除 を一貫した方針として総括 |
| [0005](./0005-bootstrap-completion-and-deferral.md) | Bootstrap Completion (v0.1.0-rc1) and Phase 10 Deferral | Accepted (2026-04-29) | Phase 9 完了で機能完成、`v0.1.0-rc1` リリース候補化。Phase 10 切り替えは検証期間確保のため遅延、完了時に `v0.1.0` 付与 |
| [0006](./0006-no-user-identifiers-in-system.md) | No User Identifiers Inside the System | Accepted (2026-04-29) | ADR 0001 の具体実装。本名 / 個人 email / GitHub handle の literal を claude-system に書かない(URL 内の自動参照・LICENSE Copyright holder・プレースホルダは例外)。`.gitleaks.toml` の allowlist 設計や hooks の許容アドレス除外を簡素化する |
| [0007](./0007-phase10-migration-script-robustness-and-boundary.md) | Phase 10 Migration Script — Robustness and Responsibility Boundary | Accepted (2026-05-04) | Phase 10 経験から得た 2 つの教訓を再実行可能性と責務境界という共通テーマで一体化。`from-claude-settings.sh` の preflight + Step 4 を堅牢化し dangling symlink を skip。settings.json の cp-deploy は `sync.sh` の責務として明文化 |
| [0008](./0008-mechanical-detection-of-user-identifier-paths.md) | Mechanical Detection of User-Identifier Paths | Accepted (2026-05-04) | ADR 0006 の機械担保。絶対パス内ユーザー名(`/Users/<name>/`)を二段階で検出 — `post-edit-validate.sh` で編集時 warn、`.gitleaks.toml` custom rule で commit 時 block。自己参照回避は paths allowlist で対処 |
| [0009](./0009-opus-48-autonomy-tuning.md) | Opus 4.8 Autonomy Tuning | Accepted (2026-05-29) | Opus 4.8 期の自律性運用方針を初めて正式に ADR 化。確認抑制の線引き(可逆=自律 / 不可逆・外向き=確認)、サブエージェント委譲の積極化、Workflow はユーザー明示オプトイン時のみ、background / スケジューリング指針を集約。散在していた 4.7 前提の運用記述を更新 |
| [0010](./0010-opus-48-harness-settings-sync.md) | Opus 4.8 Harness Settings Synchronization | Partially superseded by 0022 (2026-05-29) | ADR 0009 の機械層同期。`settings.json.template` の model pin を 4.8 に、`VERSION` を実インストール版(2.1.156)に同期。autonomy 方針は文脈依存判断のため hook 強制せず、既存 deny/ask ガードが「不可逆操作は確認」の線引きを部分担保していることを確認・記録 |
| [0011](./0011-delegation-orchestration-protocol.md) | Delegation / Orchestration Protocol | Accepted (2026-05-29) | ADR 0009 §2(委譲積極化・方針)の運用プロトコル詳細。メイン=オーケストレータ規律(役割分離 / 委譲トリガーの定量基準 / 渡す情報と返却スキーマ / 単発→ファンアウト→Workflow の段階)。`practices/delegation-orchestration.md` + `subagents/_index.md` 委譲プロトコル節として実装済み |
| [0012](./0012-token-economy-mechanization.md) | Token Economy Mechanization and Measurement | Accepted (2026-05-29) | principles/01 の公理を機械化。圧縮ポイントの因果一覧(`practices/token-economy.md`)、出力キャップ hook(`pre-bash-output-cap.sh`、PreToolUse + `updatedInput` でコマンド書き換え。PostToolUse は結果変更不可と判明し方式変更)、`subagent-log.jsonl` の計測点接続。実装済み |
| [0013](./0013-role-based-effort-modulation.md) | Role-Based Effort Modulation via Delegation and Model Selection | Accepted (2026-05-31) | effort のロール別可変化を、検証済み機構(委譲 + subagent の `model` 選択)で実現すると決定。メインループ effort は単一グローバル値を維持(タスク単位自動切替はハーネス機能ギャップ)、実効 effort は複雑度に追従させ委譲で変調。`effort:` frontmatter はスキーマ外・対応未確認のため不採用(`model` を代理)。model-selection.md の「役割固定ルール化しない」を継承 |
| [0014](./0014-tool-call-parse-error-resilience.md) | Tool-Call Parse-Error Resilience | Accepted (2026-06-05) | `tool call could not be parsed (retry also failed)` を上流(`area:model`)の根絶不能事象と前提化。in-band 自動回復は不可と確定(API error は `Stop` でなく `StopFailure` を発火、その出力は無視される)。三層対処: 層0=機械タスクを sonnet/低 effort へルーティング(ADR 0013 適用)、層A=`StopFailure` 通知フック(`notify-stop-failure.sh`、副作用のみ)実装済み、層B=cmux watchdog 自動継続は不可逆操作リスクのため Deferred |
| [0015](./0015-delegation-chain-and-mandatory-delegation.md) | 委譲チェーン(チーム連鎖)と委譲ファーストの運用 | Accepted (2026-06-06) | 実作業を原則 subagent に委譲する運用方針。subagent は再委譲できない構造制約のため、連鎖はメイン経由の単層(`main → A → 戻る → B`)に限られ ADR 0011 と一致。反証専門 `devil-advocate` と実装専門 `implementer` を新設し委譲先ロールを拡充。固定順序チェーンは `/team` command で実装、軽微・可逆な作業はメイン直接実行の例外を維持 |
| [0016](./0016-fable-5-harness-settings-sync.md) | Fable 5 Harness Settings Synchronization | Partially superseded by 0022 (2026-06-10) | Fable 5 GA(2026-06-09)/ Claude Code 2.1.170 への機械層同期。model pin を `claude-fable-5` に、`VERSION` を 2.1.170 に更新し、`fallbackModel: ["claude-opus-4-8"]` を新設。effortLevel `xhigh` と subagent tier(opus/sonnet/haiku)は据え置き(計測なき格上げをしない、ADR 0013 踏襲)。autonomy 方針(ADR 0009)は Fable 5 期も継続 |
| [0017](./0017-settings-auto-sync.md) | Deterministic Settings Rendering and Auto-Sync | Accepted (2026-06-10) | 配置済み `~/.claude/settings.json` を「template ⊕ マシン固有 overrides の決定論的レンダリング成果物」と再定義し、手動マージ運用を廃止。`tools/sync-settings.sh`(dry-run / --apply / --check)新設、template 変更コミットで発火する versioned git hooks(post-commit / post-merge、core.hooksPath 結線)、doctor.sh のドリフト検知を追加。ADR 0010/0016 で繰り越した「手動反映が必要」の Neutral 事項を解消 |
| [0018](./0018-harness-sync-2.1.197.md) | Harness Settings Synchronization (Claude Code 2.1.197) | Accepted (2026-07-01) | Claude Code 2.1.197 への機械層同期。VERSION / MCP / gitleaks pin を更新し、`attribution: {commit:"", pr:""}` を新設して Public リポへのセッション URL 混入経路を遮断(ADR 0002)。`sandbox.credentials` / `autoMode.classifyAllShell` 等の新規キーは不採用。モデル・effort・権限モデルは据え置き |
| [0019](./0019-loop-engineering-phased-adoption.md) | ループエンジニアリングの段階導入 | Accepted (2026-07-08) | 収束ループと失敗フィードバックループの段階導入方針。principles 07 は再訪条件付きで見送り、還流の思想は refactoring-trigger 拡張で受ける。集計の起点 `tools/loop-report.sh` 新設(live + アーカイブ横断)、failure-log の rm 促しをアーカイブ促しへ変更、check への収束構造の部分適用、自動化境界(ドラフトまで機械・採否は人間)の規範化、初回レトロ実走で TODO 項目 10 のクロックを起算 |
| [0020](./0020-failure-hook-event-migration.md) | failure 記録 hook の PostToolUseFailure 移行と観測ループの実効化 | Accepted (2026-07-11) | failure-log ゼロ件の真因は「失敗したツール呼び出しで PostToolUse が発火しない」ことと実測で確定。バインドを PostToolUseFailure(Bash) へ移行し、payload 実測 3 形を防御的に多重参照、レコードに exit_code / cmd を additive 追加。subagent-audit 集計(マシン全体 1 本の実態に合わせる)と `tools/archive-failure-log.sh` で ADR 0019 の欠落を補完。hook 改修時の入れ子 headless e2e 検証様式を確立。VERSION 2.1.206 |
| [0021](./0021-harness-sync-2.1.217.md) | Harness Settings Synchronization (Claude Code 2.1.217) | Accepted (2026-07-22) | VERSION 2.1.206→2.1.217。v2.1.210 で死文化した `Write(path)` deny 7 件を削除(Edit ルールが全編集ツールを統治。削除前に headless positive テストで実効を実測)。MCP pin 更新(playwright 0.0.78 / chrome-devtools 1.6.0 / sequential-thinking 2026.7.4)。ADR 0015 の単層委譲前提がハーネス既定化。Betterleaks は据え置き継続、新規プラグイン(Context7 / Frontend Design)は不採用 |
| [0022](./0022-harness-sync-2.1.220.md) | Harness Sync 2.1.220 — Model Switch to Opus 5 and Effort Recalibration | Accepted (2026-07-25) | VERSION 2.1.217→2.1.220。主モデルを `claude-opus-5[1m]` へ乗り換え(agentic 系ベンチで Fable 5 同等以上・半額、再評価トリガー付き)。無記録だった machine-overrides の `effortLevel: medium` を削除し xhigh を実効化(メイン < subagent の深度逆転を解消)。v2.1.219 のネスト spawn 既定 depth 3 化は pin せず受容し、単層連鎖を「構造制約」から「運用規約」へ是正 + meta.json の `parentAgentId`/`spawnDepth` で観測強化。fallbackModel は Opus 4.8 維持(ADR 0016 のクラシファイア整合根拠は誤帰属と訂正)。practices/model-selection.md に推論深度軸を追補 |
| [0023](./0023-harness-sync-2.1.226.md) | Harness Sync 2.1.226 — プラグイン宣言と実体の乖離、および供給網の閉包 | Accepted (2026-08-08) | VERSION 2.1.220→2.1.226。`enabledPlugins` の 3 件がブートストラップ以来**一度も未インストール**だったと実測判明(根因は ADR 0003 の「セットアップ不要」が事実誤り)。3 件を実導入し `extraKnownMarketplaces` を template 管理へ(自動同期が marketplace 登録を消す経路を実測で発見・封鎖)。`tools/setup-plugins.sh` 新設 + `doctor.sh` に片方向・ファイルベースの乖離検査 + 導線 3 点。`cleanup-claude-code-runtime.sh` が payload 実体である `plugins/cache` を消す欠陥を是正。プラグイン由来 hook が `permissions.deny` の統治外に出た空白を塞がず記録。背景セッションの `git push` を §8 に禁止形で追加。`crossSessionInbound` は据え置き(当初の「strictAllowlist と同型」論拠は反証で撤回)。ADR 0021/0022 の enabledPlugins 誤記録と ADR 0003 を訂正 |
| [0024](./0024-observation-and-restraint-optimization.md) | 観測と抑止の最適化 — 毎ターン診断のティア化、subagent push の機械的抑止、集計の分離 | Accepted (2026-08-09) | 4 領域を実測して採否決定。①`doctor.sh --fast` 新設で Stop hook の CPU を 6.73→0.80 秒(88% 減)、`ulimit -t 10` の無音切断リスクを解消(テストと shellcheck は CI が既にゲート)②ADR 0023 執筆中に subagent が 10 コミットを public main へ自動 push した事故を受け、`pre-bash-guard.sh` で subagent の push のみ deny(判別は実測した `agent_type` の有無。commit は許可)。実エージェントで拒否を実証、9 ケースをテストで固定 ③`loop-report.sh` が委譲 83 / 内部 115 / 旧 115 を混在集計していた問題を分離(empty model rate 見かけ 62% → 実 9.6%)。`spawn_depth >= 2` は 0 件で単層委譲を実データ確認 ④常時コンテキスト 26,552 bytes を実測し削減は不採用(per-skill 無効化機構が無く、CLAUDE.md 2 本に重複ゼロ) |
| [0025](./0025-symlink-switchover-record-and-release-tagging.md) | symlink 切り替えの記録と、ADR 0005 が約束した成果物の決着 | Accepted (2026-08-09) | ADR 0005 が Phase 10 完了時に約束した「`0006-symlink-switchover.md` の起票」と「`git tag v0.1.0`」が 3 か月未履行だったと棚卸しで判明。0006 番は同日別テーマへ採番済みのため番号を繰り上げ、切り替えの実施記録(2026-05-04 16:25 / バックアップ / 動作確認)を本 ADR が引き継ぐ。タグ発行は不可逆・外向き操作として運用者判断へ保留。真因を「ADR に未来の実行の約束を書いたが、回収する仕組みと接続されていなかった」と記録し、TODO への転記規約を新設 |

## ADR を書くタイミング

- principles 層に手を入れるとき(MAJOR バージョンアップ相当の判断)
- 機械的ガードレール(hooks / CI / permissions)を新設するとき
- セキュリティ・プライバシー方針を変更するとき
- 既存ファイル/コミットの破壊的書き換えを伴う方針転換を行うとき
- 「なぜこうしなかったのか」を将来の自分に聞かれたら答えに窮しそうなとき

逆に、以下は ADR を書かない:

- 単純なバグ修正、リファクタリング(コミットメッセージで足りる)
- 単発の追加(新 skill / 新 subagent など、CHANGELOG で足りる)
- typo / 文言調整

## 未来の実行を約束するとき

ADR 本文に「後でこれを行う」と書く場合、**同じコミットで [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md)(または後継の TODO ファイル)へ転記する**。

ADR は判断の記録であって、実行待ちタスクの置き場ではない。ADR 本文に書いただけの約束はどの検査にも棚卸しにも掛からず、履行されないまま放置される。実例: ADR 0005 が約束した切り替え ADR の起票と `git tag v0.1.0` は 3 か月間未履行のまま誰も気づかなかった([ADR 0025](./0025-symlink-switchover-record-and-release-tagging.md))。

**転記しない約束は履行されないものとして扱う。**
