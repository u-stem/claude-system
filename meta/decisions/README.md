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
| `0001-anonymity-policy.md` | 第 1 号 ADR、匿名性ポリシー |
| `0002-monorepo-fragment-strategy.md` | 第 2 号 ADR、monorepo fragment 戦略 |
| `0042-supersede-anonymity-policy.md` | 0001 を上書きする新方針(Status は Accepted、0001 の Status は Superseded by 0042) |

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
