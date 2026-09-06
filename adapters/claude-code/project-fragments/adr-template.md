# ADR テンプレート

プロジェクト内 `docs/adr/NNNN-<slug>.md` にコピーして使う決定記録のテンプレート(`tools/new-adr.sh` はこの fenced block を抜き出す)。
運用は `~/ws/claude-system/practices/adr-workflow.md`(索引が先、ADR は例外、根拠は実物の隣)に従う。

---

```markdown
# ADR NNNN: <短いタイトル>

- **Status**: Proposed | Accepted | Rejected | Withdrawn
- **Date**: YYYY-MM-DD
- **Decider**: <意思決定者(本名・新規連絡先は書かない、ADR 0001 準拠)>

## 決定

何を決めたか。番号付きで、条件があれば条件も 1 行に。

## 根拠

3 行以内。測った事実、参照した一次資料、比較した数値。

## 再評価トリガー

何が起きたらこの決定を見直すか。「なし」なら明記する。

## 不採用と理由

- <案>: <3〜6 語の理由>

## 覆す決定(任意)

索引の該当行と旧 ADR 番号。旧 ADR は編集しない。

## 影響ファイル

変更したファイルとディレクトリ。
```

## 使い方

1. `docs/adr/README.md`(決定索引)に決定・根拠・再評価トリガー・退けた案を 1 行で追加する。1 行に収まらない判断だけ ADR に進む
2. `tools/new-adr.sh <slug>` で採番(欠番禁止)し、上の 5 項目を 60 行以内で埋める
3. 経緯(検証の顛末、途中の訂正)は ADR に書かず変更履歴に 1 エントリ残す
4. 将来の実行を約束する行は同じコミットで TODO ファイルへ転記する
5. ADR 0001 / 0002 遵守(本名 / 新規連絡先 / Public→Private URL を含めない)

## チェックリスト

- [ ] 索引の該当行を先に更新した
- [ ] 60 行以内、5 項目が埋まっている
- [ ] 退けた案に理由がある
- [ ] 覆す決定があれば番号を名指しし、旧 ADR は編集していない
- [ ] 本名・personal email literal・Public→Private リンクが含まれていない

## 関連

- [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md) — 運用規則
- [`meta/decisions/README.md`](~/ws/claude-system/meta/decisions/README.md) — claude-system 自身の決定索引(参考形式)
