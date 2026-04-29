# ADR 0006: No User Identifiers Inside the System

- **Status**: Accepted
- **Date**: 2026-04-29
- **Decider**: プロジェクトオーナー

## Context

v0.1.0-rc1 のレビュー対応で、`.gitleaks.toml` に owner email literal が含まれている件を「ADR 0001 違反」として整理した結果、以下の対応が連鎖的に発生した:

- `.gitleaks.toml` の `paths` allowlist に `meta/decisions/0001-anonymity-policy\.md` を追加(literal を含むファイルそのものを scan 対象から外す)
- `meta/multi-device-setup.md` の chezmoi 例で email literal を `<your-...>` プレースホルダ化
- `adapters/.../hooks/subagent-stop-audit.sh` に `SUBAGENT_AUDIT_KNOWN_EMAILS` 環境変数を導入し、許容アドレス除外ロジックを足した

これは「適用範囲を明確化」する形の対応だが、本質を取り逃がしていた。

オーナーからの指摘は次のとおり:

> そもそもユーザー名や email を書く場面が claude-system にあること自体が異常では?

これは正しい。本来 claude-system は:

- **LICENSE**: 抽象的な著作権表記または GitHub handle 程度で十分(本名は不要)
- **commit author**: `git config` (global) で自動設定されるもの。リポジトリ内のファイルに literal を書く必然性はない
- **`multi-device-setup.md` の chezmoi 例**: そもそもサンプルに本人 email を埋め込む設計が悪い
- **`.gitleaks.toml`**: literal を allowlist する必要があるのは、それが文書内に書かれているから。書かなければ allowlist も不要

つまり、ADR 0001 の「個人特定情報を新たに露出させない」原則の **具体実装** として「ユーザー識別子そのものを claude-system に書かない」を確立すべきだった。書かれていないものは検出されないし、scan を緩める必要も、許容アドレス除外を実装する必要もない。

検出ロジックや allowlist は「仮に混入したら検出する」最終防衛線として残すが、**第一防衛線は『そもそも書かない』** 方が筋が良い。

## Decision

claude-system のすべての追跡ファイル(`.gitignore` 対象を除く)では、以下の literal を書かない:

| 種別 | 例 | 取り扱い |
|---|---|---|
| 本名・本人呼称 | (略) | **不許可**(変更なし、ADR 0001 を継承) |
| 個人 email literal | `<personal>@<domain>` | **不許可**(ADR 0001 では条件付き許容としていたが、本 ADR で「書かない」に厳格化) |
| GitHub handle literal | `<handle>` | **不許可**。例外あり(下記) |
| 新規連絡先 / 住所 / 電話番号 | (略) | **不許可**(変更なし) |

### handle literal の例外

以下は handle literal を許容する(書く必然性がある or 書かないと機能しない):

1. **LICENSE の Copyright holder**: 法的属性を持つ表記。`u-stem` などの handle 表記、または `The claude-system authors` 等の抽象表記のいずれも採用可。本リポジトリでは現状 `u-stem` を維持(過去の判断と整合)
2. **GitHub URL の path 部**: `https://github.com/<handle>/claude-system.git` 形式の正規リポジトリ参照。clone コマンド・`gh --repo` 引数・chezmoi 設定例などで使われる。これは git の機能として書き込まれる literal で、人為的な「個人特定情報の露出」とは性質が違う
3. **コミット履歴・git tag の Tagger 等**: ローカル `git config` (global) を継承する設計のため、claude-system のソース管理外。本 ADR の対象外
4. **手順書・サンプルコード内の明示的なプレースホルダ**: `<your-github-handle>`, `<your-email>` のような形。これは literal ではなく「読者がここに自分の値を入れる」というシグネチャなので許容

### email literal の例外

なし。ADR 0001 では「commit author 既露出のため例外的に literal 許容」としていたが、本 ADR で「書かない」に統一する。commit author は OS / git レベルの設定であり、claude-system 内のファイルに literal を書く必然性がない。

### 既存文書(ADR 0001 など)に書かれている literal の扱い

ADR 0001 には現に email / handle の literal が書かれている。これらは「規範文書だから経緯記録として必要」ではなく、抽象例(`<personal-email>`, `<your-handle>`)に置換しても規範性は損なわれない。本 ADR の採択と同時に置換する。

ADR 0001 自身を `.gitleaks.toml` の `paths` allowlist で除外していた処理も、literal が消えれば不要になるため撤回する。

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|---|---|---|
| **rc1 の方針を維持**(allowlist + paths 除外で適用範囲を明確化) | 不採用 | literal が書かれているからこそ allowlist が必要になる構造。第二防衛線(検出)の整備で済ませると「書く / 書かない」の判断軸が曖昧化する。本質的な対策にならない |
| **ADR 0001 を改訂して厳格化**(別 ADR を起こさない) | 不採用 | ADR 0001 は「個人特定情報を出さない」原則。本 ADR は「ユーザー識別子は書かない」具体実装。粒度が違うため別 ADR にして、原則と実装を階層化する方が後から辿りやすい(ADR 0004 の総括 ADR と同じ構造) |
| **handle literal も完全禁止**(LICENSE もすべて抽象化) | 不採用 | LICENSE の Copyright holder は法的・社会的に「誰が」を示す欄であり、抽象表記より handle の方が後から検証可能。例外運用の方が実害が小さい |
| **commit author 用に email literal を維持**(rc1 の Decision 表のまま) | 不採用 | commit author は global git config で自動付与される。リポジトリ内のファイルに literal を書く必然性は実はゼロ。ADR 0001 の「条件付き許容」表記は、当時の判断としては妥当だったが、現在は不要 |
| **`.gitleaks.toml` の paths 除外で済ます**(literal は維持) | 不採用 | rc1 の方針そのもの。literal が書かれている事実は変わらないため、第三者が ADR を読む際に literal を目にする。本 ADR の精神に反する |

## Consequences

### Positive

- **第一防衛線が明確化**: 「書かない」が運用ルールになり、検出 / allowlist は最終防衛線として位置付けが整理される
- **`.gitleaks.toml` の簡素化**: ADR 0001 を `paths` 除外する設定が不要になり、設定ファイル自体に literal も書かない
- **`subagent-stop-audit.sh` の単純化**: `SUBAGENT_AUDIT_KNOWN_EMAILS` の環境変数 + 許容アドレス除外ロジックが不要になる。検出されたら本当に「混入した literal」なので、log もノイズではなく実害シグナルになる
- **ADR 0001 と本 ADR の階層**: ADR 0001 は「個人特定情報を新たに露出させない」原則、本 ADR は「ユーザー識別子は書かない」実装。粒度が分離される

### Negative

- **ADR 0001 内の経緯記述が抽象化される**: 「過去の Public リポジトリ X / Y / Z で email が露出済み」のような具体記録が `<personal-email>` プレースホルダ化される。経緯の生々しさは下がるが、規範性は維持できる
- **commit author を「許容」から「ファイル内に書かない」へ厳格化**: 既存の git history は変わらないので実害なし。新規ファイル作成時の判断軸がやや厳しくなる
- **handle literal の例外運用にコスト**: 「URL 内の自動参照は OK」「規範文書の例示は NG」の境界判断が必要になる。本 ADR の表で例示しているが、判断に迷うケースが今後出れば追記する

### Neutral

- **既存 commit / git tag に含まれる identity は本 ADR 採択時点で残る**: 過去のコミット author / tagger の値はリライトしない(force push を main 上で行わないため)。これは ADR 0001 の Public 露出許容の論理と整合
- **`u-stem`(handle)を LICENSE で維持する判断**: 本 ADR 採択と同時に「The claude-system authors」のような抽象表記に切り替える選択肢もあったが、現状維持(過去判断との整合性、後方互換性)
- **本人 email の git config (global) は触らない**: OS / git レベルの設定であり、claude-system のソース管理外

## Related

- [ADR 0001](./0001-anonymity-policy.md): Anonymity Policy(本 ADR の上位原則)
- [ADR 0002](./0002-public-private-boundary.md): Public/Private Boundary(本 ADR の関連原則、Public な claude-system に Private リソースを書かない方針と整合)
- [ADR 0004](./0004-system-architecture-summary.md): System Architecture Summary(本 ADR の Public 運用 + 機密情報自動排除と整合)
- [ADR 0005](./0005-bootstrap-completion-and-deferral.md): rc1 リリース候補化の経緯(本 ADR は rc1 → rc2 への動機)
- [`.gitleaks.toml`](../../.gitleaks.toml) — 本 ADR 採択により ADR 0001 の paths 除外を撤回
- [`adapters/claude-code/user-level/hooks/subagent-stop-audit.sh`](../../adapters/claude-code/user-level/hooks/subagent-stop-audit.sh) — 本 ADR 採択により `SUBAGENT_AUDIT_KNOWN_EMAILS` を撤去
