# Phase 3 への申し送り TODO

このファイルは Phase 0 で発生した方針判断のうち、principles 層・adapter 層に取り込むべきものを Phase 3 まで記録する場所。

## 個人情報の取り扱い方針 (ADR 0001 由来)

`meta/decisions/0001-anonymity-policy.md` で決定された方針を、恒久的な原則として以下に組み込む:

- **principles/00-meta.md**(Phase 1 で作成予定)
  - 「アウトプットに個人情報を含めない」原則を抽象的に記述
  - 特定ツール名は出さず、普遍原則として表現
- **adapters/claude-code/user-level/CLAUDE.md**(Phase 3 で作成予定)
  - Claude Code 向けの具体ガイドを記述
  - global `git config` の `user.name` / `user.email` を継承する設計の明示
  - 本名・呼称の grep チェック指針
  - 新規ファイル作成時のチェックリスト

両者から ADR 0001 へのリンクを張り、決定経緯を辿れるようにする。

## チェックリスト(Phase 3 完了時)

- [ ] `principles/00-meta.md` に個人情報原則の抽象記述あり
- [ ] `adapters/claude-code/user-level/CLAUDE.md` に Claude Code 向け具体ガイドあり
- [ ] 上記 2 か所から ADR 0001 へのリンクが張られている
- [ ] Phase 7b の検討メモ:本名・呼称検出を `gitleaks` custom rule で組むかどうか
- [ ] このファイル `meta/TODO-for-phase-3.md` 自体を削除する(Phase 3 終了時)
