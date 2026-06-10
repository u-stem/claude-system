# ADR 0016: Fable 5 Harness Settings Synchronization

- **Status**: Accepted
- **Date**: 2026-06-10
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

2026-06-09 に Claude Fable 5(model ID: `claude-fable-5`)が一般公開された。Opus 4.8 の後継となる上位モデルで、常時 1M コンテキスト・デフォルト effort `high`・adaptive thinking のみ(thinking 無効化は非サポート)という特性を持つ。Claude Code 側は v2.1.170 で Fable 5 がモデルピッカーに登場した。

一方、本リポジトリの機械層は前世代のまま残存していた:

- `adapters/claude-code/VERSION` の pin は `2.1.156`(ADR 0010 で同期した値)。実インストール版は `claude --version` で `2.1.170` を確認
- `settings.json.template` の `"model": "claude-opus-4-8"` literal が残存(運用モデルは Fable 5 へ移行済み)
- env コメントに「Opus 4.8 期も有効維持」と前世代の世代表記が残存
- `user-level/CLAUDE.md` §6 の autonomy 記述が「Opus 4.8 期は〜」のまま

これは `meta/TODO-for-v0.2.md` 項目 16(VERSION pin を実インストール版へ同期)のトリガー「次に harness 設定を同期する機会」に該当する。

2.1.156→2.1.170 の changelog 確認(update-check skill / research-summarizer 委譲)で、settings.json に `fallbackModel`(v2.1.166、配列・最大 3 件)、`disableBundledSkills`(v2.1.169)等の新キーが追加されたことも判明した。設定キーの構文と Fable 5 の effort サポートは claude-code-guide(公式 model-config ドキュメント)で裏取りした。

## Decision

### 1. 機械層を Fable 5 / 2.1.170 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `settings.json.template` `model` | `claude-opus-4-8` | `claude-fable-5` | 運用モデルの世代更新。alias `fable` も有効だが ADR 0010 と同様に完全 ID で明示する。`[1m]` サフィックスは Fable 5 が常時 1M のため不要 |
| `settings.json.template` `effortLevel` | `xhigh` | `xhigh`(据え置き) | 公式 docs で Fable 5 は `low / medium / high / xhigh / max` をサポート(settings.json では `max` 不可)。デフォルトは `high` だが、ADR 0013 の「メインループ effort は単一グローバル値」の方針どおり `xhigh` を維持 |
| `settings.json.template` `fallbackModel` | (なし) | `["claude-opus-4-8"]` 新設 | v2.1.166 追加キー。Fable 5 過負荷・不達時の縮退先を直前の運用モデルに固定。Fable 5 の安全クラシファイア自動フォールバック先(Anthropic API では Opus 4.8)とも整合 |
| `settings.json.template` env コメント | 「Opus 4.8 期も有効維持」 | 「Fable 5 期も有効維持」 | 世代表記の整合。`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` は据え置き(引き下げ根拠は ADR 0014 文脈で現在も有効) |
| `adapters/claude-code/VERSION` | `2.1.156` | `2.1.170` | 実インストール版に pin を同期。TODO-for-v0.2 項目 16 をクローズ |

### 2. subagent の model tier は据え置く(Fable 5 はメインループのみ)

`subagents/*.md` の `model: opus | sonnet | haiku` は変更しない。

- alias は引き続き有効に解決される(機能的な破壊なし)
- `practices/model-selection.md` の複雑度ベース判断はモデル世代に依存しない。各 subagent の複雑度プロファイル(探索=軽量、実装=中位、批判・監査=上位)は不変
- Fable 5(input $10/M・output $50/M tokens)を全 subagent に波及させる計測上の根拠がない。`subagent-log.jsonl` の計測で「上位 tier の品質不足」が観測されてから再評価する(ADR 0013 と同じ姿勢)

### 3. autonomy 方針(ADR 0009)は Fable 5 期も継続する

確認抑制の線引き(可逆=自律 / 不可逆・外向き=確認)・委譲積極化・Workflow オプトインの各方針は Fable 5 で変更する根拠がない。`user-level/CLAUDE.md` §6 の世代表記のみ更新する。ADR 0009 自体は改訂しない(方針の中身が不変のため)。

### 4. 新規 settings キー・env の不採用判断

| 候補 | 判断 | 理由 |
|------|------|------|
| `disableBundledSkills`(v2.1.169) | 不採用 | バンドル skill / 組み込みコマンドを利用中。隠す動機がない |
| `requiredMinimumVersion` / `requiredMaximumVersion`(v2.1.163) | 不採用 | managed settings 用のエンタープライズ機能。個人運用に不要 |
| `DISABLE_PROMPT_CACHING_FABLE` | 不採用 | prompt cache はトークン経済上有効(ADR 0012)。無効化する理由がない |
| `CLAUDE_CODE_SUBAGENT_MODEL` | 不採用 | 全 subagent のモデルを一括上書きする env。ロール別 tier 設計(ADR 0013)と衝突する |

### 5. Fable 5 固有の運用上の注意を記録する

- **安全クラシファイア**: サイバーセキュリティ・生物学ドメインで Opus 4.8 へ自動フォールバックすることがある。`security-audit` 系タスクで稀にモデルが切り替わる可能性を許容する(品質 tier は同等)
- **thinking 無効化不可**: Fable 5 は adaptive thinking のみ。`MAX_THINKING_TOKENS=0` は効かない(現運用では未使用のため影響なし)
- **データ保持**: Covered Model 指定により 30 日データ保持が必須(zero data retention 不可)。個人運用・Public リポジトリ前提のため許容する

## Consequences

- **Positive**: 方針層と機械層の世代整合が回復する。TODO-for-v0.2 項目 16 がクローズされる。過負荷時の縮退先が `fallbackModel` で明示され、暗黙のモデル切替がなくなる
- **Negative**: メインループのコストが Opus 4.8 比で増加する(subagent 委譲ファースト・ADR 0015 の運用がコスト抑制側に働く前提)。30 日データ保持の制約を受け入れる
- **Neutral**: template の更新は配置済みの実 `~/.claude/settings.json` には自動反映されない(`tools/sync.sh` 実行または手動更新が必要)。subagent tier の Fable 化は計測待ちの将来判断

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — autonomy 方針(本 ADR で Fable 5 期も継続を確認)
- [ADR 0010](./0010-opus-48-harness-settings-sync.md) — 前回の harness 同期(本 ADR の直接の先行例)
- [ADR 0013](./0013-role-based-effort-modulation.md) — subagent tier 据え置きの判断軸(計測なき格上げをしない)
- [ADR 0014](./0014-tool-call-parse-error-resilience.md) — `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` 据え置きの背景
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — model / fallbackModel / env コメントを更新
- [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) — pin を 2.1.170 に同期
- [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) — 項目 16 のクローズ記録
