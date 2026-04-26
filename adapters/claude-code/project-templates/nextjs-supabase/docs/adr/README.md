# Architecture Decision Records (ADR)

{{PROJECT_NAME}} の意思決定記録。

「後から経緯を辿りたくなる判断」のみをここに記録する。
日々の細かい変更は git history / CHANGELOG.md / commit メッセージで足りる。

## 連番ルール

- ファイル名: `NNNN-kebab-case-title.md`(4 桁ゼロ埋め、ハイフン区切りの英小文字タイトル)
- 番号は意思決定が確定した順に**連続して**採番する
- **欠番禁止**(撤回しても番号は残し、Status を `Withdrawn` 等にする)
- 旧 ADR を覆す場合、新 ADR を採番し前 ADR の Status を `Superseded by NNNN` にする

## Status の語彙

| Status | 意味 |
|--------|------|
| `Proposed` | 提案中、まだ採択されていない |
| `Accepted` | 採択済み、現に運用されている |
| `Rejected` | 提案されたが採択されなかった |
| `Withdrawn` | 取り下げた |
| `Deprecated` | 採択時の前提が崩れたため非推奨 |
| `Superseded by NNNN` | 後続の ADR `NNNN` で置き換えられた |

## 必須セクション

各 ADR は以下のセクションを最低限備える。雛形は `~/ws/claude-system/adapters/claude-code/project-fragments/adr-template.md` を参照:

- Context(なぜ必要か)
- Decision(何を決めたか)
- Consequences(Positive / Negative / Neutral)
- Related(関連 ADR / Phase / コミット / ファイル)

任意: Alternatives Considered / Implementation Notes

## 既存 ADR

| 番号 | タイトル | Status | 概要 |
|------|----------|--------|------|
| [0001](./0001-architecture-overview.md) | Architecture Overview | Accepted | {{PROJECT_NAME}} の初期アーキテクチャ判断 |

## ADR を書くタイミング

- アーキテクチャの主要判断(フレームワーク採用 / 認証方式 / DB 設計の方針 等)
- 機械的ガードレール(hooks / CI / lint ルール)を新設・撤去するとき
- セキュリティ・プライバシー方針を変更するとき
- 既存ファイル / コミットの破壊的書き換えを伴う方針転換を行うとき
- 「なぜこうしなかったのか」を将来の自分が問うときに、記憶では答えられないと予想されるとき

逆に以下では書かない:

- 単純なバグ修正 / typo / 文言調整
- 単発の機能追加(commit メッセージで十分)
- リファクタリング(必要なら本文の `Implementation Notes` で言及)

## 関連

- 起票手順: `~/ws/claude-system/adapters/claude-code/user-level/skills/adr-writing/SKILL.md`
- 抽象運用: `~/ws/claude-system/practices/adr-workflow.md`
- 雛形: `~/ws/claude-system/adapters/claude-code/project-fragments/adr-template.md`
- claude-system 自身の ADR(参考形式): `~/ws/claude-system/meta/decisions/README.md`
