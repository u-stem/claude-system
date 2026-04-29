# ADR 0001: Anonymity Policy for claude-system Outputs

- **Status**: Accepted
- **Date**: 2026-04-26
- **Decider**: プロジェクトオーナー

## Context

Phase 0 のスケルトン構築中、Claude Code がグローバル `git config` および会話コンテキスト(ユーザの呼称)から個人特定情報を取得し、claude-system のアウトプット(README, CLAUDE.md, LICENSE)および commit author に焼き込もうとした。

具体的には以下の事象が発生した:

1. **README/CLAUDE.md/LICENSE の初版に個人呼称が含まれた**
   - 例: 「<本人呼称> のための個人開発システム」「<本人呼称> の AI 協働開発体験」
2. **グローバル `git config` の `user.name` / `user.email` が暗黙に commit author として使われそうになった**
   - `user.name = <github-handle>`(GitHub handle が global git config に設定されている)
   - `user.email = <personal-email>`(personal email が global git config に設定されている)

オーナーからのフィードバック「個人呼称は個人情報にあたります、含めないようにします」を受け、Phase 0 セッション中に即時対応:

- 全ファイルから個人呼称を除去
- commit author を匿名暫定値 (`claude-system <claude-system@users.noreply.github.com>`) に切り替え

その後オーナー自身が追加判断として、過去の Public リポジトリ複数件で既に personal email が commit author として露出済みであることを確認し、claude-system だけ noreply 化しても防御線として機能しないため、例外的に personal email の commit author 使用を許容することとした(同時に GitHub handle を LICENSE Copyright holder にも採用)。

## Decision

claude-system のすべてのアウトプットにおいて、**オーナーが明示的に許可した識別子のみ** を使用する。

> **具体実装(literal を書くか書かないか)は [ADR 0006](./0006-no-user-identifiers-in-system.md) を参照。**
> 本 ADR は「個人特定情報を出さない」原則を、ADR 0006 は「ユーザー識別子は claude-system に書かない」具体実装をそれぞれ規定する。

### 識別子の取り扱い

| 識別子 | 取り扱い | 補足 |
|--------|----------|------|
| 本名・個人呼称 | **不許可** | リポジトリ内のいかなるファイル・コミットメッセージ・コード片にも含めない |
| GitHub handle | **literal は不許可、URL 内の自動参照と LICENSE Copyright holder のみ例外**(ADR 0006) | LICENSE / commit author / `https://github.com/<handle>/<repo>` の URL では使うが、規範文書の例示・テンプレートのプレースホルダ説明では `<your-handle>` のような抽象表記を使う |
| Personal email | **literal を書かない**(ADR 0006 で「条件付き許容」を「書かない」に厳格化) | commit author は OS / git レベル(global `git config`)で自動付与される。リポジトリ内のファイルに literal を書く必然性はない |
| 新規の連絡先・住所・電話番号 等 | **不許可** | 一切含めない |

### 操作上のガードレール

- 新規ファイル / 新規 commit メッセージ作成前に「本名・呼称が含まれていないか」を grep で確認することを推奨
- Phase 7b の hooks / CI で機械的検出を組む(`gitleaks` の custom rule か別 lint で本名・呼称を検出)
- claude-system のローカル `git config` では `user.name` / `user.email` を override しない(global を継承する)。これにより Phase 7b でグローバル方針を変更すれば全リポジトリに伝播する

### 例外運用

- 例外を許容する場合、本 ADR(または後続 ADR)に **理由を明示的に記録** する
- 「既に他所で露出済み」を理由とする場合は、露出元を列挙する(本文 Context 参照)

## Consequences

### Positive

- 個人情報の露出範囲が明確化され、なし崩しに増えない
- 例外の根拠が記録されているため、将来の判断ブレが減る
- Phase 7b で機械的ガードレールを組む際の仕様が確定する

### Negative

- 新規ファイル作成時に確認の手間が一段増える
- ADR を超える例外が発生した場合は ADR 追加が必要(運用負荷)

### Neutral

- LICENSE の Copyright holder は GitHub handle を採用(本 ADR 採択と同時に決定、初期コミット `42caea3` に取り込み済み)。ADR 0006 でも例外として明示的に許容
- commit author の `user.name` / `user.email` は global git config の値を継承する設計とし、claude-system のローカル設定では override しない

## Related

- Phase 0 完了報告(2026-04-26)
- `meta/migration-from-claude-settings.md`
- `adapters/claude-code/user-level/CLAUDE.md` — Phase 3 で本 ADR を user-level CLAUDE.md に取り込み済み
- [ADR 0006](./0006-no-user-identifiers-in-system.md) — 本 ADR の具体実装。literal を書かない方針
