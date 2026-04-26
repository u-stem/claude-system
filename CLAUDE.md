# CLAUDE.md (claude-system 編集者向け)

このリポジトリは **メタリポジトリ** であり、AI 協働開発体験そのものを定義する。
ここに加える変更は他の全プロジェクトの開発体験に波及するため、慎重に扱うこと。

このファイルは「`claude-system` 自身を編集するときに読まれる指示」である。
「日々の開発全般で読まれる共通指示」は [`adapters/claude-code/user-level/CLAUDE.md`](./adapters/claude-code/user-level/CLAUDE.md) に分離している(Phase 10 で `~/.claude/CLAUDE.md` にリンクされる)。

## 絶対ルール

- **principles 層に特定ツール用語(skill / subagent / hook / settings 等)を出さない**(`meta/forbidden-words.txt` で機械検出)
- **practices 層にも同上**(adapter 層以下に閉じる)
- **機密情報を絶対にコミットしない**。`.gitleaks.toml` と Phase 7b の hooks/CI で多重防御するが、人間/LLM 側でも常に確認する
- **既存ファイルの破壊禁止**。旧 `~/ws/claude-settings/` は読み取り専用扱い、`*.backup-*` は人手バックアップ原本(settings.json deny で物理ブロック)
- **指定範囲外のファイルを「ついで」で編集しない**。Phase 完了報告で `git diff --stat` を必ず確認
- **冪等性**: 全スクリプトは再実行しても安全であること
- **shell スクリプトは bash 前提、`set -euo pipefail` を必ず付与**
- **macOS BSD コマンド前提**(GNU 互換不要、ただし bash は Homebrew 5.x を許容)
- **ADR 0001(個人特定情報)・ADR 0002(Public/Private 境界)を遵守**。本名・呼称・新規連絡先・Private リソースへの URL を成果物に含めない

## 編集時の慎重度

| 層 | 慎重度 | 理由 |
|----|--------|------|
| `principles/` | 最大 | 全プロジェクトの根本原則。破壊的変更は MAJOR バージョンアップ相当 |
| `practices/` | 高 | 抽象パターン。複数プロジェクトに波及。特定ツール用語混入禁止 |
| `adapters/<tool>/` | 中 | ツール固有。当該ツール利用者に影響。ここではじめて固有用語を使ってよい |
| `projects/` | 個別 | gitignore 済み、各プロジェクトの統合情報 |
| `tools/` | 中〜高 | 自動化スクリプト。冪等性を厳守、`set -euo pipefail` 必須 |
| `meta/` | 低 | 履歴・記録。事実を正確に書くこと |

## 層別の編集ルール

### principles/

- 5 年後の自分が読んでも成立する内容のみ書く
- 共通フォーマット 6 セクションを備える(公理 / 帰結 / 運用への落とし込み / アンチパターン / 関連する practices / 旧資産からの継承)
- 各ファイル 800〜1500 字程度
- 1 セッションで得られた経験則を直接ここに昇格させない(複数文脈で妥当性が確認できてから)
- 破壊的変更は ADR を必ず起票(`practices/adr-workflow.md` 参照)

### practices/

- principles の帰結として実装手順を書く
- 特定ツール用語を出さない(「能力単位」と書き、`skill` とは書かない)
- 各 practice は導入背景・トリガー・手順・判断基準・アンチパターン・旧資産からの継承を備える

### adapters/`<tool>`/

- principles と practices を当該ツールの語彙に翻訳する
- 固有用語(skill / subagent / hook / settings.json 等)を使ってよいのはここから下のみ
- VERSION ファイルで前提バージョンを明示し、影響範囲マップと移行プレイブックを README に記述
- API キー等の機密はテンプレートに含めず、TODO コメントで配置時に手動設定する旨を明記

### tools/

- shebang は `#!/usr/bin/env bash`、`set -euo pipefail` 必須
- macOS BSD コマンド前提(`date -jf`, `stat -f`, `sed -i ''` 等)、GNU 互換は仮定しない
- 全スクリプトは冪等(再実行しても結果が同じ)
- 副作用は `--dry-run` で観測可能にする選択肢を持つ

### meta/

- 履歴・申し送り・棚卸し・ADR・用語集の置き場
- 各 Phase の TODO ファイル(`TODO-for-phase-N.md`)は当該 Phase で消化し、完了したら削除する
- ADR は連番(欠番禁止)、Status は最新に保つ

## 言語規約

- README, CLAUDE.md, principles/practices/adapters の文書: **日本語**
- shell スクリプト・コード内のコメント: **英語**
- コミットメッセージ: **英語**(Conventional Commits)
- ADR: 日本語(後から読み返すのは本人のため)

## コミット規約

Conventional Commits:

| type | 用途 |
|------|------|
| `feat:` | 新しい principle / practice / skill / subagent / hook / template 等 |
| `fix:` | 修正 |
| `docs:` | ドキュメントのみ |
| `refactor:` | リファクタリング |
| `chore:` | ビルド、CI、雑務 |
| `test:` | テスト追加・修正 |

各 Phase で**複数コミットに分割推奨**(後から判断単位を読み取るため)。

## 必須検証

編集後、以下のいずれかを実施(具体ツールは Phase 7a / 7b で整備):

- `principles/` `practices/` 編集時: 禁止語チェック(`while read word; do grep -ri "$word" principles/ practices/; done < meta/forbidden-words.txt`)
- 設定テンプレート編集時: `jq` で JSON 妥当性、`gitleaks detect --source <path> --no-git --redact` で機密漏洩チェック
- 全般: `tools/doctor.sh`(Phase 7a 実装予定)で整合性確認

検証なしで「完了」と書かない([`principles/02-decision-recording.md`](./principles/02-decision-recording.md) - 検証されていない仮定を残さない)。

## ロールバック

各 Phase で 1 コミット以上残すこと。問題があれば `git revert <commit-id>` で対応。
Phase 7b のフック有効化以降は `tools/disable-guardrails.sh` で一時無効化可能。

## Phase 進行

- 全 Phase の構成: `~/.claude-system-bootstrap/00-MASTER-PLAN.md`
- 各 Phase の詳細仕様: `~/.claude-system-bootstrap/PHASE-*.md`
- 完了報告は MASTER-PLAN「共通プロトコル」セクションに従う(`git diff` の証跡を必ず添付)

## 関連

- [`adapters/claude-code/user-level/CLAUDE.md`](./adapters/claude-code/user-level/CLAUDE.md) — ユーザーレベル共通指示(日常開発で読まれる側)
- [`meta/decisions/0001-anonymity-policy.md`](./meta/decisions/0001-anonymity-policy.md)
- [`meta/decisions/0002-public-private-boundary.md`](./meta/decisions/0002-public-private-boundary.md)
- [`meta/glossary.md`](./meta/glossary.md) — 用語集
