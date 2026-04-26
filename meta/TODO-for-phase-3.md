# Phase 3 への申し送り TODO

このファイルは Phase 0 / Phase 0.5 で発生した方針判断のうち、principles 層・adapter 層に取り込むべきものを Phase 3 まで記録する場所。

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

## Public/Private 境界の取り扱い (ADR 0002 由来)

`meta/decisions/0002-public-private-boundary.md` で決定された方針を、恒久的な原則として以下に組み込む:

- **principles/00-meta.md** または **principles/01-output-hygiene.md**(Phase 1 で作成予定)
  - 「Public 成果物から Private リソースへの直接リンクを作らない」原則を抽象記述
  - 「Private 情報の存在に言及する場合も URL を含めず事実のみ記載する」原則
  - ADR 0001 と並ぶ姉妹原則として、出力衛生(output hygiene)の章にまとめる選択肢あり
- **adapters/claude-code/user-level/CLAUDE.md**(Phase 3 で作成予定)
  - Claude Code 向けの具体ガイドを記述
  - 新規ドキュメント作成前のチェック手順(`grep -E 'github\.com/[^/]+/<private-repo>'` で Private リポジトリ参照の機械検出)
  - 旧設定からの移行作業時に `meta/migration-from-claude-settings.md` 1 ファイルに集約するルール
- ADR 0002 へのリンクを張り、決定経緯を辿れるようにする
- Phase 7b で機械検出を実装する場合、本 TODO に対応するエントリを `meta/TODO-for-phase-7b.md` に追加する

## チェックリスト(Phase 3 完了時)

- [ ] `principles/` に個人情報原則の抽象記述あり(ADR 0001 由来)
- [ ] `principles/` に Public/Private 境界原則の抽象記述あり(ADR 0002 由来)
- [ ] `adapters/claude-code/user-level/CLAUDE.md` に Claude Code 向け具体ガイドあり(両 ADR 反映)
- [ ] 上記から ADR 0001 / 0002 へのリンクが張られている
- [ ] Phase 7b の検討メモ:本名・呼称検出と Private リポジトリ名検出を `gitleaks` custom rule または別 lint で組むかどうか(`meta/TODO-for-phase-7b.md` への申し送り判断)
- [ ] このファイル `meta/TODO-for-phase-3.md` 自体を削除する(Phase 3 終了時)
