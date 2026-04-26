---
name: review
description: 指定ファイルの簡易コードレビュー
---

以下のファイルを簡易レビューする: $ARGUMENTS

重大な問題のみを指摘し、簡潔に報告する。
詳細なレビューが必要な場合は **`code-reviewer` subagent**(7 観点 / 重大度別出力)を使用する。

## 簡易レビュー観点

- 構文 / 型エラーの懸念
- 明らかなセキュリティ問題(SQL インジェクション / 機密のハードコード等)
- 明らかな誤魔化し(`@ts-ignore` の理由なし / 空 catch / `// あとで直す` 等)
- デッドコード(コメントアウト / 未使用 import)

## 出力

```
## 簡易レビュー結果
- 問題: <count>(重大: <n>)

### 重大(必須修正)
- <file:line> - <問題> - <修正案>

### 軽微 / 提案
- <file:line> - <提案>

### 詳細レビュー推奨
変更行 100 行超 / 5 ファイル超なら `code-reviewer` subagent を起動推奨
```

## 関連

- subagent: `code-reviewer`(詳細レビュー)
- skill: `security-audit`(セキュリティ観点)
- skill: `pr-description`(PR 本文側)
