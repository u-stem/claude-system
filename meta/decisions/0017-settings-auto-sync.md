# ADR 0017: Deterministic Settings Rendering and Auto-Sync

- **Status**: Accepted
- **Date**: 2026-06-10
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

`settings.json.template` の更新は配置済みの実 `~/.claude/settings.json` に自動反映されない。これは ADR 0010 / 0016 の両方で Neutral 事項として記録され続けてきた恒常的なギャップである。

- `tools/sync.sh` は settings.json について「既存ファイルがあれば manual diff/merge required」と表示するのみで、更新を行わない(マシン固有値を壊さないための安全側設計)
- 実機の settings.json にはマシン・個人ローカル値(`agentPushNotifEnabled` / `effortLevel` / 通知設定等)が混在しており、テンプレートの盲目的 `cp` は不可能
- 実害も観測済み: ADR 0016 適用時点で、実機には 2026-05 にテンプレートへ追加済みの deny エントリや MCP pin 更新が未反映のまま残っていた(テンプレート更新がコミットされても誰も配置し直さない)

「テンプレート(repo 管理)とマシン固有値(ローカル)が同じファイルに混ざっている」ことが手動マージを強いる根本原因である。

## Decision

### 1. 配置ファイルを「ビルド成果物」と定義し、決定論的にレンダリングする

```
~/.claude/settings.json = deep-merge(
  settings.json.template,                      # repo 管理の方針
  ~/.claude/settings.machine-overrides.json   # マシン固有値(任意)
)
```

- マージは `jq` の `*`(オブジェクトは再帰マージ、配列・スカラは overrides 側で丸ごと置換)
- 配置ファイルには `"// managed"` マーカーを焼き込み、手編集禁止を明示する
- repo 方針の変更は template へ、マシン固有値は overrides へ。配置ファイルを直接編集する運用を廃止する
- **運用制約**: overrides に `permissions.*` / `hooks.*` 等の方針リストを書かない(配列置換でガードレールが丸ごと差し替わるため)

### 2. `tools/sync-settings.sh` を新設し、settings.json 配置の責務を移管する

- 引数なし = dry-run(正規化 diff 表示)/ `--apply`(バックアップ後に原子的書き込み)/ `--check`(ドリフト時 exit 1、hook / doctor 用)
- バックアップは `~/.claude-system-backups/`(`_lib.sh` の既存機構)
- ADR 0007 で「値配置は `sync.sh` の責務」とした境界を更新する: symlink 配布は引き続き `sync.sh`、settings.json の配置・更新は `sync-settings.sh` が所有する(`sync.sh` の該当メッセージも委譲先を案内するよう変更)

### 3. トリガーは versioned git hooks(post-commit / post-merge)

- `tools/githooks/post-commit` / `post-merge` を新設し、`git config core.hooksPath tools/githooks` で結線(`tools/setup.sh` に冪等ステップとして追加)
- template に触れたコミット / マージ(pull)のときのみ `sync-settings.sh --apply` を実行
- hook の失敗は warn のみで git 操作を阻害しない(fail-open。配置失敗は doctor のドリフト検知が拾う)
- コミットを発火点とする理由: コミット = レビュー済み内容という既存規約(検証 → コミットの順序)に乗ることで、「未検証のテンプレート編集が実機ガードレールに流れる」事故を構造的に防ぐ

### 4. ドリフト検知を `doctor.sh` に追加する

- `sync-settings.sh --check` + `core.hooksPath` 結線状態をチェック
- 配置済み settings.json が存在しないマシン(CI 含む)では informational 扱い(warn を出さない)
- `doctor.sh` は Stop hook(`stop-session-doctor.sh`)から定常実行されるため、hook 未結線・手動編集などで生じたドリフトもセッション単位で可視化される

### 5. 不採用の選択肢

| 候補 | 理由 |
|------|------|
| settings.json の symlink 配置 | マシン固有値が表現できない。ADR 0007 で確定した cp 方針の前提そのもの |
| 編集時 PostToolUse hook での即時適用 | 未コミット(未検証)の template 編集が実機ガードレールに即流れるのは早すぎる。粒度はコミットが正しい |
| launchd / fswatch 等の常駐 watcher | 過剰。変更の発生源は git 操作に限られる |
| 初回実行時の overrides 自動抽出 | 配置済みファイルとの差分が「意図したローカル値」か「単なる陳腐化」かは機械判定できない。初回のみ人間が振り分ける |

### 6. 初回移行(本マシン)

実機の現行値とテンプレートの差分から、意図的なローカル値のみを overrides に抽出する:
`agentPushNotifEnabled` / `effortLevel` / `remoteControlAtStartup` / `skipWorkflowUsageWarning`。
`model` の `[1m]` サフィックスは Fable 5 では冗長(常時 1M、ADR 0016)のため overrides に残さず template 値に統合する。それ以外の差分(deny エントリ・MCP pin の遅れ)は陳腐化であり、レンダリングで解消する。

## Consequences

- **Positive**: template 変更がコミットと同時に実機へ自動伝播し、ADR 0010/0016 で繰り返した「手動反映が必要」の Neutral 事項が解消する。repo 方針とマシン固有値が宣言的に分離され、ドリフトは doctor で常時可視化される。新マシンの settings 配置も `setup.sh` + `sync-settings.sh --apply` で完結する
- **Negative**: `jq *` の配列置換により、overrides の書き方を誤ると方針リストが丸ごと差し替わる(運用制約として明示。doctor のドリフト検知では捕捉できないため、overrides は小さく保つ)
- **Neutral**: 適用は次セッション起動から有効。`core.hooksPath` の結線はマシンごとに `setup.sh` の実行が必要(doctor が未結線を warn する)

## Related

- [ADR 0007](./0007-phase10-migration-script-robustness-and-boundary.md) — 「値配置は sync.sh の責務」とした境界(本 ADR で settings.json 分を `sync-settings.sh` へ移管)
- [ADR 0010](./0010-opus-48-harness-settings-sync.md) / [ADR 0016](./0016-fable-5-harness-settings-sync.md) — 本ギャップを Neutral 事項として繰り越してきた経緯
- [`tools/sync-settings.sh`](../../tools/sync-settings.sh) — レンダラ本体
- [`tools/githooks/`](../../tools/githooks/) — post-commit / post-merge トリガー
- [`tests/test-sync-settings.sh`](../../tests/test-sync-settings.sh) — マージ・冪等性・ドリフト検知のテスト
