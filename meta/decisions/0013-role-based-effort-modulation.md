# ADR 0013: Role-Based Effort Modulation via Delegation and Model Selection

- **Status**: Accepted
- **Date**: 2026-05-31
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

運用は単一のグローバル effort(`settings.json` の `effortLevel`、現状 `xhigh`)で全タスクを回している。軽い定型作業(取得・整形・列挙・短い修正)にも最高 effort が適用され、token・速度のコストが複雑度に見合わず過剰になる場面がある。

2026-05-31、運用者から「effort を作業内容・ロールごとに変えたい(難所は高 effort、軽作業は低 effort)」という要望が出た(auto memory `effort-per-role-wish`)。これを ADR として記録する。

実態を確認した上での制約:

- **メインループ effort はセッション単位のグローバル値**である。執筆時点の実行版(2.1.158。本セッション中に 2.1.159 へ自動更新されたが挙動差は未確認)で「タスク単位での effort 自動切替」機構は確認できない。確認済みの制御面は `settings.json` の `effortLevel`(セッション単位)のみ。
- **subagent frontmatter の検証済みフィールドは `name` / `description` / `tools` / `model`** である(`adapters/claude-code/subagents/_index.md` の必須フィールド検証ループで確認)。`effort:` は現行スキーマに無く、ハーネスがそれを honor するかも未確認。架空フィールドには依拠しない(存在確認なしの架空 API を使わない原則)。
- 一方 **`model:` はロール別に既に機能している**(`explorer` = haiku、`code-reviewer` = sonnet 等)。委譲先の model を変えることで、ロールごとに投入する計算量(実効 effort)を変えられる。
- [`practices/model-selection.md`](../../practices/model-selection.md) は「役割で固定ルール化」をアンチパターンと定め、**複雑度・思考量で判断する**と規定している。本 ADR はこの方針を継承し、これと矛盾させない。

## Decision

実効的な計算投入(effort)のロール別可変化を、以下の枠組みで実現する。

### 1. メインループ effort は単一グローバル値を維持する

- メインが担う最難の作業(オーケストレーション + 難所の推論)に合わせて校正する。
- タスク単位の自動切替はハーネス機能ギャップのため前提にしない。本 ADR は既定値(`xhigh`)の変更ではなく、機構の明文化である。

### 2. ロール別 effort は「委譲 + 委譲先 model 選択」で実現する

- 軽量・機械的作業は軽量 model の subagent へ委譲し、難所はメイン(高 effort)が直接担う。
- 結果として実効 effort が複雑度に追従する。これは ADR 0011(委譲プロトコル)と [`practices/model-selection.md`](../../practices/model-selection.md) の既存機構の組み合わせであり、新規の未検証機構を導入しない。

### 3. 判断基準は複雑度に従う(役割固定ルールにしない)

| タスクの性質 | 委譲先 / model 水準 | 例(実 frontmatter) |
|----------------|----------------------|-----|
| 取得・整形・探索(判断が薄い) | 軽量 model の subagent へ委譲 | `explorer`(haiku) |
| 一般的な実装・リファクタ・テスト | 中位 | — |
| コードレビュー・整合判定 | 中位〜上位 | `code-reviewer`(sonnet) |
| 設計・セキュリティ・原子性(判断が重い) | 上位 model / メイン直接(高 effort) | `security-auditor`(opus) |

ロールは複雑度プロファイルの代理に過ぎない。「ロール X は常に effort Y」と硬直化させない(model-selection.md のアンチパターンを継承)。

### 4. セッション単位の手動調整を補助手段として認める

- メイン effort がセッションの性質と乖離する場合(終日、軽微な定型作業が続く等)、運用者は `settings.json` の `effortLevel` をセッション単位に手動調整してよい。
- これは自動化ではなく線引きである。タスク粒度には届かないため、粒度が必要な場面は §2 の委譲で対処する。

### 5. 専用 `effort:` frontmatter は現時点で採用しない

- 現行スキーマ外かつハーネス対応が未確認のため導入しない。`model` を effort の代理とする。
- 将来、ハーネスが per-subagent / per-task の effort を honor すると**検証できた場合**に限り、本 ADR を見直して frontmatter スキーマ拡張(`_index.md` の検証ループ更新を含む)を別途決定する。

## Consequences

- **Positive**: 全タスク一律 `xhigh` の過剰コストを、委譲によって実効的に解消できる。effort 方針が ADR 0009(委譲積極化)/ 0011(委譲プロトコル)/ 0012(token 経済)と model-selection.md に接続し一貫する。検証済み機構(`model` + 委譲)のみに依拠し、架空フィールドに依存しない。
- **Negative**: メインループのタスク単位自動切替は実現できない(ハーネス機能ギャップ)。委譲にはコンテキスト往復のオーバーヘッドがあり、ごく軽い作業では委譲が常に最適とは限らない(メイン直接実行との損益分岐は ADR 0009 / 0011 の委譲トリガー基準に従う)。
- **Neutral**: 既定のメイン effort(`xhigh`)は変更しない。subagent frontmatter スキーマも現状維持。ハーネスが per-task effort 機構を備えた時点で本 ADR を再評価する。

## Alternatives Considered

- **(A) メイン effort のセッション単位手動上下に寄せる** — タスク粒度に届かず、手動負荷が高い。補助手段として残す(Decision §4)。
- **(B) ロール→effort の固定テーブルを作る** — model-selection.md のアンチパターン「役割で固定ルール化」に反する。複雑度追従を採用。
- **(C) per-subagent `effort:` frontmatter を今導入する** — ハーネス対応が未確認のため見送り(架空 API 不使用の原則)。`model` を代理とし、検証後に再検討(Decision §5)。

## Implementation Notes

- 本 ADR は機構・方針の記録。重作業/軽作業の振り分けは ADR 0011 の委譲トリガー基準に従う。
- メインの effort 設定(`settings.json` の `effortLevel` フィールド)は据え置き。
- model-selection.md は既に複雑度判断を規定しており、本 ADR はそれを effort 文脈へ明示接続する(次に同 practice を触る機会に相互参照を追補)。
- 出所となった auto memory: `effort-per-role-wish`。

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) §2 — サブエージェント委譲の積極化
- [ADR 0011](./0011-delegation-orchestration-protocol.md) — 委譲 / オーケストレーション・プロトコル(委譲トリガーの定量基準)
- [ADR 0012](./0012-token-economy-mechanization.md) — token 経済(effort と token コストの関係)
- [`practices/model-selection.md`](../../practices/model-selection.md) — 複雑度による model / effort 判断
- [`principles/01-context-economy.md`](../../principles/01-context-economy.md) — 注意総量は有限、タスクに応じた投資
- [`adapters/claude-code/subagents/_index.md`](../../adapters/claude-code/subagents/_index.md) — subagent frontmatter 規約(検証フィールド)
