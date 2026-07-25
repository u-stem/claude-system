---
name: team
description: 委譲チェーン(計画→反証→実装→レビュー→ゲート)をメイン主導で回す
---

タスクを委譲チェーンで遂行する: $ARGUMENTS

メインがオーケストレータに徹し、各段を対応する subagent に委譲して連結する。
設計と判断基準は [`practices/delegation-orchestration.md`](../../../../practices/delegation-orchestration.md)(連鎖の規律)と [ADR 0015](../../../../meta/decisions/0015-delegation-chain-and-mandatory-delegation.md) に従う(本コマンドはその Claude Code 実装)。

## 前提となる運用規約

- **連鎖は必ずメインを経由する単層**(`main → A → 戻る → B → 戻る → C`)とする。ハーネスは v2.1.219 以降ネスト委譲を depth 3 まで許容するが、観測(subagent-log)と統制をメインに集約するため多段ネストは使わない(ADR 0015 / 0022)。
- 各段の戻りは**構造化結論のみ**。ファイル全文・探索ログをメインに載せない([`delegation-orchestration`](../../../../practices/delegation-orchestration.md))。

## いつこのコマンドを使うか

- 設計級・不可逆級の変更(境界・契約の変更、新機能、100 行超 / 5 ファイル超)を、計画→反証→実装→レビューの一貫した流れで通したいとき
- 委譲を毎回同じ順序で確実に回したいとき

ごく軽微・可逆な 1 点修正はメイン直接実行で足りる(連鎖の固定費が見合わない)。探索だけ・レビューだけなど単発で足りる場合は対応する subagent / `/review` を直接使う。

## チェーンの構成(段は取捨選択する)

| 段 | 委譲先 | model / effort | 省略の目安 |
|----|--------|----------------|-----------|
| 1. 探索 | `explorer`(内部)/ `research-summarizer`(外部) | haiku/medium / sonnet/high | 対象が既知で前提情報が揃っているなら省略 |
| 2. 計画 | `refactor-planner` | opus/high | 設計が自明な小変更なら省略(メインが方針を決める) |
| 3. 反証 | `devil-advocate` | opus/high | 可逆・低致命なら省略。重い / 不可逆判断の前は必須 |
| 4. 実装 | `implementer` | sonnet/high | 必須(唯一のコード writer) |
| 5. レビュー | `code-reviewer`(反復は `/review-loop`) | sonnet/high | 必須。設計級は `/review-loop` で反復収束 |
| 6. 最終ゲート | `security-auditor` | opus/high | セキュリティ感受面 / 致命度の高い変更のみ |
| 7. 文書追従 | `doc-writer` | haiku/medium | コード変更に伴う doc があれば |

段の取捨選択はタスクの性質でメインが判断する。役割を固定で強制せず、複雑度に追従させる([`model-selection`](../../../../practices/model-selection.md))。

## 手順

1. **タスクを分解し、回す段を宣言する**
   - $ARGUMENTS から、上表のどの段を使うか(どこから始め、どこを飛ばすか)を先に決めて明示する。

2. **探索(必要時)**
   - 前提情報が不足するなら `explorer` / `research-summarizer` に委譲し、構造化要約だけ受け取る。

3. **計画 → 反証**
   - 設計が重いなら `refactor-planner` に段階的計画を立てさせる。
   - 重い / 不可逆な判断を含むなら、その計画を `devil-advocate` に渡して反証させる(前提の崩れ・代替案・非対称リスク)。
   - メインは反証を踏まえ計画を確定する(採用 / 条件付き / 再考)。**最終判断はメインが持つ**。

4. **実装**
   - 確定した計画・完了条件・触ってよい範囲を `implementer` に渡して実装させる。設計判断は渡さない(確定済みが前提)。
   - 戻りは編集ファイル・検証結果・残課題の構造化報告のみ。

5. **レビュー**
   - 実装差分を `code-reviewer` に渡す。設計級なら `/review-loop` で反復収束させる(毎ラウンド新規起動 + 最終ゲート)。
   - 重大指摘は実装(4)へ差し戻す。

6. **最終ゲート(必要時)**
   - セキュリティ感受面 / 致命度の高い変更は、収束後の小さくなった差分に `security-auditor` を一度だけ当てる。

7. **文書追従(必要時)**
   - コード変更に伴う doc は `doc-writer` に委譲するか、メインが同コミットで更新する。

8. **報告**
   - 回した段 / 各段の結論 / 反証で覆った点 / レビュー収束 / 残課題を、user-level CLAUDE.md の完了報告フォーマットで要約する。

## アンチパターン

- subagent に多段委譲させる(ハーネス上は可能だが運用規約違反。観測と統制が崩れるため連鎖は必ずメイン経由)
- 軽微・可逆な作業まで全段を回す(固定費が純損。段を絞るかメイン直接)
- 計画と実装、レビューと修正を同じ担当に兼ねさせる(独立性が崩れる)
- 反証を省いて重い判断を確定する(非対称リスクを見落とす)
- 各段の中間出力を素通しでメインに積む(コンテキスト肥大、委譲の利得喪失)

## 関連

- practice: [`delegation-orchestration`](../../../../practices/delegation-orchestration.md)(連鎖の規律・委譲ファースト)
- practice: [`iterative-review`](../../../../practices/iterative-review.md) / command: `/review-loop`(レビュー段の反復)
- subagent: `explorer` / `research-summarizer` / `refactor-planner` / `devil-advocate` / `implementer` / `code-reviewer` / `security-auditor` / `doc-writer`
- ADR: [`0015-delegation-chain-and-mandatory-delegation`](../../../../meta/decisions/0015-delegation-chain-and-mandatory-delegation.md) / [`0011-delegation-orchestration-protocol`](../../../../meta/decisions/0011-delegation-orchestration-protocol.md)
