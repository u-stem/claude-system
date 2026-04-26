---
name: commit-conventional
description: Conventional Commits 規約に従ってコミットを切る
recommended_model: sonnet
---

# Conventional Commits

`<type>: <日本語の説明>` 形式の Conventional Commits 規約でコミットを切る skill。
抽象規約は [`practices/commit-conventions.md`](~/ws/claude-system/practices/commit-conventions.md)、根拠は [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md)。

## 目的

1 コミット 1 判断単位を維持し、後から判断境界を読み取れる履歴を残す。

## いつ発動するか

- コミットを切るとき
- ブランチをマージするとき(squash 時のメッセージ作成)
- AI と協働した成果物を記録に残すとき

## 手順

1. **差分の整理**: `git status` と `git diff --cached` でステージ内容を確認。スコープ外の変更が混じっていれば `git restore --staged <file>` で外す
2. **判断単位への分割**: 異なる判断(feat と refactor 等)が混ざっていれば、ステージを分割して**複数コミットに切る**
3. **type を選ぶ**:

   | type | 用途 |
   |------|------|
   | `feat` | 新機能、新しい principle / practice / skill / subagent / hook / template |
   | `fix` | バグ修正 |
   | `docs` | ドキュメントのみの変更 |
   | `refactor` | 振る舞いを変えない構造変更 |
   | `chore` | 構築、自動化、雑務 |
   | `test` | テストの追加・修正 |

4. **scope を選ぶ(任意)**: `feat(skills):` `feat(adapters):` `docs(meta):` `chore(meta):` のように変更領域を括弧書きで補う
5. **件名は短く具体に**: 件名は 50〜70 字、句点なし、命令形 / 体言止めで「何を変えたか」を書く
6. **本文に Why を書く**: なぜこの変更が必要か、どの代替案を捨てたか、影響範囲。HEREDOC で改行込みで書くのが安全
7. **機密混入チェック**: `git diff --cached` で API キー・トークン・本物の認証情報・本名・personal email の literal が含まれていないか確認(ADR 0001)
8. **検証の証跡**: 大きな変更には検証コマンドの実行結果を本文か関連ドキュメントに残す
9. **コミット**: `--no-verify` は禁止(settings.json で deny 済み)、`--amend` は基本使わず新コミットを切る
10. **コミット作者欄**: `git config` の global 値を継承、ローカル override しない(ADR 0001)

## 件名テンプレート

```
<type>(<scope>): <短い動詞 / 体言止めで何を変えたか>
```

例:
- `feat(skills): add Tier 1 skills`
- `docs(meta): expand root CLAUDE.md`
- `chore(meta): retire TODO-for-phase-3`
- `fix(adapters): correct settings.json deny pattern for backup files`

## 本文テンプレート(HEREDOC 推奨)

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <件名>

- 変更点 1(Why)
- 変更点 2(Why)
- 影響範囲・関連 Phase / ADR / Issue
EOF
)"
```

## チェックリスト

- [ ] 1 コミット 1 判断単位に収まっている(複数判断は分割)
- [ ] type / scope / 件名 / 本文(必要なら)を埋めた
- [ ] 件名は短く具体(50〜70 字目安)
- [ ] 本文に Why が書かれている
- [ ] 認証情報・personal email literal・本名が差分に含まれていない(ADR 0001)
- [ ] スコープ外の「ついで」変更が混入していない
- [ ] 検証(lint / typecheck / test 等)を通してから commit している
- [ ] `--no-verify` を付けていない(settings.json で deny 済み)
- [ ] 既存コミットの amend ではなく新コミット(post-commit hook の整合性のため)

## アンチパターン

- 件名に絵文字 / 装飾を入れる
- 本文を空にして Why を残さない
- 機能追加とリファクタを 1 コミットにまとめる
- 検証を通さずに commit を切る
- 同じ趣旨の細切れコミットを濫造する(逆方向の過剰分割)

## 関連

- [`practices/commit-conventions.md`](~/ws/claude-system/practices/commit-conventions.md) — 抽象規約
- [`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md) — 根拠原則
- [`meta/decisions/0001-anonymity-policy.md`](~/ws/claude-system/meta/decisions/0001-anonymity-policy.md) — commit author の取り扱い
