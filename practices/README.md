# practices

不変層(`principles/`)を踏まえた**抽象的な実践パターン**を定義する層。

ツール固有の API・設定ファイル名・コマンド名は出さないが、不変層より一段具体に踏み込み、
「いつ発動するか」「どの順で進めるか」「何を判断軸にするか」を整理する。
特定言語固有の構文ガイドや具体ツールの実装は適応層(`adapters/`)に置く。

## 共通フォーマット

各 practice は以下のセクションを必ず備える:

- 関連する原則
- いつ使うか(トリガー)
- 手順
- 判断基準
- アンチパターン
- 旧資産からの継承

## 構成

| ファイル | テーマ | 主に参照する原則 |
|---|---|---|
| `adr-workflow.md` | 意思決定記録の運用 | 02, 06 |
| `skill-design-guide.md` | 能力単位の切り方 | 03, 04, 05 |
| `session-handoff.md` | セッション跨ぎでの引き継ぎ | 01, 02 |
| `project-bootstrap.md` | 新規プロジェクト立ち上げ | 05, 06 |
| `refactoring-trigger.md` | 共通化・抽象化の判断タイミング(失敗パターンの還流を内包) | 03, 02, 06 |
| `update-propagation.md` | 共通設定変更の波及判断 | 06, 05, 02 |
| `model-selection.md` | モデル選択ガイドライン | 01, 06 |
| `secure-coding-patterns.md` | セキュアコーディングのパターン | 05, 06 |
| `supply-chain-hygiene.md` | 依存関係の衛生管理 | 06, 02 |
| `secrets-handling.md` | 認証情報・秘密鍵の取り扱い | 05, 06 |
| `testing-strategy.md` | テスト戦略(TDD サイクルを内包) | 03, 02, 05 |
| `development-workflow.md` | 開発ワークフロー | 02, 06 |
| `coding-style-conventions.md` | コーディングスタイル(言語非依存部分) | 03, 02, 01 |
| `commit-conventions.md` | コミット規約 | 02, 03 |
| `delegation-orchestration.md` | 委譲とオーケストレーションの規律 | 01, 03, 05 |
| `iterative-review.md` | 反復レビューの委譲戦略(収束ループの一般形を内包) | 01, 02, 05 |
| `token-economy.md` | トークン経済の運用(発動点 → 機構 → 計測) | 01, 04, 05 |

(数字は `principles/0N-…` の番号)

## 検証

不変層と同じく、`meta/forbidden-words.txt` を機械検出のソースとして本層にも禁止語チェックを通す。
本層から不変層への参照(`principles/...` パス)が各ファイルに 1 つ以上含まれていることも検証対象。
