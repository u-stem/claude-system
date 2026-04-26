---
name: pr-description
description: Pull Request の本文(Summary / Test plan)を書く
recommended_model: sonnet
---

# PR Description

Pull Request の本文を、**レビュアが 30 秒で本質を把握できる**形に整える skill。
コミット規約は別 skill `commit-conventional`、レビュー側の観点は別 skill `pr-review`(将来の Tier 1 候補)。

## 目的

差分を見れば分かる「何を変えたか」ではなく、「**なぜ変えたか**」「**どうテストしたか**」「**何に注意してレビューしてほしいか**」を伝える。

## いつ発動するか

- PR を新規作成するとき(`gh pr create`)
- 既存 PR の Description を更新するとき
- ドラフト PR を ready for review に上げるとき

## 手順

### 1. 構成

```markdown
## Summary
- (3 行以内、結論先行)

## Why
- (背景・制約・代替案を捨てた理由)

## Changes
- (主要な変更点を箇条書き、ファイル粒度ではなく機能粒度)

## Test plan
- [ ] 手動確認した手順
- [ ] 自動テストを追加した場合のテスト名
- [ ] エッジケース確認結果

## Notes for reviewer
- (特に見てほしい設計判断 / 妥協した点)

## Related
- Closes #<issue>
- ADR: meta/decisions/00NN-...
```

### 2. Summary は 30 秒ルール

- 3 行以内、結論先行
- レビュアが Summary だけ読んで「どこを最優先で見るか」を判断できること
- 「機能 X を追加」「バグ Y を修正」では不十分。**何が嬉しくなったか**を書く

### 3. Why を必ず書く

- 「Issue #123 を解決」だけでは Why にならない(Issue を開かないと分からない)
- 制約(時間 / 互換性 / 既存設計との整合)、捨てた代替案、なぜこの実装に落ち着いたか
- ADR がある場合はリンク([ADR 0003](../../meta/decisions/0003-memory-architecture.md) のように相対パス)

### 4. Test plan はチェックボックスで

- レビュア・本人が後から確認しやすい形
- 「テストした」だけでなく「何をどう確認したか」
- E2E / 統合テストを通したかも記載
- UI 変更なら**スクリーンショット**を添付(Before/After)

### 5. Notes for reviewer で時間を節約させる

- 設計上の trade-off を先に明示
- 「ここは別 PR で改善予定」「この命名は後で見直したい」
- レビュアが指摘する前に「分かっている」を書く(ノイズ削減)

### 6. CI / リンクのチェック

- CI が緑か(赤なら理由を Notes に記載)
- Issue / ADR のリンクが正しいか
- 機密情報・本名・personal email literal が混入していないか(ADR 0001)
- Public→Private リンクが含まれていないか(ADR 0002)

### 7. `gh pr create` の使い方

```bash
gh pr create --title "feat(skills): add Tier 1 skills" --body "$(cat <<'EOF'
## Summary
...
EOF
)"
```

- HEREDOC で改行込みを安全に渡す
- `--draft` で WIP 状態で開く選択肢あり

## チェックリスト

- [ ] Summary が 3 行以内、結論先行
- [ ] Why セクションがあり、Issue リンクだけに頼っていない
- [ ] Changes が機能粒度で書かれている(ファイル列挙ではない)
- [ ] Test plan がチェックボックス形式で具体
- [ ] Notes for reviewer で trade-off / 既知の限界を明示
- [ ] Related に関連 Issue / ADR / Phase が貼られている
- [ ] CI 結果と整合(緑なら問題なし、赤なら理由明記)
- [ ] 機密情報 / 本名 / personal email literal / Private URL が含まれていない
- [ ] UI 変更があるならスクリーンショット添付

## アンチパターン

- Summary が「機能 X を追加」一行のみ(レビュアが diff から読み取らされる)
- Why を Issue リンクに丸投げ(Issue が削除・private 化されたら経緯不明)
- Test plan が「テストしました」のみ(何を確認したか不明)
- Notes for reviewer 無しで「全部見て」状態(レビュー時間が肥大)
- 絵文字 / 過剰装飾 で本質が埋もれる
- HEREDOC を使わず `\n` を escape して可読性を犠牲にする

## 関連

- [`adapters/claude-code/user-level/skills/commit-conventional/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/commit-conventional/SKILL.md) — コミット側の規約
- [`adapters/claude-code/user-level/skills/japanese-tech-writing/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/japanese-tech-writing/SKILL.md) — 日本語表現
- [`practices/commit-conventions.md`](~/ws/claude-system/practices/commit-conventions.md) — Why を残す規律
