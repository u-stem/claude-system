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

## モデル切り替え時の注意

- principles 層に手を入れる場合は最も能力の高いモデルを使う
- 単純な実装は Sonnet で十分
- 詳細な指針は practices/ のモデル選択ガイド (Phase 2 で作成) を参照
