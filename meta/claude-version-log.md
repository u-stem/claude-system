# Claude モデル利用履歴

このシステムを構築・運用する上で利用した Claude モデルの履歴。

## 履歴

各 Phase は Claude Code セッションで実行。記録の精度には限界があり、ここに載っているのは「Phase 完了時に明示的に記録できたもの」のみ。`git log` 上のコミット author / committer は global git config を継承する設計のため、モデル情報は含まれない。

| 日付 | モデル | 用途 | メモ |
|------|--------|------|------|
| 2026-04-26 | claude-opus-4-7 (1M context) | Phase 0 / 0.5(初期化、棚卸し、ADR 0001/0002) | xhigh effort, auto mode |
| 2026-04-27 | claude-opus-4-7 (1M context) | Phase 1-7b(principles / practices / adapter / skills / subagents / fragments / templates / tools / hooks / CI) | xhigh effort、各 Phase は別セッション |
| 2026-04-28 | claude-opus-4-7 (1M context) | Phase 8(kairous 取り込み) | 案 Y(`@web-apps-common.md` 追加のみ) |
| 2026-04-29 | claude-opus-4-7 (1M context) | Phase 8(sugara 取り込み) / Phase 9(検証 + ドキュメント整備、`v0.1.0-rc1` リリース候補化) | xhigh effort、Phase 9 中に Claude maturity timeline 概念を発見 |
| 2026-05-29 | claude-opus-4-8 (1M context) | ADR 0009 起票(Opus 4.8 自律性チューニング)、adapter 層の 4.7→4.8 運用記述を更新 | 運用モデル 4.8 へ更新。マルチエージェント / background / 並列ファンアウト前提に調整 |
| 2026-05-29 | claude-opus-4-8 (1M context) | ADR 0010 起票(harness 機械層の同期)。settings.json.template の model pin / VERSION を 4.8・2.1.156 に同期 | 方針層と機械層の世代整合。autonomy は hook 強制せず既存ガードで部分担保を確認 |
| 2026-05-29 | claude-opus-4-8 (1M context) | リポジトリ棚卸し。stale クローズ(TODO 12/13、CLAUDE.md Phase 進行節)+ ADR 0011(委譲オーケストレーション)/ 0012(トークン経済の機械化)起票・実装 | 運用プロトコルが薄かった 2 領域を設計し実装まで完了(practices 2 本 + 出力キャップ hook)。hook 機構は claude-code-guide で検証し PreToolUse `updatedInput` 方式を採用 |

## モデル切り替え時の注意

- principles 層に手を入れる場合は最も能力の高いモデルを使う
- 単純な実装は Sonnet で十分
- 詳細な指針は practices/ のモデル選択ガイド (Phase 2 で作成) を参照
