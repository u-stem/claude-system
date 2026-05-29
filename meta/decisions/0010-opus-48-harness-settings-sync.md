# ADR 0010: Opus 4.8 Harness Settings Synchronization

- **Status**: Accepted
- **Date**: 2026-05-29
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

ADR 0009 で Opus 4.8 期の自律性運用方針を**方針層**(adapter 層の散文 + ADR)で確定した。しかし harness の**機械層**(`adapters/claude-code/user-level/settings.json.template` の model pin / env コメント、`adapters/claude-code/VERSION`)は 4.7 期の値のまま残存しており、方針層と機械層に世代不整合が生じていた。

検証で以下が判明した:

- `settings.json.template` の `"model": "claude-opus-4-7"` literal が残存(運用モデルは 4.8)
- env コメントに「EXPERIMENTAL_AGENT_TEAMS は Opus 4.7 期に厳格化」と 4.7 期の記述が残存
- `adapters/claude-code/VERSION` の pin は `2.1.119`、実インストール版 Claude Code は `2.1.156`。`tools/check-claude-version.sh` が "installed newer than pinned" を警告する状態

「機械担保(設定で物理的に強制する)」の要請に対して、まず ADR 0009 の方針が機械強制になじむかを検討した。結論は **autonomy 方針の中核(可逆/不可逆操作の線引き、サブエージェント委譲の判断、Workflow のオプトイン判断)は文脈依存の判断であり、ADR 0008 の `/Users/` パス検出のような二値の機械判定にはなじまない**。これらを無理に hook 化すると false-positive/negative が頻発し、運用を阻害する。

ただし「不可逆・外向き操作は事前確認」という ADR 0009 の線引きの**一部**は、既存の機械ガードが既に担保している。`permissions.deny`(強制 push / `--no-verify` / `~/.claude*` の `rm`)と `pre-bash-guard.sh` の ASK_PATTERNS(`git reset --hard` / `git clean -f` / `git checkout .` 等)が、不可逆操作を物理ブロックまたは確認に回している。本 ADR はこの整合を確認・記録する。

## Decision

### 1. 機械層で確実に固定できる値を 4.8 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `settings.json.template` `model` | `claude-opus-4-7` | `claude-opus-4-8` | 運用モデルの世代更新(環境情報で確定) |
| `settings.json.template` env コメント | 「Opus 4.7 期に厳格化」 | 「Opus 4.8 期も有効維持」 | 世代表記の整合 |
| `adapters/claude-code/VERSION` | `2.1.119` | `2.1.156` | `claude --version` で確認した実インストール版に pin を同期 |

### 2. ADR 0009 の autonomy 方針は方針層に留め、新規 hook を増設しない

- 可逆/不可逆の線引き・委譲判断・Workflow オプトインは文脈依存の判断であり、機械的二値判定にできない。無理な hook 化は false-positive で運用を阻害する。
- これは「機械担保しない」ではなく「機械強制になじむ部分とそうでない部分を切り分ける」判断である。なじむ部分(下記 3)は既存ガードで担保済み。

### 3. 既存ガードが ADR 0009 の線引きの一部を担保していることを確認・記録する

ADR 0009「不可逆・外向き操作は事前確認」の機械担保は、既存の二層が部分的に満たしている:

- `permissions.deny`: 強制 push(`git push --force` / `-f`)、`--no-verify`、`~/.claude*` / `claude-system` の `rm`、機密ファイル系 Read/Write を物理ブロック
- `pre-bash-guard.sh`: DENY_PATTERNS(破壊的 `rm` / 強制 push / `--no-verify` / `--no-gpg-sign`)を block、ASK_PATTERNS(`git reset --hard` / `git clean -fdxX` / `git checkout .` / `git restore .` / `git branch -D`)を確認に回す

これらは ADR 0009 の「不可逆操作は事前確認」と方向が一致する。本 ADR で新たな検出器は追加しない(既存で足りる範囲を確認するに留める)。

### 4. permissions の allow/deny リストは据え置く

- allow(良性コマンド)/ deny(破壊操作・機密)はいずれもモデル世代に依存しない。4.8 で新たに追加・撤回すべき確実な項目は現時点で無い。
- 実 `~/.claude/settings.json` への値配置は `tools/sync.sh` の責務(ADR 0007)であり、本 ADR は template と VERSION の更新までを範囲とする。

## Consequences

- **Positive**: 方針層(ADR 0009)と機械層(template / VERSION)の世代整合が取れる。`check-claude-version.sh` の version 警告が解消する。autonomy の機械強制可否が切り分けられ、過剰 hook 増設を避けられる。既存ガードが ADR 0009 の線引きを既に部分担保していることが記録され、重複実装を防げる。
- **Negative**: ADR 0009 の autonomy 方針の大部分は LLM の判断遵守に依存し、機械強制されない(意図的なトレードオフ。文脈依存判断の本質的限界)。
- **Neutral**: template の `model` 更新は配置済みの実 `~/.claude/settings.json` には自動反映されない(`tools/sync.sh` 実行または手動更新が必要)。VERSION pin の更新は breaking change の有無を別途レビューする前提で、本 ADR は pin 同期のみを行う。

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — Opus 4.8 Autonomy Tuning(本 ADR が機械層を同期する対象の方針)
- [ADR 0007](./0007-phase10-migration-script-robustness-and-boundary.md) — 値配置は `sync.sh` の責務という責務境界
- [ADR 0008](./0008-mechanical-detection-of-user-identifier-paths.md) — 二値判定になじむ規範の機械担保例(対比)
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — model / env コメントを更新
- [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) — pin を 2.1.156 に同期
- [`adapters/claude-code/user-level/hooks/pre-bash-guard.sh`](../../adapters/claude-code/user-level/hooks/pre-bash-guard.sh) — 不可逆操作の既存 deny/ask 担保
