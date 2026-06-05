---
name: review-loop
description: レビュー→修正→レビューの反復ループ(立て直し既定 + 修正確認の継続 + 最終ゲート)
---

対象を反復レビューで収束させる: $ARGUMENTS

単発の強いレビューに賭けず、安定して完走する委譲先を反復させ、収束で品質を担保する。
設計と判断基準は [`practices/iterative-review.md`](../../../../practices/iterative-review.md) に従う(本コマンドはその Claude Code 実装)。

## いつこのコマンドを使うか

- 変更が設計級(境界・契約の変更、セキュリティ感受面、100 行超 / 5 ファイル超)
- 「問題なし」が再確認されず下流に流れるのを避けたいレビュー

ごく小さく可逆な差分は `/review`(単発)で足りる。反復は固定費(往復・収束判定)が見合うときだけ。

## 委譲先と水準(校正済み)

| 局面 | 担当 | model / effort | 理由 |
|------|------|----------------|------|
| ループ本体のレビュー | `code-reviewer` subagent を**毎ラウンド新規起動**(B) | sonnet / high | 最多用ゆえ安定完走を優先。opus+xhigh の中断(parse-error)露出を避ける |
| 修正の解消確認 | 直前ラウンドの `code-reviewer` を **SendMessage で継続**(A) | 同上(継続) | 「指摘 X はこの修正で解消したか / 回帰がないか」の追跡 |
| 修正の適用 | メイン(または `refactor-planner` で方針立案) | — | レビューと修正の担当を分け独立性を保つ |
| 最終ゲート | `security-auditor` subagent を新規起動(B + 強い水準) | opus / high | 収束後の小さくなった差分に一度だけ。能力由来の盲点を掬う |

セキュリティが主目的の低頻度・致命的レビューは、反復より単発の天井が効くため最初から `security-auditor`(opus/high)を当ててよい。

## 手順

1. **収束条件とラウンド上限を先に宣言する**
   - 収束 = 「新規の actionable な指摘が出ない」ラウンドに到達
   - 上限 = 既定 3 ラウンド(振動・発散を止める backstop)。宣言してから回す。

2. **各ラウンド(B = 立て直し)**
   - `code-reviewer` subagent を**新規**に起動する(前ラウンドのインスタンスは使わない)。
   - 渡すもの: 現在の差分 + 「決着済みメモ」(前ラウンドで意図的に残した論点の 1〜2 行)。
   - 戻りは**重大度別の指摘リストのみ**(探索ログ・全文をメインに載せない / [`delegation-orchestration`](../../../../practices/delegation-orchestration.md) 参照)。

3. **修正を適用する**
   - 重大 → 必須修正。軽微 → 方針判断。修正はメインで行い、設計変更を伴うなら `refactor-planner`(opus/high)で先に方針を立てる。

4. **修正の解消確認だけ継続(A)**
   - 特定の指摘の追跡が要る一点に限り、そのラウンドの `code-reviewer` を `SendMessage` で継続させ「指摘 X は解消したか / 回帰はないか」を問う。
   - 一般レビューは継続させない(アンカリングと文脈肥大を避ける)。

5. **収束判定**
   - 新規 actionable がゼロ → 次へ。出続けるなら上限まで 2 へ戻る。上限到達時は残課題を明示して止める。

6. **最終ゲート(B + 強い水準)**
   - 収束後の差分に `security-auditor`(opus/high)を**一度だけ**新規起動。
   - 反復が構造的に拾えない能力由来の盲点をここで掬う。対象が小さいので強い水準を一度使うコストは小さい。

7. **報告**
   - ラウンド数 / 各ラウンドの指摘数推移 / 最終ゲートの結果 / 残課題を要約。

## 多数ファイル・並列化したいとき(Workflow オプション)

差分が多数ファイルに跨り並列で回したい場合は Workflow で pipeline 化できる。骨子:

- `pipeline(files, review, verify)` で各ファイルを独立にレビュー→確認。各 stage の `agent()` に `agentType: 'code-reviewer'`(sonnet/high)を指定。
- ループ本体は毎回新規 `agent()`(B)、修正確認のみ `SendMessage` 相当の継続を使う。
- 全ファイル収束後、まとめてクリーンになった差分に最終ゲート 1 回(`agentType: 'security-auditor'`, opus/high)。
- 収束は「K ラウンド連続で新規指摘ゼロ」(loop-until-dry)で判定し、上限ラウンドで打ち切る。

Workflow はトークン消費が大きいため、ユーザーが明示的にオプトインした場合のみ起動する。通常は本コマンドの逐次手順で足りる。

## アンチパターン(practice より)

- 強い単発に全部賭ける(完走率を無視 → 中断で「未完了の沈黙」)
- 同一担当を延々継続(アンカリングで「問題なし」追認、文脈肥大で中断)
- 立て直しだけで盲点も消えると思う(同水準の立て直しは能力由来の盲点を温存 → 最終ゲートの多様性が要る)
- 収束条件を決めずに回す(発散・振動)
- ハンドオフなしで立て直す(決着済みを毎ラウンド蒸し返す)

## 関連

- practice: [`iterative-review`](../../../../practices/iterative-review.md)(本コマンドの設計元)
- practice: [`model-selection`](../../../../practices/model-selection.md)(水準配分)
- command: `/review`(単発簡易レビュー)
- subagent: `code-reviewer`(sonnet/high) / `security-auditor`(opus/high) / `refactor-planner`(opus/high)
- ADR: [`0013-role-based-effort-modulation`](../../../../meta/decisions/0013-role-based-effort-modulation.md)
