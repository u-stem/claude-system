---
name: adr-writing
description: ADR(意思決定記録)を起票・更新する
---

# ADR Writing

意思決定記録(Architecture Decision Record)を起票・更新する skill。
具体運用は [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md)、根拠原則は [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md)、テンプレートは [`adapters/claude-code/project-fragments/adr-template.md`](~/ws/claude-system/adapters/claude-code/project-fragments/adr-template.md) を参照。

## 目的

「3 年後の自分に聞かれて答えに窮する判断」を、決定索引(1 画面で読める現在形の一覧)と短い ADR(60 行以内の記録)に分けて残す。判断の物語は ADR に書かず、経緯は変更履歴に残す。

## いつ発動するか

- 設定や共通指示に落とし込めない方針判断(トレードオフの比較、機械的ガードレールの新設・撤去、セキュリティ・プライバシー方針の変更、破壊的書き換え)をするとき
- 決定索引にある既存の決定を覆すとき

逆に、単純なバグ修正・typo 直し・能力単位の追加・設定変更で根拠が実物の隣の注記に収まる場合は起票しない。

## 手順

1. **決定索引を先に更新する**: claude-system 自身の判断なら [`meta/decisions/README.md`](~/ws/claude-system/meta/decisions/README.md)、他プロジェクトの判断ならそのプロジェクトの `docs/adr/README.md` に、決定・根拠・再評価トリガー・退けた案・出典を 1 行で書く。1 行に収まらない判断だけ次へ進む
2. **`tools/new-adr.sh <slug>` で採番する**(プロジェクトの `docs/adr/` 配下に採番・テンプレ展開。claude-system 自身の `meta/decisions/` は同じ連番規則で手動作成する)。**欠番禁止**、撤回しても番号は残す
3. **5 項目を 60 行以内で埋める**: 決定(何を、条件があれば条件も)/ 根拠(3 行以内、測った事実や比較した数値)/ 再評価トリガー(何が起きたら見直すか、「なし」も明記)/ 不採用と理由(1 案 1 行)/ 影響ファイル
4. **既存決定を覆すなら名指しする**: 決定索引の該当行と、覆す旧 ADR の番号を新 ADR の「覆す決定」欄に書く。**旧 ADR は編集しない**(凍結。現行状態は索引が表す)
5. **経緯は変更履歴へ**: 検証の顛末・途中の誤読と訂正・走査結果の表は ADR に書かず、[`meta/CHANGELOG.md`](~/ws/claude-system/meta/CHANGELOG.md)(または相当のプロジェクト変更履歴)に 40 行以内の 1 エントリとして残す
6. **将来の実行の約束は同じコミットで TODO へ転記する**: ADR や索引に「後でやる」と書いただけの約束は履行されない。転記しない約束は履行されないものとして扱う
7. **意思決定者の識別子規約を守る**: 本名・新規連絡先を書かない(ADR 0001)、Public→Private リンクを書かない(ADR 0002)

## チェックリスト

- [ ] 決定索引を先に更新した(1 行に収まらない判断だけ ADR に進んだ)
- [ ] 連番に欠番がない、ファイル名が `NNNN-kebab-case-title.md` 形式
- [ ] Status は `Proposed` / `Accepted` / `Rejected` / `Withdrawn` のいずれか
- [ ] 決定 / 根拠 / 再評価トリガー / 不採用と理由 / 影響ファイルの 5 項目が 60 行以内で埋まっている
- [ ] 既存決定を覆すなら、索引の該当行と旧 ADR 番号を名指しし、旧 ADR 本体は編集していない
- [ ] 検証の経緯・訂正の記録を ADR ではなく変更履歴に書いた
- [ ] 将来の約束を同じコミットで TODO へ転記した
- [ ] Decider 欄に本名・新規連絡先が含まれていない(ADR 0001)、Public→Private リンクが含まれていない(ADR 0002)
- [ ] コミットメッセージに ADR 番号を含めた(`docs(meta): add ADR NNNN for ...`)

## 関連

- [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md) — ADR 運用の抽象手順(索引が先、ADR は例外)
- [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) — 根拠原則
- [`adapters/claude-code/project-fragments/adr-template.md`](~/ws/claude-system/adapters/claude-code/project-fragments/adr-template.md) — 5 項目テンプレートと使い方
- [`meta/decisions/README.md`](~/ws/claude-system/meta/decisions/README.md) — claude-system 自身の決定索引、連番ルール、Status 語彙
- [`meta/decisions/0001-anonymity-policy.md`](~/ws/claude-system/meta/decisions/0001-anonymity-policy.md) — 識別子規約(Decider 欄に影響)
- [`meta/decisions/0002-public-private-boundary.md`](~/ws/claude-system/meta/decisions/0002-public-private-boundary.md) — Public→Private リンクの制約
- [`~/ws/claude-system/tools/new-adr.sh`](~/ws/claude-system/tools/new-adr.sh) — プロジェクト内 ADR の採番スクリプト
