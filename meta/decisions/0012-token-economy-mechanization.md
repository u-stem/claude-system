# ADR 0012: Token Economy Mechanization and Measurement

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-05-29
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

[`principles/01-context-economy.md`](../../principles/01-context-economy.md) は「注意は有限資源」「入力・出力を最小化」「圧縮・委譲・境界区切り」を公理・帰結として与えている。しかしこれは**原則の宣言**であり、「**どこをどう抑えれば、どのコストが下がるか**」という因果と、その効果を**計測する手段**が claude-system 側に体系化されていない。

現状を棚卸しすると、トークン抑制メカニズムは「意図はあるが機械実装が一部欠落」している:

- **欠落**: 旧 `~/ws/claude-settings/` には `hooks/filter-test-output.sh`(テスト出力を `tail -150` でラップしコンテキスト圧縮、[`meta/migration-inventory.md`](../migration-inventory.md):87 で Class A 資産と評価)が存在したが、**現行の `adapters/claude-code/user-level/hooks/` には移植されていない**。テスト/ビルドの大量出力がそのままメインコンテキストに流入する経路が開いている。
- **散在**: 圧縮に効く仕組み(委譲によるコンテキスト隔離、段階的開示、deny による無駄ツール呼び出し抑止)は principles / ADR 0009 / 0011 / subagents に分散し、「圧縮ポイント一覧」として一望できない。
- **未計測**: `subagent-stop-record.sh` が `subagent-log.jsonl` を書く計測基盤はあるが、これを「削減策の効果観測」に接続していない。効果が定量で見えないため、抑制が規律として機能しているか検証できない。

ADR 0011 が委譲プロトコル(主要な抑制手段)を定めるのと対をなし、本 ADR は**抑制ポイントの一覧化・機械実装の補完・計測の接続**を担う。

## Decision

トークン経済を「明示された圧縮ポイント + 機械実装 + 計測」の三点で機械化する。

### 1. 圧縮ポイントの一覧化(因果の明示)

新規 practice [`practices/token-economy.md`](../../practices/token-economy.md) に、「**ここをこうすれば、ここが抑えられる**」の因果表を置く。最低限以下を含む:

| 抑制ポイント | 機構 | 抑えられるコスト |
|---|---|---|
| 大量出力タスクの委譲 | サブエージェント(ADR 0011) | メイン親コンテキストの成長 |
| テスト/ビルド出力 | 出力キャップ hook(下記 §2) | 失敗ログ全文の流入 |
| 段階的開示 | 入口は要約、深掘り時のみ全文(principles/04) | 初期入力の肥大 |
| 無駄なツール呼び出し | permissions.deny / allow | 試行錯誤の往復 |
| 遅延ツールロード | ToolSearch(必要な schema のみ取得) | ツール定義の常時占有 |
| タスク境界の区切り | 1 セッション 1 タスク(principles/01) | 完了タスクの持ち越し |

### 2. 機械実装の補完(出力キャップ hook の導入)

旧 `filter-test-output.sh`(`tail` ラップ)に相当する機構を `pre-bash-output-cap.sh` として導入する。実装にあたり、出力加工の正しい機構を確認した結果、**PostToolUse はツール実行済みの結果を変更できない**ことが判明したため、**PreToolUse(Bash)で `hookSpecificOutput.updatedInput.command`(Claude Code v2.0.10+)を返してコマンドを実行前に書き換える**方式を採る(当初案の「PostToolUse でキャップ」は機構として不成立)。

設計上の安全策:

- 対象は test/build/lint/typecheck カテゴリの**単純コマンドのみ**。`&&` / `||` / `;` / `|` / リダイレクト / コマンド置換 / 改行を含む複合コマンドはスキップする(書き換えで意味を壊さない、かつ `pre-bash-guard.sh` 等の deny を `allow` で上書きしない)。
- **標準出力のみ**を `tail -n N` でキャップし、標準エラーは保持する。これにより `log-bash-failure.sh`(PostToolUse、stderr から失敗を category 判定)の自己参照ループを壊さない。
- 元コマンドの**終了コードを `PIPESTATUS` で保全**する(`tail` の終了コードに化けさせない)。
- キャップ行数は `CLAUDE_BASH_OUTPUT_CAP`(既定 200)、`0` で無効。緊急時は `tools/disable-guardrails.sh`。
- 現行 hook 規約(`#!/usr/bin/env bash` / `set -euo pipefail` / 対象外で早期 exit / `_lib.sh` 利用)に従う。

### 3. 計測の接続

`subagent-log.jsonl`(`subagent-stop-record.sh` が記録)を「委譲によりメインから隔離された作業量」の観測点として位置づけ、practice に集計の起点を記す。定量の自動レポート化は過剰投資を避けて段階導入とし、まずは記録項目と観測手段の定義に留める(自動化は [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) 項目 10 のレトロ連動と合わせて判断)。

### 4. 適用範囲

principles 層は変更しない(principles/01 が公理を既に与えている)。本 ADR は実装手順(practices)と機械実装(hook)に閉じる。

## Consequences

- **Positive**: 「最小化せよ」という原則が、計測可能な機械的仕組みに落ちる。旧システムにあった出力圧縮の欠落が塞がる。圧縮ポイントが一覧化され、新しい抑制策を追加する際の参照点ができる。
- **Negative**: 新規 practice + 新規 hook + settings.json への結線を実施済み(本 ADR と同一作業)。hook は対象コマンド判定を誤ると有用な出力まで切る恐れがあるため、複合コマンドをスキップし単純コマンドに限定した。キャップ行数(既定 200)とマッチャは運用しながら調整する。`updatedInput` の都合上、書き換え時は `permissionDecision: allow` を伴うが、対象を非破壊カテゴリ(test/build/lint)の単純コマンドに限定しているため deny 対象とは交差しない。
- **Neutral**: 計測の自動化は段階導入とし、本 ADR では `subagent-log.jsonl` を観測点と位置づけるに留める(自動レポート化は TODO-for-v0.2 項目 10 と合わせて判断)。

## Update (2026-06-05): 計測点の盲点を塞ぐ

`subagent-log.jsonl` を観測点に据えたものの、実データ検証で **記録の約 69%(drowsy-unity 406 件中 281 件)で `agent_type` が空**であり、`model` も未記録だったことが判明した。SubagentStop payload が型を載せない経路があるため、「どのロールがどの model でどれだけ走ったか」が見えず、ロール別 model 選択(ADR 0013)の費用対効果を評価できない状態だった。これが「model 分けが効いている実感が無い」の正体である(model 分け自体は honor されている。transcript の実モデルが宣言通り: `research-summarizer`→`claude-sonnet-4-6`、haiku ロール→`claude-haiku-4-5` と確認済み)。

対処: `subagent-stop-record.sh` を改修し、payload が薄いときも sidecar `*.meta.json` の `agentType` と transcript 内の最頻 `model` id を補完して記録するようにした(前進方向の記録のみ。揮発済み transcript の遡及補完は対象外)。これによりロール別・model 別の使用量が観測可能になり、ロール構成の剪定判断(死蔵ロールの統合・削除)を勘でなくデータで行う前提が整う。

## Update (2026-07-08): 空フィールドの原因確定と誤帰属の修正

初回レトロ(2026-07)で `agent_type` 空率が上記対処後も改善していない(74%)ことが判明し、原因切り分けを実施した。確定した事実は 3 点:

1. **空 `agent_type` = ハーネス内部の補助エージェント**。空レコードにも `agent_id` / `effort` は入っており実在の agent 実行だが、Agent ツール起動の委譲(検証セッションで 7/7 全件が型付き記録)には対応せず、per-agent transcript / meta.json もディスクに存在しない。つまり **hook の取りこぼしではなく分母の汚染**であり、「69% が計測失敗」という本 Update 冒頭の解釈は範囲の問題(内部エージェントは設計上 `agent_type` を持たない)に訂正される。
2. **`model` backfill はメインの model を誤帰属していた**。SubagentStop payload の `.transcript_path` は subagent でなく**メインセッションの transcript** を指す(公式 hooks doc で裏取り。subagent 自身は `agent_transcript_path`、実体は `<session>/subagents/agent-<agent_id>.jsonl`)。2026-06-06 の「偽キー修正」(`3e3a352`)はこの前提を誤認し、sidecar 補完の除去と引き換えにメイン transcript の最頻 model を記録していた(例: opus 指定の devil-advocate が `claude-fable-5` と記録)。**本 Update 以前の `model` 列はロール別評価に使えない**。
3. **`subagent-stop-audit.sh` も同じ偽前提で監査が全件誤検知化していた**。メイン transcript は指示文書経由で `claude-settings` 文字列等を常に含むため、SubagentStop のたびに `private-resource-link` が発火(findings 359 件中 319 件)。

対処: 両 hook の transcript 解決を「公式キー `agent_transcript_path` 優先 + `<session>/subagents/agent-<agent_id>.jsonl` 導出フォールバック」に修正。`agent_type` は per-agent meta.json の `agentType` で補完し、per-agent transcript が存在しない内部エージェントは `"(internal)"` と明示記録(model はメイン transcript から拾わず空のまま — 誤帰属より欠測を選ぶ)。監査は per-agent transcript のみを対象とし、内部エージェントは skip。過去レコードの遡及補正はしない(前進記録のみの方針を維持)。

## Related

- [ADR 0011](./0011-delegation-orchestration-protocol.md) — 委譲プロトコル(本 ADR の主要な抑制手段)
- [ADR 0013](./0013-role-based-effort-modulation.md) — ロール別 model 選択(本計測が費用対効果評価の前提)
- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — Autonomy Tuning(委譲積極化の方針)
- [`principles/01-context-economy.md`](../../principles/01-context-economy.md) — 抑制の公理
- [`principles/04-progressive-disclosure.md`](../../principles/04-progressive-disclosure.md) — 段階的開示
- [`practices/token-economy.md`](../../practices/token-economy.md) — 発動点 → 機構 → 計測の運用 practice
- [`meta/migration-inventory.md`](../migration-inventory.md):87 — 旧 `filter-test-output.sh`(Class A、未移植)
- [`adapters/claude-code/user-level/hooks/pre-bash-output-cap.sh`](../../adapters/claude-code/user-level/hooks/pre-bash-output-cap.sh) — 出力キャップ hook 実体
