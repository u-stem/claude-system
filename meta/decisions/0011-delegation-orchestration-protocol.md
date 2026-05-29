# ADR 0011: Delegation / Orchestration Protocol

- **Status**: Accepted
- **Date**: 2026-05-29
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

ADR 0009(Opus 4.8 Autonomy Tuning)§2 で「サブエージェント委譲を積極化する」方針は定めたが、**委譲の運用プロトコル**(どの粒度で、何を渡し、何を返させるか)は明文化していない。現状、委譲に関する記述は断片として散在している:

- [`principles/01-context-economy.md`](../../principles/01-context-economy.md):17 — 「重い探索や大量出力が予測されるタスクは独立コンテキストを持つ単位へ委譲する」(1 文)
- [`principles/03-skill-composition.md`](../../principles/03-skill-composition.md) — 能力の合成と再利用(原則レベル)
- ADR 0009 §2 — 「並列ファンアウトを既定」「5 クエリ超 / 10 ファイル以上で委譲」(方針レベル)
- [`adapters/claude-code/subagents/explorer.md`](../../adapters/claude-code/subagents/explorer.md):75 — 「境界では委譲を選ぶ」(個別 heuristic)

`adapters/claude-code/subagents/` には 6 個のサブエージェント(explorer / code-reviewer / doc-writer / refactor-planner / research-summarizer / security-auditor)が定義済みだが、「**メインはオーケストレータに徹し、実作業と大量出力をサブエージェントに閉じ込め、メインには構造化された結論だけ返させる**」という統合的な運用規律を 1 枚にまとめた practice / adapter ガイドが存在しない。結果として、

- 委譲すべき場面で委譲せずメインのコンテキストを肥大化させる
- 委譲してもサブエージェントが大量の中間出力(ファイルダンプ等)をメインに戻し、コンテキスト圧縮の利得を失う
- 返却フォーマットが定まらず、メイン側で再パース・再判断が発生する

といった非効率が起こりうる。harness 自身のツールガイダンス(「the agent's final message is returned to you as the tool result; it is not shown to the user — relay what matters」)が示す設計意図を、claude-system の運用規律として明文化する必要がある。

## Decision

メイン=オーケストレータ規律を確立する。実体は新規 practice [`practices/delegation-orchestration.md`](../../practices/delegation-orchestration.md) と、その adapter 翻訳([`adapters/claude-code/subagents/_index.md`](../../adapters/claude-code/subagents/_index.md) の「委譲プロトコル」節)として配置済み。プロトコルの骨子を以下に定める。

### 1. 役割分離

| 主体 | 担うこと | 担わないこと |
|------|----------|--------------|
| メイン | タスク分解、委譲先の選定、結論の統合、不可逆操作の判断、ユーザーとの対話 | 広範な探索の実走、大量の中間出力の生成・保持 |
| サブエージェント | 与えられたスコープ内の実作業、中間出力の生成と消化 | 役割境界を越えた判断、ユーザーへの直接応答(最終テキストはメインへの戻り値) |

### 2. 委譲トリガー(定量基準)

以下のいずれかに該当したら委譲を既定とする(ADR 0009 §2 の基準を踏襲・明文化):

- 広範な探索: 5 クエリ超、または 10 ファイル以上の横断が見込まれる
- 大量出力の予測: 結論に対して中間出力が支配的になる(ログ走査、全文読解、一括変換)
- 独立並列タスク: 相互依存のない複数サブタスク → 1 メッセージで並列ファンアウト
- 単発の小タスク(既知のファイル・シンボル・値の 1 点参照)はメイン直接実行(委譲しない)

### 3. メインが渡すもの / サブエージェントが返すもの

- **渡す**: スコープを絞ったタスク記述 + **返却スキーマ(structured output)**。生のコンテキストを丸投げしない。
- **返す**: 構造化された結論のみ。ファイルダンプ・全文・探索ログをメインに戻さない(サブエージェント内で消化し、`file_path:line` 等の参照と要約に圧縮する)。
- 並列ファンアウトで結果を束ねる必要があるときのみバリア同期し、それ以外はパイプライン(逐次依存のない段は待ち合わせない)を既定とする。

### 4. 段階(単発 → ファンアウト → Workflow)

| 段階 | 使う場面 | 制約 |
|------|----------|------|
| 単発サブエージェント | 1 つの独立した重いタスク | 既定 |
| 並列ファンアウト | 独立な複数タスクの同時実行 | 1 メッセージで複数ツール呼び出し |
| Workflow(決定論的オーケストレーション) | 多段・多数エージェントの構造化実行 | **ユーザー明示オプトイン時のみ**(ADR 0009 §3 を維持) |

### 5. 適用範囲

本 ADR は運用プロトコル(practices / adapter 層)を定めるものであり、principles 層の文言は変更しない(principles/01・03 が背後の公理を既に与えている)。

## Consequences

- **Positive**: 委譲の粒度・渡す情報・返却形式が一箇所に定まり、メインのコンテキスト肥大を構造的に抑制できる。サブエージェント 6 個の使い分けと整合する運用規律ができる。ADR 0009(方針)→ 0011(プロトコル)の階層が明確になる。
- **Negative**: 新規 practice ファイルの作成と `subagents/_index.md` の追記を要した(本 ADR と同一作業で実施済み)。プロトコルの遵守は文脈依存判断であり機械強制しない(過剰確認を避ける ADR 0009 と整合)。
- **Neutral**: Workflow のオプトイン制約は ADR 0009 のまま維持し、本 ADR で緩めない。

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — Autonomy Tuning(§2 委譲積極化 / §3 Workflow オプトイン)。本 ADR はその運用プロトコル詳細
- [`principles/01-context-economy.md`](../../principles/01-context-economy.md) — 委譲の経済的根拠(注意は有限資源)
- [`principles/03-skill-composition.md`](../../principles/03-skill-composition.md) — 能力の合成と再利用
- [`adapters/claude-code/subagents/_index.md`](../../adapters/claude-code/subagents/_index.md) — サブエージェント索引(委譲プロトコル節を追記予定)
- [ADR 0012](./0012-token-economy-mechanization.md) — トークン経済の機械化(委譲はその主要手段の一つ)
