# ADR テンプレート

プロジェクト内 `docs/adr/NNNN-<slug>.md` にコピーして使う ADR の標準テンプレート。
詳細運用は `~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md` 参照。

---

```markdown
# ADR NNNN: <短いタイトル>

- **Status**: Proposed | Accepted | Rejected | Withdrawn | Deprecated | Superseded by NNNN
- **Date**: YYYY-MM-DD
- **Decider**: <意思決定者(本名・新規連絡先は書かない、ADR 0001 準拠)>

## Context

なぜこの判断が必要になったか。背景・制約・関係者・代替案の事情を、後から読んでも経緯が辿れるように書く。

- 何が起きていたか
- どの制約があったか(技術 / 期日 / 互換性 / 既存設計)
- 誰が関与したか(役割で記述、本名は書かない)
- 検討すべきだった代替案の事情

## Decision

何を決めたか。曖昧さなく記述する。条件分岐があるなら表で示す。

(可能なら図 / 表 / コード片で具体化)

## Alternatives Considered(任意、複雑な決定では推奨)

| 代替案 | 採否 | 理由 |
|--------|------|------|
| 案 A | 不採用 | <なぜ捨てたか> |
| 案 B | 採用 | <なぜ選んだか> |
| 案 C | 不採用 | <なぜ捨てたか> |

## Consequences

決定の結果として起きること:

### Positive

- 良くなる点

### Negative

- 副作用 / コスト

### Neutral

- 中立的な影響、注意点

## Implementation Notes(任意)

実装上のメモ。コミット ID、関連 PR、デプロイ計画等。

## Related

- 関連 ADR(番号で参照、例: `[ADR 0001](./0001-anonymity-policy.md)`)
- 関連 Phase / コミット / ファイル
- 外部参照(必要なら URL。Public→Private リンクは禁止、ADR 0002 準拠)
```

## 使い方

1. プロジェクトの `docs/adr/` ディレクトリで最大連番 + 1 を確認
2. 上のテンプレートを `docs/adr/NNNN-<kebab-case-slug>.md` にコピー
3. 不要な任意セクション(Alternatives Considered / Implementation Notes)は削除
4. `docs/adr/README.md` の表に新 ADR の行を追加(ある場合)
5. ADR 0001 / 0002 遵守(本名 / 新規連絡先 / Public→Private URL を含めない)

## チェックリスト

- [ ] 連番に欠番がない
- [ ] Status が現状を正確に反映している
- [ ] Context / Decision / Consequences / Related が埋まっている
- [ ] 本名・personal email literal が含まれていない
- [ ] Public→Private リンクが含まれていない
- [ ] 既存 ADR を覆すなら旧 ADR の Status を `Superseded by NNNN` に更新済み

## 関連

- [`adapters/claude-code/user-level/skills/adr-writing/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md) — 起票手順
- [`practices/adr-workflow.md`](~/ws/claude-system/practices/adr-workflow.md) — 抽象運用
- [`meta/decisions/README.md`](~/ws/claude-system/meta/decisions/README.md) — claude-system 自身の ADR 規約(参考形式)
