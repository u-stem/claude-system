---
name: adr-writing
description: ADR(意思決定記録)を起票・更新する
recommended_model: opus
---

# ADR Writing

意思決定記録(Architecture Decision Record)を `~/ws/claude-system/meta/decisions/` 配下に起票・更新する skill。
具体運用は [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md)、根拠原則は [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) を参照。

## 目的

「3 年後の自分に聞かれて答えに窮する判断」を、後から経緯を辿れる形で保存する。

## いつ発動するか

- 不変層(`principles/`)に手を入れるとき
- 機械的ガードレール(hooks / CI / permissions / lint ルール)を新設・撤去するとき
- セキュリティ・プライバシー方針を変更するとき
- 既存ファイル群やコミット履歴の破壊的書き換えを行うとき
- 「なぜこうしなかったのか」を将来の自分が問うときに記憶では答えられないと予想されるとき

逆に、単純なバグ修正・typo 直し・新 skill 追加・軽微な文言調整では起票しない。

## 手順

1. **連番採番**: 直近 ADR 番号 + 1。`ls ~/ws/claude-system/meta/decisions/[0-9]*.md | tail -1` で確認。**欠番禁止**、撤回しても番号は残す
2. **ファイル名決定**: `NNNN-kebab-case-title.md`(4 桁ゼロ埋め、英小文字、ハイフン区切り)
3. **Status を初期値で書く**: 即決なら `Accepted`、議論を残したい場合は `Proposed`
4. **必須セクションを埋める**:
   - `Context`: なぜこの判断が必要になったか(背景・制約・関係者・代替案の事情)
   - `Decision`: 何を決めたか(曖昧さなく記述。条件分岐があるなら表で示す)
   - `Consequences`: Positive / Negative / Neutral の 3 区分
   - `Related`: 関連 ADR(番号で参照)、関連 Phase / コミット / ファイル
5. **任意セクション**: 複雑な決定では `Alternatives Considered`(検討した他案)、`Implementation Notes`(実装メモ)を追加してよい
6. **意思決定者**: ADR 0001 の識別子規約に従う(本名・新規連絡先は書かない、`プロジェクトオーナー` 等の抽象語または `u-stem`)
7. **ADR 0002 遵守**: Public 文書から Private リソース(URL / git remote)へのリンクを書かない。旧 spec に言及するときは「Private リソースで参照不能」と明記
8. **既存 ADR との整合**: 前の決定を覆す場合、旧 ADR の Status を `Superseded by NNNN` に更新し、本 ADR 末尾の Related で参照する
9. **`meta/decisions/README.md` の表に追記**: 番号・タイトル・Status・短い概要を 1 行で

## チェックリスト

- [ ] 連番に欠番がない(`ls meta/decisions/[0-9]*.md` の番号が連続している)
- [ ] ファイル名が `NNNN-kebab-case-title.md` 形式
- [ ] Status は `Proposed` / `Accepted` / `Rejected` / `Withdrawn` / `Deprecated` / `Superseded by NNNN` のいずれか
- [ ] Context / Decision / Consequences / Related の 4 セクションすべて埋まっている
- [ ] Decider 欄に本名・新規連絡先が含まれていない(ADR 0001)
- [ ] Public→Private リンク(URL / git remote)が含まれていない(ADR 0002)
- [ ] 既存 ADR を覆すなら旧 ADR の Status を更新済み
- [ ] `meta/decisions/README.md` の表に新 ADR の行を追加した
- [ ] コミットメッセージに ADR 番号を含めた(`docs(meta): add ADR NNNN for ...`)

## 関連

- [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md) — ADR 運用の抽象手順
- [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) — 根拠原則
- [`meta/decisions/README.md`](~/ws/claude-system/meta/decisions/README.md) — 連番ルール、Status 語彙、必須セクション仕様
- [`meta/decisions/0001-anonymity-policy.md`](~/ws/claude-system/meta/decisions/0001-anonymity-policy.md) — 識別子規約(Decider 欄に影響)
- [`meta/decisions/0002-public-private-boundary.md`](~/ws/claude-system/meta/decisions/0002-public-private-boundary.md) — Related 欄に影響
