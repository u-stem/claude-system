# ADR 0005: Bootstrap Completion (v0.1.0-rc1) and Phase 10 Deferral

- **Status**: Accepted
- **Date**: 2026-04-29
- **Decider**: プロジェクトオーナー

## Context

Phase 0-9 を経て、claude-system は機能的には完成段階に到達した:

- 4 層構造(principles / practices / adapters / projects)が確立
- 機械的ガードレール 5 層(permissions / PreToolUse / PostToolUse / Stop / CI)が配置
- 既存プロジェクト 2 件(`kairous` / `sugara`)を取り込み済み
- `tools/doctor.sh` が clean(38 / 38 OK、warn/error 0)
- GitHub Actions の 3 ワークフローすべて green
- migrate スクリプト 2 本(`from-claude-settings.sh` / `rollback-from-claude-system.sh`)が配置済み

しかし v3 マスタープランで定義された **Phase 10 の `~/.claude/` シンボリックリンク切り替え** は本 ADR 採択時点で未実行。これは以下の理由による意図的な遅延:

1. **検証期間の確保**: Phase 0-9 で構築したガードレール群(特に hooks)は Phase 10 完了後に初めて実プロジェクトで発火する。ドキュメント整備期間中(数日〜1 週間)を「読み返し・脳内動作確認」に充てることで、Phase 10 切り替え時の予測精度を上げる
2. **ロールバック容易性の担保**: 切り替えは破壊的操作であり、`~/.claude/` 配下を破壊して symlink に置き換える。ロールバックスクリプト(`rollback-from-claude-system.sh`)はあるが、実行前にスクリプト自体を実機で動作確認する余裕を持つ
3. **migrate スクリプトの慣熟**: スクリプトのコードは Phase 9 で配置したが、Phase 10 セッションで初めて実行する。ドライ実行や手順書(`README.md`)の読み返し期間を経てから実行する方が安全

このため、Phase 9 完了時点で **v0.1.0-rc1**(Release Candidate 1)としてタグ付けし、Phase 10 を別タイミングで実行する判断を行う。

## Decision

### v0.1.0-rc1 リリース候補化

Phase 9 完了時点で以下を満たすため、`v0.1.0-rc1` タグを付与する:

- `tools/doctor.sh` clean
- ドキュメント整備完了(`README.md` / `operating-manual.md` / `daily-routine.md` / `multi-device-setup.md` / `glossary.md` 完成版)
- ADR 0001-0005 起票済み
- migrate スクリプト 2 本配置済み(未実行)
- GitHub Actions 直近 push が全 green
- `kairous` / `sugara` 取り込み済み

`v0.1.0-rc1` の意味:

- **rc1**: Release Candidate 1。「機能的には v0.1.0 として fix できる状態」だが、Phase 10 切り替えを経て実プロジェクトで動作確認するまで正式リリース(`v0.1.0`)としない
- 切り替え後に重大な問題が見つかれば revert + `v0.1.0-rc2` で再候補化
- 問題なく数日運用できれば Phase 10 完了時に `v0.1.0` を付与

### Phase 10 への遅延判断

Phase 10 は **本 ADR 採択時点では実行しない**。実行条件:

1. 切り替え実行前に以下を確認:
   - Phase 9 のチェックリストがすべて埋まっている
   - 旧 claude-settings の GitHub プッシュが完了し、archived 状態である
   - 数日間 claude-system を運用した(README、ドキュメントの読み返し等)
   - 切り替え後に問題が出た場合のロールバック手順を理解している
2. 別セッションで Phase 10 を Claude Code に依頼(マスタープラン `PHASE-8-9-10-adopt-verify-switch.md` の Phase 10 セクションのプロンプト使用)
3. 切り替え実行は明示的な人間の承認後

Phase 10 完了条件:
- `~/.claude/` の各 symlink が claude-system を指す
- `~/.claude/settings.json` が新 template ベースに置換済み
- `tools/doctor.sh` が clean
- hooks が発火する(`--no-verify` 試行で `permissions.deny` が阻止する等)
- バックアップ `~/.claude-system-backups/migration-<TIMESTAMP>/` が永続保管されている

### 切り替え後のリリース

Phase 10 完了時:

- ADR 起票: `0006-symlink-switchover.md`(切り替え日時 / 動作確認結果 / バックアップ場所)
- `git tag v0.1.0`(正式リリース)
- 旧 `claude-settings` の GitHub 側 archive 設定を再確認

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|---|---|---|
| **Phase 9 完了と同時に Phase 10 を実行**(同セッション内) | 不採用 | 検証期間ゼロ。hooks の実発火を確認できない状態でドキュメント整備とともに切り替えは認知負荷が高く、ミス時のロールバック判断が遅れる |
| **Phase 9 で v0.1.0 を直接付与**(rc を経ない) | 不採用 | Phase 10 で実プロジェクト動作確認するまでは「機能完成」と「動作完成」のギャップが存在する。SemVer 上 rc 段階を経るのが妥当 |
| **Phase 10 を完了まで Phase 9 を完了扱いにしない** | 不採用 | Phase 9 完了の成果(ドキュメント / ADR / migrate スクリプト配置)が宙吊りになる。Phase 9 自体は「検証 + ドキュメント整備」が責務範囲なので完了扱いが妥当 |
| **migrate スクリプトを Phase 10 セッションで初めて作成** | 不採用 | スクリプト自体に問題があった場合、Phase 10 セッション内で発見すると切り替え実行が遅延する。Phase 9 で配置 + 静的検証(shellcheck)を済ませることでリスクを前倒し |
| **Phase 10 を細分化**(Step ごとに別セッション) | 不採用 | 切り替え自体は migrate スクリプト 1 本で完結する設計のため、細分化のメリットが少ない。手順全体が `tools/migrate/from-claude-settings.sh` に集約されており、別セッション化は余分なコンテキスト分断を生む |

## Consequences

### Positive

- **Phase 10 切り替え失敗時の影響範囲を最小化**: 数日の検証期間で予期せぬ問題を発見できる(例: Claude Code 本体のバージョンアップで `~/.claude/` の構造が変わった等)
- **migrate スクリプトの段階的検証**: 配置(Phase 9) → 静的検証(shellcheck / doctor.sh) → 実行(Phase 10)の 3 段階で問題を検出できる
- **rc / 正式リリースの SemVer 整合**: 機能完成と動作完成を別タグで区別できる
- **ロールバック容易性**: `v0.1.0-rc1` のコミット ID + バックアップディレクトリで Phase 10 切り替え前後を巻き戻せる

### Negative

- **Phase 10 実行が忘れられるリスク**: 数日後に切り替えるつもりが、運用が落ち着くと「動いているなら触らない」となり、新ガードレールの恩恵を受けない期間が長引く可能性。本 ADR を `meta/CHANGELOG.md` から参照することで定期的に思い出せるようにする
- **rc1 / rc2 の運用負荷**: 切り替え後に問題が見つかった場合、rc を増やすのか revert で巻き戻すのかの判断が必要。基本方針: 問題が migrate スクリプト起因なら revert + rc2、ガードレール側起因なら fix + 新リリース
- **未検証の機能を含むタグ**: `v0.1.0-rc1` 時点で hooks の実発火は未検証。これを「rc」の意味として明示することで承知のリスクとする

### Neutral

- **GitHub release 機能の使用**: 本 ADR 時点では release ドラフト化はせず、tag のみ付与。正式 `v0.1.0` 時点で release notes を含めて GitHub release を作成するか判断
- **`adapters/claude-code/VERSION` との関係**: Claude Code 本体のバージョン(2.1.119)と claude-system のバージョン(`v0.1.0-rc1`)は独立。Claude Code 本体更新時の影響範囲マップ([`adapters/claude-code/README.md`](../../adapters/claude-code/README.md))は別途維持
- **既存タグとの整合**: claude-system にはこれまでタグがなかったため、`v0.1.0-rc1` が初めての SemVer タグとなる

## Related

- [ADR 0001](./0001-anonymity-policy.md) — Anonymity Policy(本 ADR の Public 運用前提)
- [ADR 0002](./0002-public-private-boundary.md) — Public/Private Boundary(同上)
- [ADR 0003](./0003-memory-architecture.md) — Memory Architecture(本 ADR の構成要素)
- [ADR 0004](./0004-system-architecture-summary.md) — System Architecture Summary(本 ADR の前提となる総括)
- `~/.claude-system-bootstrap/PHASE-8-9-10-adopt-verify-switch.md` — Phase 10 のプロンプト(bootstrap 用のローカル文書、Public 参照ではない)
- [`tools/migrate/from-claude-settings.sh`](../../tools/migrate/from-claude-settings.sh) — Phase 10 で実行する migrate スクリプト
- [`tools/migrate/rollback-from-claude-system.sh`](../../tools/migrate/rollback-from-claude-system.sh) — Phase 10 緊急時のロールバック
- [`meta/integration-trace.md`](../integration-trace.md) — Phase 9 統合テストシミュレーション(Phase 10 切り替え後の予測含む)
- [`meta/CHANGELOG.md`](../CHANGELOG.md) — Phase 0-9 の全変更履歴
