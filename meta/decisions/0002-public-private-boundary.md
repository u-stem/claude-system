# ADR 0002: Public/Private Boundary in claude-system

- **Status**: Accepted
- **Date**: 2026-04-26
- **Decider**: プロジェクトオーナー

## Context

claude-system は **Public リポジトリ** として構築される(LICENSE: MIT)。一方、その前身である旧 `claude-settings` リポジトリは **Private** として保存され、`projects/`、`telemetry/`、`backups/`、`history.jsonl` 等の Claude Code ランタイム生成物にも個人のセッション履歴・操作ログが含まれる。

Phase 0 / Phase 0.5 で複数の場面で「新 Public 文書から旧 Private リソースを参照したくなる」局面が発生した:

- `meta/migration-from-claude-settings.md` で旧リポジトリの git remote(`git@github.com:<github-user>/claude-settings.git`)を記載していた
- `meta/CHANGELOG.md` 冒頭に「旧 CHANGELOG はリポジトリリンク先を参照」と書く案が浮上した
- 旧 `docs/superpowers/specs/plans/` 群の設計書を「参照しやすいよう新システムに転記する」案が浮上した

これらは一見便利だが、以下の問題がある:

1. **リンク先にアクセスできない**: 公開された Public リポジトリを見た第三者は Private リソースに到達できない(GitHub 401/404)。リンクは事実上常に切れている
2. **境界の曖昧化**: Public と Private を行き来する記述が増えると、新システムが「Private の続き」に見え、新リポジトリの独立性が損なわれる
3. **個人情報の再露出**: git remote 表記やリポジトリ名は GitHub handle・ホスト名を含み、ADR 0001 の「アウトプットに個人特定情報を新たに露出させない」原則と擦り合わない

これらは個別判断で都度避けることもできるが、判断を都度委ねるとミスが累積する。明文化された ADR で機械的に防ぐのが妥当。

## Decision

claude-system のすべてのアウトプット(README, ADR, ドキュメント, コミットメッセージ, コード片)において、**Public から Private リソースへの直接リンクを作らない**。

### 具体ルール

| 対象 | ルール |
|------|--------|
| 旧 claude-settings リポジトリの URL / git remote | **記述しない** |
| 旧 claude-settings 配下のファイルパスを引用するとき | パス自体は OK(例: `~/ws/claude-settings/hooks/...`)、ただし「GitHub 上で見るには ... を開く」のような誘導は書かない |
| 旧設定の存在に言及する必要があるとき | 「別途 Private リポジトリにて永続保管」のような **事実のみの記載** に留める。具体名・URL を書かない |
| 旧 spec / plan 等の設計記録の **転記** | 行わない(`docs/superpowers/specs/plans` 群は新システムに含めない、Phase 0.5 で確認済み) |
| 旧設計から **昇華された概念** を新システム側で書くとき | 出典は「旧 claude-settings から取り込み」のような抽象的記述に留め、具体ファイル名のみ書く(URL は書かない) |
| `~/ws/<別 private プロジェクト>/` 配下 | 同様、ローカルパス参照は最小限、URL は書かない |

### 事故防止

- 新規ドキュメント作成時に `grep -E 'github\.com/[^/]+/(claude-settings|<other-private>)'` 等で Private リポジトリ名・ホスト経由参照を機械検出する仕組みを Phase 7b の hooks / CI で検討する
- ADR 0001 の本名検出と同じ仕組みに相乗りする

### 適用範囲(遡及)

本 ADR 採択時点で既存の文書(Phase 0 / Phase 0.5 で書かれたもの)に対しても遡及適用し、違反箇所は同 PR/コミットで修正する。Phase 0.5 では `meta/migration-from-claude-settings.md` の git remote 記述 1 行を本 ADR 方針に従って書き換えた(コミット `6379112`)。

## Consequences

### Positive

- Public 文書からのリンクが「常に切れている」状態にならない(そもそも書かない)
- Public / Private の境界が明確になり、誤って Private 情報を Public 文書で参照する事故が起きない
- ADR 0001(anonymity-policy)と整合し、識別子レイヤと情報源レイヤの両方で個人特定情報露出を防げる
- 第三者(将来の GitHub 訪問者)が新システムを読んだとき、Private 知識前提なしで内容を理解できる

### Negative

- 過去の Private 資産(設計書、議論記録)を辿るには、オーナー個人が GitHub ダッシュボード経由で確認する必要がある
- 「あの時の判断根拠は何だったか」を新システム側で復元するため、本 ADR や Phase 0.5 のインベントリで **対応関係を残す手間** が発生する
- 旧設計のリッチなコンテキストを新文書に持ち込めないので、新文書側で必要なら自前で背景を書き起こす

### Neutral

- Phase 0.5 の `meta/migration-inventory.md` は本 ADR 方針に従い、旧 `docs/superpowers/specs/plans` 群を **C 参考扱いとし新システムに転記しない**ことが既に確定している(該当セクション参照)
- 旧設定との関係を語るのは `meta/migration-from-claude-settings.md` 1 ファイルに集約する(他の文書では重複させない)

## Related

- [ADR 0001](./0001-anonymity-policy.md): Anonymity Policy(識別子レイヤの個人情報保護、本 ADR は情報源レイヤを補完)
- `meta/migration-from-claude-settings.md`(本 ADR 採択時に修正済み)
- `meta/migration-inventory.md`(Phase 0.5 の棚卸し結果、本 ADR 方針に従い旧 specs/plans を転記しないと確定)
- `meta/TODO-for-phase-3.md`(本 ADR を `principles/` および `adapters/claude-code/user-level/CLAUDE.md` に取り込む TODO を追加)
