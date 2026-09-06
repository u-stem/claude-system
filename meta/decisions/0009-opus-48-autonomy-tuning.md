# ADR 0009: Opus 4.8 Autonomy Tuning

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-05-29
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

claude-system は Opus 4.7 期に構築され、自律性に関する運用方針は専用 ADR を持たず、adapter 層に散文として点在していた。具体的には user-level `CLAUDE.md` §6 作業フローの「Opus 4.7 期は自律判断を尊重し、確認プロンプトを抑制」と、`subagents/explorer.md` の「Opus 4.7 期は単発の小タスクはメインで直接実行が原則」である。これらは ADR 化されておらず、根拠と適用範囲が一箇所にまとまっていなかった。

2026-05-29、運用モデルが Opus 4.8 に更新された。4.8 の harness では新規・拡張された能力が利用可能になっている:

- マルチエージェント・オーケストレーション(複数 subagent を決定論的に束ねる仕組み)
- background 実行・スケジューリング(長時間タスクの分離実行、定期実行)
- 並列ファンアウト(独立タスクの同時ツール呼び出し、worktree 分離)
- 構造化質問(曖昧時の選択肢提示)
- 遅延ツールロード(必要なツールだけ schema を取得)

4.7 前提の散文記述ではこれらの実態とズレが生じるため、散在する方針を一箇所に集約し、4.8 の能力前提でチューニングを明文化する。本 ADR が autonomy 運用方針の正式な初回記録であり、従来 ADR 化されていなかったため supersede 対象は存在しない(置き換えではなく新規記録)。なお `meta/` 配下の履歴記録(`migration-inventory.md`、`claude-version-log.md` の過去行、ADR 0003/0004 の「4.7 期に構築」等)は**時点の事実**であり、本 ADR では変更しない。

## Decision

Opus 4.8 期の自律性運用方針を以下に定める。

### 1. 確認抑制の線引きを明文化する

| 操作種別 | 既定の振る舞い |
|----------|----------------|
| 可逆操作(ローカル編集、読み取り、再実行可能なスクリプト) | 事前確認なしで自律実行 |
| 不可逆・外向き操作(ファイル削除/上書き、`git push`、コミット、外部サービスへの送信) | 事前確認を取る |
| durable な承認(明示的な事前許可)がある場合 | 当該文脈の範囲で再利用してよい |

- 一度の文脈での承認は別の文脈へ持ち越さない。承認の範囲は明示された対象に限る。
- これは harness 標準方針("actions that are hard to reverse or outward-facing, confirm first")と整合する。
- 影響範囲が大きい / 破壊的な操作は §7「困ったら問い直す」に従い必ず確認する(本方針は確認の**省略**ではなく**線引き**である)。

### 2. サブエージェント委譲を積極化する

- 並列ファンアウトが安価・確実になったため、判断を委譲寄りに倒す。
- 独立した複数タスクは 1 メッセージで並列ツール呼び出しを既定とする。
- 広範な探索(多数ファイル / 命名規則の横断)は早めに探索 subagent へ委譲する。
- 旧基準(単発の小タスクはメイン直接実行、5 クエリ超 / 10 ファイル以上で委譲)は維持しつつ、境界では委譲を選ぶ。

### 3. Workflow(マルチエージェント・オーケストレーション)はユーザー明示オプトイン時のみ

- token コストが大きいため、自動・暗黙の起動はしない。
- タスクが恩恵を受ける場合でも、ユーザーの明示的な要求を前提とする。明示要求がなければ、単発 subagent で対応するか、起動の是非と概算コストを提示して確認を取る。

### 4. background 実行 / スケジューリングの指針

- `run_in_background` は長時間タスク(ビルド・テスト・デプロイ監視)の分離に使う。
- harness が追跡する作業の完了は自動で再通知されるため、短間隔 wakeup によるポーリングをしない。harness が追跡できない外部状態(CI・デプロイ・リモートキュー)のみ、変化速度に合わせた間隔で観測する。
- `/loop`・scheduled agents(定期実行)はユーザーの明示要求時のみ設定する。

### 5. 「困ったら問い直す」の手段に構造化質問を使う(補足)

- 仕様が曖昧 / 解釈が複数あるときは、構造化質問で選択肢を提示する(user-level `CLAUDE.md` §7)。
- ただし既定のある選択や自分で検証可能な事実には使わない。自明な選択は採用理由を述べて先に進む。

完了報告フォーマット(user-level `CLAUDE.md` §1)は 4.8 でも不変であり、維持する。

## Consequences

- **Positive**: 4.8 の能力を前提とした自律運用が可能になる。確認の線引きが明確になり、過剰確認と無断の不可逆操作の双方を避けられる。散在していた autonomy 方針が ADR 1 ファイルに集約され、参照先が一箇所になる。
- **Negative**: adapter 層の文言を 4.7→4.8 に更新する必要がある(本 ADR と同一コミットで実施)。Workflow のオプトイン制約により、明示しない限りマルチエージェントは起動されない(意図的なトレードオフ)。
- **Neutral**: 履歴記録(`migration-inventory.md` 等の「4.7 期に構築」)は時点事実として変更しない。`claude-version-log.md` には 4.8 への更新行を追記する。

## Related

- [ADR 0004](./0004-system-architecture-summary.md) — System Architecture Summary(全体方針の総括)
- [`adapters/claude-code/user-level/CLAUDE.md`](../../adapters/claude-code/user-level/CLAUDE.md) §6 作業フロー / §7 困ったら問い直す
- [`adapters/claude-code/subagents/explorer.md`](../../adapters/claude-code/subagents/explorer.md) — 起動の判断基準
- [`meta/claude-version-log.md`](../claude-version-log.md) — 2026-05-29 Opus 4.8 への更新行
- [`principles/01-context-economy.md`](../../principles/01-context-economy.md) — 委譲の選択基準
- [`principles/02-decision-recording.md`](../../principles/02-decision-recording.md) — 検証されていない仮定を残さない
