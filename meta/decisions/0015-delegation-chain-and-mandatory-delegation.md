# ADR 0015: 委譲チェーン(チーム連鎖)と委譲ファーストの運用

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-06-06
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

運用者から「実作業を必ず subagent に委譲し、その subagent がさらに委譲して連鎖する『チーム』として動かしたい。どのプロジェクトでも同じように効かせたい」という要望が出た。あわせて反証専門の `devil-advocate` と実装専門の `implementer` を新設し、委譲先のロールを揃えた。

設計に先立ち、Claude Code の構造的制約を公式ドキュメント(`code.claude.com/docs/en/subagents`)で確認した:

- **subagent は別の subagent を起動できない**(構造的制約)。"Subagents cannot spawn other subagents. If your workflow requires nested delegation, use Skills or chain subagents from the main conversation." subagent には他エージェント起動ツールが渡らず、無限ネストが構造的に防止されている。
  - したがって要望の「subagent がさらに委譲する多段チェーン(`main → A → B`)」は**実現不能**。連鎖は必ずメインを経由する単層(`main → A → 戻る → B → 戻る → C`)になる。これは ADR 0011(メイン=オーケストレータ)と完全に一致する。
- **「必ず委譲」の物理強制は限定的**。PreToolUse hook でメインの Edit/Write をブロックすることは技術的に可能だが、「ブロックの代わりに subagent へ自動リダイレクト」はできず、軽微・可逆な 1 行修正まで委譲を強制してしまう。これは ADR 0011 / 0013 の「軽作業はメイン直接実行が損益分岐上有利」と衝突する。

これらを踏まえ、運用者と方針を確認した(2026-06-06):強制は**指示レベル**、連鎖は**固定パイプライン command**、適用範囲は**user-level(全プロジェクト)**。

## Decision

### 1. 委譲チェーンはメイン主導の単層オーケストレーションとする

- 「チーム」= メインが複数の委譲先を**定義された順序で連結**する単層構造。委譲先は自ら再委譲せず、各段の結論は必ずメインに戻る。
- 標準チェーン(局面に応じて段を省略可):

  | 段 | 委譲先 | 目的 |
  |----|--------|------|
  | 探索 | `explorer`(内部)/ `research-summarizer`(外部) | 前提情報の収集 |
  | 計画 | `refactor-planner`(設計が重いとき) | 段階的変更計画の立案 |
  | 反証 | `devil-advocate` | 計画・決定の前提をストレステスト(重い判断の前) |
  | 実装 | `implementer` | 確定した計画をコードに落とす(唯一のコード writer) |
  | レビュー | `code-reviewer`(反復は `/review-loop`) | 実装差分の品質検証 |
  | 最終ゲート | `security-auditor` | 致命度の高い変更に一度だけ |
  | 文書追従 | `doc-writer` | コード変更に伴う doc 更新 |

- 段の取捨選択(どこから始め、どこを飛ばすか)はメインがタスクの性質で判断する。固定テーブル化はしない([`practices/model-selection.md`](../../practices/model-selection.md) のアンチパターン継承)。

### 2. 「委譲ファースト」は指示レベルで運用する(物理強制しない)

- 実装・計画・反証・レビュー・広範な探索は**原則として対応する委譲先に委譲**する、を user-level の共通指示に明記する。
- ただし**軽微・可逆・1 点参照**の作業はメイン直接実行を許容する(委譲の固定費が利得を上回るため。ADR 0011 / 0013 の損益分岐基準に従う)。
- hook による物理ブロックは採らない。軽作業まで委譲を強制し、ADR 0011 / 0013 と矛盾する副作用が大きいため(Alternatives (A))。

### 3. 固定パイプラインを `/team` command として提供する

- 連鎖を毎回同じ順序で確実に回したいときのために、メイン主導の固定パイプラインを slash command `/team` として実装する(`/review-loop` が反復レビューを command 化した先例に倣う)。
- skill ではなく command にする理由: 固定順序の連鎖は「明示起動・決定論的」が望ましく、LLM 判断で自動起動する段階開示型の skill より command が適合する。

### 4. 適用範囲は user-level(全プロジェクト共通)

- 新 subagent・`/team` command・委譲ファースト指示はいずれも user-level に置き、Phase 10 のシンボリックリンクで全プロジェクトに効かせる。
- プロジェクト固有の上書きが要るときは各プロジェクトの設定層で個別対応する(本 ADR は既定の土台を定めるに留める)。

## Consequences

- **Positive**: 委譲の連鎖が明文化され、反証・実装のロールが揃うことで「計画→反証→実装→レビュー→ゲート」の一貫した流れを全プロジェクトで再現できる。指示レベルゆえ軽作業の損益分岐を壊さない。構造的に不可能な多段ネストに依拠しない(実在機構のみ)。
- **Negative**: 「必ず委譲」は物理保証ではなくメインの自制に依存する(指示レベルの限界)。守られているかは別途観測が要る(subagent-log.jsonl での委譲頻度確認)。
- **Neutral**: nested delegation 不可は Claude Code の構造制約であり本 ADR で変えられない。将来ハーネスが多段委譲や per-task 強制を備えたら再評価する。

## Alternatives Considered

- **(A) hook でメインの Edit/Write を物理ブロックし委譲を強制** — 軽微・可逆な修正まで委譲を強制し、往復の固定費が純損になる場面が増える(ADR 0011 / 0013 と衝突)。「ブロックの代替実行(自動リダイレクト)」は hook の権限外で、LLM 推論制御はできない。指示レベルを採用。
- **(B) 連鎖を skill 化して LLM 自動起動に委ねる** — 固定順序の再現性が LLM 判断に左右される。明示起動・決定論的な command を採用(skill は段階開示が要る場面に残す)。
- **(C) subagent 同士の多段委譲(`main → A → B`)** — 構造的に不可能(subagent は他エージェントを起動できない)。メイン主導の単層連鎖で代替。

## Implementation Notes

- 新 subagent: [`adapters/claude-code/subagents/implementer.md`](../../adapters/claude-code/subagents/implementer.md)(sonnet/high)、[`adapters/claude-code/subagents/devil-advocate.md`](../../adapters/claude-code/subagents/devil-advocate.md)(opus/high)。(model, effort) 校正は [ADR 0013](./0013-role-based-effort-modulation.md) のパネルに追記済み。
- 連鎖パターン(抽象)は [`practices/delegation-orchestration.md`](../../practices/delegation-orchestration.md) に追記(特定ツール用語を出さない)。
- 委譲ファースト指示は [`adapters/claude-code/user-level/CLAUDE.md`](../../adapters/claude-code/user-level/CLAUDE.md) に追記。
- 固定パイプライン command は [`adapters/claude-code/user-level/commands/team.md`](../../adapters/claude-code/user-level/commands/team.md)。
- 出所となった要望: 本セッションでの運用者要望(2026-06-06)。

## Update (2026-07-25)

Context の事実命題「subagent は別の subagent を起動できない(構造的制約)」は Claude Code v2.1.219 で偽になった(ネスト spawn が既定 depth 3 まで許容)。本 ADR の単層連鎖は**構造制約由来ではなく運用規約**として維持する(根拠は観測の一元化とメインへの統制集約)。env pin による旧既定の復元は不採用。詳細・観測強化(per-agent meta.json の `parentAgentId` / `spawnDepth` 記録)・再評価トリガーは [ADR 0022](./0022-harness-sync-2.1.220.md) §5 を参照。Consequences の「将来ハーネスが多段委譲を備えたら再評価する」は本 Update で消化した。

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) §2 — サブエージェント委譲の積極化
- [ADR 0011](./0011-delegation-orchestration-protocol.md) — 委譲 / オーケストレーション・プロトコル
- [ADR 0013](./0013-role-based-effort-modulation.md) — ロール別 effort 校正(新 2 ロールを追記)
- [`practices/delegation-orchestration.md`](../../practices/delegation-orchestration.md) — 委譲の規律(連鎖パターン)
- [`practices/iterative-review.md`](../../practices/iterative-review.md) — 反復レビュー(`/review-loop` の設計元)
