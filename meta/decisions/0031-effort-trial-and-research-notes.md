# ADR 0031: effort 試行と研究知見の注記

- **Status**: Accepted
- **Date**: 2026-09-23
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## 決定

1. 主モデル(Fable 5.1)の effort を 2026-09-23〜2026-10-07 の期限付き例外として `high` にして測る。決定本体(索引「メインループ effort は単一 xhigh」)は変えない。指標と baseline(2026-09-09〜09-23): (a) 中断率 = StopFailure 通知 6 件 / Stop 記録 15 行(セッション数の代理としては弱く、09-23 以降は `session-start-doctor.log` の行数で数える)、(b) 委譲の完走率 = subagent-log 78 件で非ゼロ終了 0、(c) failure-log の実失敗 14 件(probe 1 件を除外)、(d) 体感: 以前 `/effort high` が書かれていた期間に運用者は差を感じなかった。解除条件: 期限で差が無ければ high を新既定として索引を書き換える(ADR)、悪化なら xhigh に戻す。委譲先 5 役の `effort: high` は維持(外すとセッション値 xhigh を継承する。ADR 0013)
2. 主モデルの試行 2 を予約: 2026-10-07 以降、`claude-opus-5-5[1m]` へ 2 週間切り替えて同じ指標で測る(効率試行と重ねない)。fallback の入れ替え案は試行時に判断
3. 研究知見を practices 5 本へ定性的注記として採用(session-handoff / delegation-orchestration / iterative-review / model-selection / skill-design-guide)。数値・銘柄・URL は本 CHANGELOG に置く。あわせて `/team` の最終ゲートに計画要点を渡して逸脱を検査させ、doctor に CLAUDE.md 200 行の目安検査、update-check に「部品の仮定の再検証」手順を追加

## 根拠

- 固定高 effort は精度を落としうるとの実証と、ある世代の公式評価で中程度 effort が精度維持・出力大幅減、ハーネスの既定も High(`meta/CHANGELOG.md` 2026-09-23「研究の取り込み」)
- 索引の parse-error 行は「1M 高占有 + 強い thinking が誘発」と仮説しており試行はその検証(`meta/decisions/README.md` 委譲とモデル節)
- 運用者の自然実験(high 期間に差を感じなかった)と、本リポジトリに品質信号が無いこと(同 CHANGELOG)

## 再評価トリガー

2026-10-07 の判定 / 試行 2 の結果 / 採用した出典が追試で覆ったとき / 公開評価で主モデル差が数ポイント以内に縮んだとき

## 不採用と理由

- 委譲先の `effort:` 削除: セッション値 xhigh を継承し逆効果
- 差分レビュー役への plan-deviation 観点: 計画が入力に無く空振り、正当な逸脱で振動
- 0 回 skill の説明文書き直しと再計測: 運用者の判定は需要の有無。180 日クロックを汚す
- practices への数値・URL・銘柄名の直書き: 前例なし、追試で覆ると波及層の保守
- principles の改訂: 単一調査での昇格は原則 06 に反する
- 型付き権限分離の自作: ハーネスの返却枠付けと tool 制限が担う
- planner・generator・evaluator の 3 役常設: 既存チェーンと組み込み Plan で足りる
- 今すぐ主モデルを切り替える: 変数を 1 つずつ

## 覆す決定

なし(索引の effort 行は決定本体を保ち、期限付き例外として注記)

## 影響ファイル

`adapters/claude-code/user-level/{settings.json.template,commands/team.md,commands/update-check.md}`、`adapters/claude-code/subagents/security-auditor.md`、`tools/doctor.sh`、`practices/{session-handoff,delegation-orchestration,iterative-review,model-selection,skill-design-guide}.md`、`meta/{decisions/README.md,CHANGELOG.md,TODO-for-v0.2.md}`
