# ADR 0022: Harness Sync 2.1.220 — Model Switch to Opus 5 and Effort Recalibration

- **Status**: Accepted
- **Date**: 2026-07-25
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

前回の harness 同期は ADR 0021(2.1.217 / 2026-07-22)。実インストール版は **2.1.220** まで進み、3 パッチ分の差分が蓄積した。`update-check` command による調査(research-summarizer 2 系統委譲 + 一次裏取り: CHANGELOG raw / 公式 model-config doc / npm registry / headless 実測)で以下を確定した:

- **v2.1.218**: `/code-review` の background subagent 化、`context: fork` skill の background 既定化、agent 名の `:` 拒否(plugin namespace 予約)
- **v2.1.219(最重要)**: **Claude Opus 5(`claude-opus-5`)追加、`opus` alias の新デフォルト**。`sandbox.network.strictAllowlist` / `DirectoryAdded` hook / `workflowSizeGuideline` 追加。**subagent のネスト spawn が既定 depth 3 に緩和**(2.1.217 で既定単層化された直後の反転)。Opus 4.7 が fast mode 対象外に
- **v2.1.220**: bug fixes のみ
- **Opus 5 の価格は $5/$25 per MTok(Opus 4.8 と同額)**。調査初報の「$10/$50」説は **Opus 5 fast mode の価格との混同**だった(次回調査時の再混入に注意)。1M context・128K 出力・effort 5 段階(low〜max)対応。「別レートリミットバケット」説は三次情報のみで一次未確認
- MCP pin(playwright 0.0.78 / chrome-devtools 1.6.0 / sequential-thinking 2026.7.4)は npm registry 実測で全て最新のまま。gitleaks 8.30.1 も最新のまま(Betterleaks は据え置き継続)

あわせて本 ADR は、調査過程で顕在化した**方針と実機の乖離 2 件**を主要論点として扱う:

1. **effortLevel の乖離**: template は `xhigh`(ADR 0013/0016/0018/0021 が一貫して据え置きと記録)だが、実機 `~/.claude/settings.machine-overrides.json` が `medium` で恒常上書きしていた。この値は ADR 0017 の初回移行が「意図的なローカル値」として機械的に抽出したもので、**medium という値自体の理由はどこにも記録がない**。結果として「メイン medium < subagent high」という推論深度の逆転が生じ、ADR 0013 §1「メインは最難の作業(オーケストレーション + 難所の推論)に合わせて校正する」に反していた
2. **単層連鎖の根拠喪失**: ADR 0015 の「subagent は再委譲できない(構造的制約)」という事実命題が v2.1.219 で偽になった。ADR 0021 §3 の「方針とハーネスが一致」という記録も 3 パッチで崩れた

計画は devil-advocate の反証レビューを経て大幅に修正した(depth pin 案の撤回、fallbackModel 2 件化案の撤回、effort「記録して維持」案の撤回、主モデル再評価の追加)。effort 復帰・depth 非 pin・主モデル乗り換え・fallback 維持の 4 判断は運用者確認済み(2026-07-25)。

## Decision

### 1. 機械層を 2.1.220 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `adapters/claude-code/VERSION` | `2.1.217` | `2.1.220` | 実最新版に pin を同期 |
| `settings.json.template` `model` | `claude-fable-5` | `claude-opus-5[1m]` | §2 参照 |
| `settings.json.template` `effortLevel` | `xhigh`(実効 medium) | `xhigh`(実効 xhigh) | §3 参照(overrides 側の削除) |
| `mcp/servers.template.json` chrome-devtools | `npx` | `bunx -y` | README「runner は bunx 統一」との残存不整合を是正(pin 1.6.0 は据え置き) |
| `commands/update-check.md` | sequential-thinking 欠落 | 3 サーバー全列挙 + strictAllowlist 定点観測 | 調査対象の欠落是正 |

### 2. 主モデルを Opus 5 へ乗り換える(`claude-opus-5[1m]`)

- ベンチマーク(2026-07-24 発表時点): Frontier-Bench(agentic terminal coding)43.3% vs Fable 5 33.7%、CursorBench 3.2 で Fable 5 最高値 ±0.5%、GDPval-AA v2 Elo 1,861 vs 1,747、OSWorld 2.0 で Fable 5 超え。日常のコーディング/エージェント用途では**同等以上・半額($5/$25 vs $10/$50)**
- 公式の使い分けは「迷ったら Opus 5、最高性能が要る負荷は Fable 5(長時間・複雑タスクほど Fable 5 優位)」。本リポジトリの主用途(開発オーケストレーション)はベンチ優位側に該当する
- `[1m]` を明示指定して 1M context を確定(Fable 5 の「常時 1M のため不要」という旧注記を廃止)
- **再評価トリガー**: 長時間自律タスク・難所推論で品質不足を体感したら Fable 5 へ戻す(`/model fable` で一時切替可)。xhigh 復帰(§3)によるコスト増は単価半減で相殺される
- Opus 5 固有の注意: thinking 無効化は effort high 以下限定(xhigh 運用では常時 thinking)。headless で `claude-opus-5[1m]` の解決を実測確認済み(2.1.220)

### 3. effortLevel を xhigh に復帰する(machine-overrides から削除)

- `~/.claude/settings.machine-overrides.json` から `effortLevel: "medium"` を削除し、template の `xhigh` を実効化した(`sync-settings.sh --apply` で実測確認: model / fallbackModel / effortLevel が期待値でレンダリング)
- Why: medium は ADR 0017 初回移行時の実機値の機械的抽出であり、**値の理由が無記録のまま方針既定(xhigh)を 3 週間恒常上書きしていた**。「運用したことのない既定値を方針として掲げる幽霊状態」と「メイン < subagent の深度逆転」を同時に解消する
- overrides は通知系・TUI 等の真のマシン固有値のみに縮める(ADR 0017「overrides は小さく保つ」)。方針系キー(`model` / `effortLevel` / `fallbackModel`)の override 残存は doctor.sh が WARN する(§5)
- ADR 0013 §4 の「セッション単位の手動調整」の裁量は不変(/effort 等)。恒常的なマシン上書きと混同しない

### 4. fallbackModel は `["claude-opus-4-8"]` を維持し、根拠を訂正する

- 主モデルが Opus 5 になったため、Opus 5 を fallback に足す案(当初計画)は無意味化し撤回。1 世代前の既知良品として Opus 4.8 を維持する
- **根拠の訂正**: ADR 0016 が挙げた「安全クラシファイアの自動フォールバック先(Opus 4.8)と揃える」は、サーバ側 refusal ルーティングと settings の過負荷・不達時縮退という**別系統機構の混同(誤帰属)**だったため撤回する。以後の保持根拠は「既知良品の前世代」のみ

### 5. ネスト委譲は pin せず、観測を強化する

- v2.1.219 の既定 depth 3 を**受容**し、`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` の env pin は**採らない**(devil-advocate 反証で当初計画から転換)
  - ADR 0015 §2 は当初から「物理強制せず指示レベル」を選んでおり、principles/06「抑制は最終手段」に整合。旧既定の機械的固定は「条件のない永続例外」になる
  - env 値の意味(main を含む数え方)が未実測で、外した場合「委譲ファースト運用が全プロジェクトで静かに死ぬ」失敗モードを持つ
- 単層連鎖は**運用規約**として維持し、記述を是正した(user-level CLAUDE.md §6 / commands/team.md の「構造制約」→「運用規約」)。ADR 0015 には Update 節で前提変化を追記
- **観測強化(実測に基づく)**: SubagentStop payload に親子フィールドは無いが、per-agent sidecar meta.json に `parentAgentId` / `spawnDepth` が実在することを headless 入れ子セッションで実測確認(depth 2 の子 meta.json に `"parentAgentId":"<親ID>","spawnDepth":2`)。`subagent-stop-record.sh` が両値を additive に記録し、`loop-report.sh` が多段委譲の発生を集計する。規約違反(depth≥2)が機械検出可能になった
- 再評価トリガー: 多段委譲を意図的に採用する場合は ADR 0015 の改訂とセットで行う

### 6. subagent の model / effort は据え置く(opus alias の暗黙世代アップを受容)

- `opus` alias の 3 subagent(refactor-planner / security-auditor / devil-advocate)は Opus 4.8 → Opus 5 へ暗黙昇格する。明示 pin はしない(固有銘柄 pin は model-selection.md のアンチパターン。解決済み model ID は subagent-log.jsonl に実測記録され事後検証可能)
- effort は全 subagent で high 以下を据え置き。xhigh/max の parse-error 安全性は Opus 5 世代でも未検証(ADR 0013 の共有仮定を世代更新後も維持)
- **正直な記録**: ADR 0013 が約束した「parse-error 発生率の監視」は現状機械計測の仕組みが無く、体感ベースである。StopFailure 通知(ADR 0014 層A)が代理シグナル

### 7. 不採用の判断

| 候補 | 判断 | 理由 |
|------|------|------|
| `sandbox.network.strictAllowlist`(2.1.219) | 不採用、定点観測化 | 方向性はガードレール多層化と整合するが、allowlist 列挙対象が広く(WebFetch / registry / MCP / gh)失敗モードが「静かなツール不能」でメンテコスト先行。導入するなら専用検証セッション + 別 ADR。update-check.md に再評価項目として明記 |
| `workflowSizeGuideline`(2.1.219) | 不採用 | workflow 機能は不使用(overrides の `skipWorkflowUsageWarning` と整合)。既定値運用 |
| `DirectoryAdded` hook(2.1.219) | 不採用(記録のみ) | 想定用途(保護対象ディレクトリ追加の警告)は既存 deny + pre-edit-protect.sh で被覆。実例が出てから再評価 |
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` env pin | 不採用 | §5 参照(反証レビューで撤回) |
| fallbackModel への Opus 5 追加 | 撤回 | §4 参照(主モデル乗り換えで無意味化) |
| Betterleaks 乗り換え | 据え置き継続 | ADR 0021 の判断を継承(エコシステム成熟待ち) |
| Opus 4.7 fast mode 除外(2.1.219) | 記録のみ | fast mode 不使用のため影響なし |

### 8. 影響範囲マップの走査結果(変更なし行を含む全行記録)

| 領域 | 結果 |
|------|------|
| permissions 構文 | 変更なし |
| hooks matcher / フィールド構文 | 変更なし |
| hook event 種別 | `DirectoryAdded` 新設 → 不採用(§7) |
| skill frontmatter 仕様 | `context: fork` の background 既定化(2.1.218)。現行 skill に `context: fork` 使用ゼロ(grep 確認)で影響なし |
| subagent frontmatter 仕様 | 変更なし。agent 名 `:` 拒否(2.1.218)→ 全 8 subagent 名に `:` なし。ネスト depth 3 化 → §5 で対応 |
| MCP server 設定スキーマ | スキーマ変更なし。runner 統一のみ(§1) |
| enabledPlugins | 採用 3 プラグインとも存続(marketplace 自動更新) ← **誤記録。ADR 0023 で訂正**: 当時 3 件とも未インストールであり、marketplace 自動更新は起きていなかった |
| attribution 構文 | 変更なし |
| `~/.claude/` ディレクトリ構造 | 変更なし(per-agent meta.json の `parentAgentId` / `spawnDepth` を §5 で活用) |
| env 変数 | 廃止・改名なし |
| デフォルトモデル / effort | **要対応 → 対応済み**(§2 / §3。Fable 5 据え置き案は §2 の根拠で不採用) |
| slash command | `/code-review` の background 化(2.1.218)は built-in の話で、本リポジトリの独自 `/review` / `/review-loop` に影響なし |

## Consequences

- **Positive**: 主モデルのコスト半減と effort 復帰(方針どおりの深い推論)を同時達成。方針記録と実機設定の乖離が解消され、doctor.sh の WARN で再発を機械検出。単層連鎖が「事実の誤記」から「観測可能な運用規約」になり、多段委譲の発生が subagent-log で追跡可能に
- **Negative**: 主モデル乗り換えは計測ではなくベンチマーク(一部三次情報)に基づく判断。長時間自律タスクでの品質は §2 の再評価トリガーで運用監視する。単層規約の遵守は引き続きメインの自制に依存する(違反は事後検出のみ)
- **Neutral**: opus alias subagent の実効世代が変わるため、subagent-log.jsonl の model 列の分布が 2026-07-25 を境に変化する(集計時に注意)。「Opus 5 別レートバケット」説は一次未確認のため判断根拠から除外した

## Related

- [ADR 0013](./0013-role-based-effort-modulation.md) — effort 校正原則(§3 の復帰判断の根拠)
- [ADR 0015](./0015-delegation-chain-and-mandatory-delegation.md) — 単層連鎖(本 ADR §5 で前提変化を Update 追記)
- [ADR 0016](./0016-fable-5-harness-settings-sync.md) — 前回のモデル乗り換え(fallback 根拠の誤帰属を本 ADR §4 で訂正)
- [ADR 0017](./0017-settings-auto-sync.md) — machine-overrides の由来(§3 の乖離の発生経路)
- [ADR 0021](./0021-harness-sync-2.1.217.md) — 前回同期(単層既定化の記録が本 ADR で反転)
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — model / effortLevel / fallbackModel
- [`adapters/claude-code/user-level/hooks/subagent-stop-record.sh`](../../adapters/claude-code/user-level/hooks/subagent-stop-record.sh) — 親子記録
- [`practices/model-selection.md`](../../practices/model-selection.md) — 推論深度軸の追補(ADR 0013 Implementation Notes の宿題を解消)
- 外部: [Opus 5 発表](https://www.anthropic.com/news/claude-opus-5) / [model-config doc](https://code.claude.com/docs/en/model-config) / [Fable 5 発表](https://www.anthropic.com/news/claude-fable-5-mythos-5)
