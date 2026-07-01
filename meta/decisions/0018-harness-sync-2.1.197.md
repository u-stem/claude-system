# ADR 0018: Harness Settings Synchronization (Claude Code 2.1.197)

- **Status**: Accepted
- **Date**: 2026-07-01
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

前回の harness 同期(ADR 0016 / 2026-06-10)で pin した Claude Code **2.1.170** に対し、実際の最新版は **2.1.197**(2026-06-30。既定モデルが Sonnet 5 / 1M へ)まで進み、間に 27 パッチ分の差分が蓄積した。方針層と機械層の世代整合を回復し、この間に追加された設定・非推奨・依存バージョンを取り込む。

`update-check` skill による調査(WebFetch で releases / changelog / gitleaks releases / settings schema を裏取り)で以下を確定した:

- **Claude Code 最新**: 2.1.197(出典: `github.com/anthropics/claude-code/releases`, `code.claude.com/docs/en/changelog`)
- **gitleaks 最新**: v8.30.1(2026-03。feature-complete 継続、後継 betterleaks は実績浅く据え置き)
- **MCP 最新**: `@playwright/mcp` 0.0.77、`chrome-devtools-mcp` 1.4.0、`@modelcontextprotocol/server-sequential-thinking` 2025.12.18(変化なし)
- 2.1.170→2.1.197 の間に追加された settings: `sandbox.credentials`(v2.1.187)、`autoMode.classifyAllShell`(v2.1.193)、`attribution.sessionUrl`(v2.1.183, changelog 表記)、`enforceAvailableModels`(v2.1.175)、`footerLinksRegexes`(v2.1.176)等
- 非推奨/削除: `TeamCreate`/`TeamDelete` ツール(v2.1.178 で削除)、`CLAUDE_CODE_SUBAGENT_MODEL` のスコープ変更(v2.1.147)

## Decision

### 1. 機械層を 2.1.197 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `adapters/claude-code/VERSION` | `2.1.170` | `2.1.197` | 実最新版に pin を同期 |
| `settings.json.template` `attribution` | (なし) | `{ "commit": "", "pr": "" }` 新設 | Public メタリポの commit/PR に claude.ai セッション URL(harness 自動 attribution)を混入させない(ADR 0002)。§4 参照 |
| `settings.json.template` `@playwright/mcp` | `0.0.75` | `0.0.77` | 最新へ pin |
| `mcp/servers.template.json` `@playwright/mcp` | `0.0.75` | `0.0.77` | 同上 |
| `mcp/servers.template.json` `chrome-devtools-mcp` | `1.2.0` | `1.4.0` | 最新へ pin(マイナー、破壊的変更なし) |
| `.github/workflows/doctor.yml` `GITLEAKS_VERSION` | `8.21.2` | `8.30.1` | doctor 用 CLI バイナリを最新へ。ADR 0016 で「本体 8.30.1 が最新」と認識済みだった doctor.yml の取り残しを解消。新規検出ルール(Bedrock / Looker / Airtable)を取り込む |

`sequential-thinking`(2025.12.18)は既に最新のため据え置き。

### 2. `attribution` の実現方法(スキーマ確認結果)

権威ある settings JSON schema(schemastore)では `attribution` は `commit` / `pr` の2つの文字列サブキーのみで、`additionalProperties: false`。changelog が示す `attribution.sessionUrl`(v2.1.183)は web / Remote Control 限定の内部項目で、**安定 settings スキーマにはキーが存在しない**。空文字は当該 attribution を hide する仕様のため、`commit: ""` / `pr: ""` で harness 自動 attribution ブロック(セッション URL を含む)ごと抑止する。

`Co-Authored-By` トレーラと `Generated with Claude Code` 行は `user-level/CLAUDE.md` の指示でモデルが別途付与するため失われない。

### 3. モデル方針は据え置く

メインループ `claude-fable-5` / `fallbackModel: ["claude-opus-4-8"]` / `effortLevel: xhigh` は変更しない。Claude Code 既定が Sonnet 5 になったが、Fable 5 は現行最上位モデルであり既定変更の影響を受けない。subagent の tier(opus/sonnet/haiku)も据え置き(ADR 0013 / 0016 §2 の「計測なき格上げをしない」姿勢を継続)。

### 4. 新規 settings キー・非推奨の判断

| 候補 / 変更 | 判断 | 理由 |
|------------|------|------|
| `sandbox.credentials`(v2.1.187) | 不採用 | 認証情報をサンドボックスへ「露出」する allowlist。既定サンドボックスは元々認証ファイル・秘密 env を遮断するため、露出設定は不要 |
| `autoMode.classifyAllShell`(v2.1.193) | 不採用 | 有効化すると auto mode 中の allow ルールを全停止し全 shell を分類器へ回す。トークン経済のため精選した allow-list(ADR 0012)を打ち消すため採らない |
| `enforceAvailableModels` / `footerLinksRegexes` / `requiredMinimumVersion` / `disableBundledSkills` | 不採用 | managed/enterprise 向け、または個人運用に不要(ADR 0016 §4 と同旨。バンドル skill / 組み込みコマンドは利用中) |
| `TeamCreate` / `TeamDelete` 削除(v2.1.178) | 影響なし | リポジトリ内に参照ゼロ(grep 済み)。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env は有効のまま(teammate は `Agent` の `name` で spawn) |
| `CLAUDE_CODE_SUBAGENT_MODEL` スコープ変更(v2.1.147) | 影響なし | ADR 0016 §4 で既に不採用。参照ゼロ |
| betterleaks(gitleaks 後継) | 据え置き | v0.2 の継続評価項目。2026 末を目安に再評価(ADR 0016 の記録を継承) |

## Consequences

- **Positive**: 方針層と機械層の世代整合が回復する。Public リポの commit/PR からセッション URL 混入経路を塞ぐ(ADR 0002 の Public/Private 境界を機械層でも担保)。gitleaks / MCP の pin 遅れを解消し、新規シークレット検出ルールを取り込む
- **Negative**: なし(モデル・effort・権限モデルは不変。attribution は harness 自動ブロックのみ抑止し、モデル付与のトレーラは維持)
- **Neutral**: template 更新はコミット時に `tools/sync-settings.sh`(ADR 0017)経由で配置済み `~/.claude/settings.json` へ自動反映される。`attribution` の web / Remote Control セッションでの挙動は当該環境でのみ観測可能

## Related

- [ADR 0002](./0002-public-private-boundary.md) — `attribution` 採用の根拠(セッション URL 混入防止)
- [ADR 0010](./0010-opus-48-harness-settings-sync.md) / [ADR 0016](./0016-fable-5-harness-settings-sync.md) — 先行する harness 同期
- [ADR 0012](./0012-token-economy-mechanization.md) — `autoMode.classifyAllShell` 不採用の判断軸(allow-list のトークン経済)
- [ADR 0013](./0013-role-based-effort-modulation.md) — subagent tier 据え置きの判断軸
- [ADR 0017](./0017-settings-auto-sync.md) — template 更新の自動反映機構
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — `attribution` / playwright pin
- [`adapters/claude-code/user-level/mcp/servers.template.json`](../../adapters/claude-code/user-level/mcp/servers.template.json) — MCP pin
- [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) — pin を 2.1.197 に同期
- [`.github/workflows/doctor.yml`](../../.github/workflows/doctor.yml) — gitleaks CLI を 8.30.1 へ
