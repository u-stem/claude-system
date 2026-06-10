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

`Status` 行は本文冒頭の bullet に置き、現状を必ず正確に保つ。

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
| [0010](./0010-opus-48-harness-settings-sync.md) | Opus 4.8 Harness Settings Synchronization | Accepted (2026-05-29) | ADR 0009 の機械層同期。`settings.json.template` の model pin を 4.8 に、`VERSION` を実インストール版(2.1.156)に同期。autonomy 方針は文脈依存判断のため hook 強制せず、既存 deny/ask ガードが「不可逆操作は確認」の線引きを部分担保していることを確認・記録 |
| [0011](./0011-delegation-orchestration-protocol.md) | Delegation / Orchestration Protocol | Accepted (2026-05-29) | ADR 0009 §2(委譲積極化・方針)の運用プロトコル詳細。メイン=オーケストレータ規律(役割分離 / 委譲トリガーの定量基準 / 渡す情報と返却スキーマ / 単発→ファンアウト→Workflow の段階)。`practices/delegation-orchestration.md` + `subagents/_index.md` 委譲プロトコル節として実装済み |
| [0012](./0012-token-economy-mechanization.md) | Token Economy Mechanization and Measurement | Accepted (2026-05-29) | principles/01 の公理を機械化。圧縮ポイントの因果一覧(`practices/token-economy.md`)、出力キャップ hook(`pre-bash-output-cap.sh`、PreToolUse + `updatedInput` でコマンド書き換え。PostToolUse は結果変更不可と判明し方式変更)、`subagent-log.jsonl` の計測点接続。実装済み |
| [0013](./0013-role-based-effort-modulation.md) | Role-Based Effort Modulation via Delegation and Model Selection | Accepted (2026-05-31) | effort のロール別可変化を、検証済み機構(委譲 + subagent の `model` 選択)で実現すると決定。メインループ effort は単一グローバル値を維持(タスク単位自動切替はハーネス機能ギャップ)、実効 effort は複雑度に追従させ委譲で変調。`effort:` frontmatter はスキーマ外・対応未確認のため不採用(`model` を代理)。model-selection.md の「役割固定ルール化しない」を継承 |
| [0014](./0014-tool-call-parse-error-resilience.md) | Tool-Call Parse-Error Resilience | Accepted (2026-06-05) | `tool call could not be parsed (retry also failed)` を上流(`area:model`)の根絶不能事象と前提化。in-band 自動回復は不可と確定(API error は `Stop` でなく `StopFailure` を発火、その出力は無視される)。三層対処: 層0=機械タスクを sonnet/低 effort へルーティング(ADR 0013 適用)、層A=`StopFailure` 通知フック(`notify-stop-failure.sh`、副作用のみ)実装済み、層B=cmux watchdog 自動継続は不可逆操作リスクのため Deferred |
| [0015](./0015-delegation-chain-and-mandatory-delegation.md) | 委譲チェーン(チーム連鎖)と委譲ファーストの運用 | Accepted (2026-06-06) | 実作業を原則 subagent に委譲する運用方針。subagent は再委譲できない構造制約のため、連鎖はメイン経由の単層(`main → A → 戻る → B`)に限られ ADR 0011 と一致。反証専門 `devil-advocate` と実装専門 `implementer` を新設し委譲先ロールを拡充。固定順序チェーンは `/team` command で実装、軽微・可逆な作業はメイン直接実行の例外を維持 |
| [0016](./0016-fable-5-harness-settings-sync.md) | Fable 5 Harness Settings Synchronization | Accepted (2026-06-10) | Fable 5 GA(2026-06-09)/ Claude Code 2.1.170 への機械層同期。model pin を `claude-fable-5` に、`VERSION` を 2.1.170 に更新し、`fallbackModel: ["claude-opus-4-8"]` を新設。effortLevel `xhigh` と subagent tier(opus/sonnet/haiku)は据え置き(計測なき格上げをしない、ADR 0013 踏襲)。autonomy 方針(ADR 0009)は Fable 5 期も継続 |
| [0017](./0017-settings-auto-sync.md) | Deterministic Settings Rendering and Auto-Sync | Accepted (2026-06-10) | 配置済み `~/.claude/settings.json` を「template ⊕ マシン固有 overrides の決定論的レンダリング成果物」と再定義し、手動マージ運用を廃止。`tools/sync-settings.sh`(dry-run / --apply / --check)新設、template 変更コミットで発火する versioned git hooks(post-commit / post-merge、core.hooksPath 結線)、doctor.sh のドリフト検知を追加。ADR 0010/0016 で繰り越した「手動反映が必要」の Neutral 事項を解消 |

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
