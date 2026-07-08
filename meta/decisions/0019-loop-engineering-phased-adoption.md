# ADR 0019: ループエンジニアリングの段階導入

- **Status**: Accepted
- **Date**: 2026-07-08
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

claude-system には「反復・自動再実行・フィードバック」の素材が 3 系統存在するが、互いに独立に進化しており、ループとしての設計が閉じていない:

1. **収束ループ(手動)** — `/review-loop` command と設計元 `practices/iterative-review.md`。収束条件・ラウンド上限・立て直し/継続・最終ゲートという収束構造が明文化されているのは、このレビュー 1 文脈のみ。`/check` は実態として修正ループを回すが構造が未明文
2. **委譲チェーン(手動)** — `/team` command(ADR 0015)
3. **失敗フィードバックループ(自動)** — hooks が失敗を `<project>/.claude/failure-log.jsonl` に記録し、SessionStart の `check-failure-patterns.sh` が同カテゴリ 3 回以上の再発を通知する。しかし**通知止まり**であり、通知文言は「対処後に `rm`」を促して計測の連続性(再発率の before/after を測る材料)を自ら断つ設計だった

加えて調査で以下が確定した:

- ADR 0012 が計測点と位置づけた `failure-log.jsonl` / `subagent-log.jsonl` の**集計の起点(ツール)が未実装**。ADR 0012 Update 節の計測品質問題(`agent_type` 空 69%)も可視化手段がない
- **月次レトロは実績ゼロ**(`meta/retrospectives/` はテンプレートのみ)。TODO-for-v0.2 項目 10「レトロ連動の自動化」のトリガー(手動 3 ヶ月)は未起算。自己改善ループ最大のボトルネックは自動化不足ではなく「レトロが回っていないこと」
- ログの正準パスは hooks 実装側の `<project>/.claude/*.jsonl`(実データも実在)。`meta/operating-manual.md` とレトロテンプレートが記す `~/.claude/projects/<scope>/` は誤りで、集計を作る前に是正が必要
- `failure-log.jsonl` はまだどのプロジェクトにも存在しない = 検出ループは一度も発火していない

「単発のタスク実行の設定」から「ループを中核に据えた開発体験」への進化にあたり、本リポジトリの一貫した哲学(計測なき格上げをしない / 先回り導入を避ける / 物理強制より指示レベル + 観測)と整合する段階導入の線引きを決める。本 ADR は devil-advocate による反証レビューを経ており、反証で覆った初期案は「見送った選択肢」に記録する。

## Decision

### 1. principles 07(ループの原則)は今回昇格させない

「品質も設定も、一回の強さではなく収束条件を持つ反復と観測の還流から改善される」という原則候補は認識するが、`principles/00-meta.md` の昇格要件(複数文脈での妥当性確認)を満たさない(明文化された収束構造の適用実績はレビュー 1 文脈のみ)。**再訪条件**:

1. 収束構造の適用が 3 文脈で運用される
2. 月次レトロ 3 回で還流の実績が確認される
3. 四半期見直しで既存 02(意思決定の保存)/ 06(変化への適応戦略)との代替・補完・競合を判定する

昇格時は MAJOR 相当のため別 ADR を起票する。

### 2. 還流の思想は `practices/refactoring-trigger.md` の拡張で受ける

独立 practice(feedback-loop)の新設は見送る。反証レビューの指摘: 新設根拠とした「3 文脈の実績」のうち月次レトロは実績ゼロの設計であり水増しである、既存 practice(refactoring-trigger の 3 回ルール、update-propagation の波及、adr-workflow の記録)との境界競合が未検証のまま真実源を増やすことになる。収束ループ側に課した「3 適用まで独立ファイル化しない」自制を還流側にも対称に適用する。

refactoring-trigger に「失敗パターンの還流」節を追加し、還流の 5 段(記録→検出→集約→昇格→検証)と自動化境界を規範化する。**独立 practice 化の再訪条件**: 月次レトロの実績が積まれ、還流節が実際に昇格を駆動した実績が出たとき。

### 3. 収束構造の一般形を明文化し、`/check` に部分適用する

- `practices/iterative-review.md` に「収束ループの一般形」節を追加(5 要素: 収束条件の事前宣言 / 上限 / 立て直し・継続の使い分け / 最終ゲート / 構造化結論)。ただし決定論的な検査修正への適用は全要素同型ではなく**部分適用**(収束条件 + 振動検出 + ソフトな上限)であることを正確に記す
- `commands/check.md` に修正ループ節を追加。主停止条件は**振動・停滞検出**(同一エラー 2 ラウンド連続 = 進捗なし)とし、固定ラウンド上限は主条件にしない(検査修正は決定論的で失敗は単調減少が正常。固定 hard cap は正当な修正を打ち切る)
- `/team` への収束語彙統一は Phase 2(check ループの実運用 1 回後)に送る

### 4. 集計の起点 `tools/loop-report.sh` を新設し、記録の保全へ切り替える

- **計測の連続性の目的は「再発率の before/after トレンド分析」**と確定する。したがって loop-report は live ログとアーカイブ(`<project>/.claude/failure-log.archive/*.jsonl`)を**時系列マージして横断集計**する(アーカイブを読まない集計では、保全したデータを消費する経路がなく目的が達成されない — 反証レビュー指摘)
- `check-failure-patterns.sh` の通知末尾を `rm` 促しから**アーカイブ促し**に変更する。hook 自身は通知のみ(ファイル操作の副作用を持たない)を維持
- 複数プロジェクト横断のロールアップ(`--all`)を備える(同一カテゴリ失敗のプロジェクト跨ぎ再発は最強の昇格シグナル)
- 自動実行はしない。月次レトロと随時に人間が起動する道具に留める

### 5. 自動化境界の規範

| 段 | 担当 |
|----|------|
| 記録・検出・集計表示 | 機械(hooks / loop-report.sh) |
| 昇格候補のドラフト生成 | 機械(ただし明示起動時のみ。常駐・自動生成はしない) |
| 昇格の採否、practices / principles への反映、ログのアーカイブ実行 | 人間 |

ADR 0009(/loop・scheduled agents は明示要求時のみ)と整合する。

### 6. 初回レトロを実走し、TODO 項目 10 のクロックを起算する

道具だけ作ってもレトロが回る確率は上がらない(反証レビューの最重要指摘)。本 ADR の実装と同時に `meta/retrospectives/2026-07.md` を実データで作成し、「月次レトロを 3 ヶ月手動運用」のクロックを 2026-07 起算とする。TODO 項目 10 のトリガー条件自体(自動化判断は手動 3 ヶ月後)は変更しない。

## Alternatives Considered(見送った選択肢)

| 案 | 見送り理由 |
|----|-----------|
| principles 07 の即時新設 | 昇格要件(複数文脈)未達。自リポジトリの「計測なき格上げをしない」と自己矛盾 |
| `practices/feedback-loop.md` の新設 | 実績根拠の水増し(レトロ設計を実績に計上)と境界競合未検証。refactoring-trigger 拡張で受ける |
| 収束ループの独立 practice ファイル化 | 適用 2 文脈(レビュー + 検査修正)のみ。3 適用到達まで iterative-review 内の節に留める |
| SessionStart での昇格ドラフト自動生成 | 自動化境界(§5)違反。セッション開始の副作用も増える |
| レトロの /loop・routine 自動起動 | TODO 項目 10 のトリガー(手動 3 ヶ月)成立前。ADR 0009 のオプトイン原則 |
| check への固定 3 ラウンド上限 | 検査修正は決定論的で失敗は単調減少が正常。振動検出を主条件に変更 |

## Consequences

- **Positive**: 失敗フィードバックループが「記録を消す通知」から「保全 + 集計 + 定例消費」に閉じる。収束構造が 2 文脈目(検査修正)へ広がり、一般形が言語化される。ADR 0012 の計測(空フィールド率含む)が初めて可視化される。レトロのクロックが起算され、TODO 項目 10 の判断材料が貯まり始める
- **Negative**: アーカイブは人間の手動 mv 頼み(hook は促すのみ)。守られなければ live ログが肥大するか、逆に rm されて連続性が切れる。月次レトロで loop-report を叩く運用が定着しなければ、道具は死蔵する
- **Neutral**: Phase 2(team への展開)以降は運用実績を条件とする(ADR 0012 と同じ段階導入様式)。principles 07 と独立 practice 化は再訪条件成立まで凍結。`subagent-log.jsonl` の agent_type 空問題は可視化のみで修正しない(ADR 0012 の前進記録方針を維持)

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — /loop・scheduled agents のオプトイン原則(§5 の根拠)
- [ADR 0012](./0012-token-economy-mechanization.md) — 計測点の位置づけと agent_type 空 69% 問題(§4 の可視化対象)
- [ADR 0015](./0015-delegation-chain-and-mandatory-delegation.md) — /team・/review-loop の委譲チェーン(収束ループの既存 1 文脈)
- [`practices/iterative-review.md`](../../practices/iterative-review.md) — 収束ループの一般形節
- [`practices/refactoring-trigger.md`](../../practices/refactoring-trigger.md) — 失敗パターンの還流節
- [`tools/loop-report.sh`](../../tools/loop-report.sh) — 集計の起点
- [`adapters/claude-code/user-level/hooks/check-failure-patterns.sh`](../../adapters/claude-code/user-level/hooks/check-failure-patterns.sh) — アーカイブ促しへの変更
- [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) — 項目 10(レトロ連動の自動化)のクロック起算
- [`meta/retrospectives/2026-07.md`](../retrospectives/2026-07.md) — 初回レトロ
