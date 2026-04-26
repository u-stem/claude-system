---
name: japanese-tech-writing
description: 日本語の技術文書を書く(README / ADR / docs)
recommended_model: sonnet
---

# 日本語テクニカルライティング

README / ADR / 設計文書 / リリースノートを日本語で書くときの作法。
言語非依存のスタイル原則は [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)、コンテキスト経済は [`principles/01-context-economy.md`](~/ws/claude-system/principles/01-context-economy.md)。

## 目的

意図が一意に伝わる日本語技術文書を書く。読者に「結論まで読み続けるか」「途中で離脱できるか」の選択肢を残す。

## いつ発動するか

- 日本語の README / ADR / 設計ドキュメント / 申し送り / リリースノートを書くとき
- 既存の日本語ドキュメントを改訂するとき
- AI が生成した日本語文をレビュー / 修正するとき

## 手順

### 1. 文の長さと構造

- **1 文 60 字以内**を目安(意味で切る)
- 主語と述語の距離を縮める
- 入れ子の修飾を避ける(複雑なら 2 文に分ける)
- 体言止めは見出し・箇条書きに留め、本文では避ける

### 2. 結論先行(BLUF: Bottom Line Up Front)

- 段落の冒頭に結論を置く
- 背景・経緯は後段
- 読者が途中で十分情報を得て止まれる構造にする

### 3. 表記ゆれを避ける

| 望ましい | 避ける |
|----------|--------|
| 半角英数 + 全角文字の間に空白 | 詰めすぎ・空きすぎが混在 |
| 「行う」「実施する」のいずれかに統一 | ドキュメント内で混在 |
| 「ですます」「である」のどちらかに統一 | 段落ごとに切り替わる |
| カタカナ語と英語のどちらかに統一 | 同じ概念を混在表記 |
| 全角記号 `（）「」` または半角 `()""` を統一 | 混在 |

ADR や principles は「である」、README や user 向け説明は「ですます」で書く(本リポジトリの慣習)。

### 4. 過剰装飾を避ける

- 絵文字禁止(明示要求がある場合のみ)
- 「深掘り」「活用」「レバレッジ」「させていただきます」は使わない
- 強調(太字)を使うのは「ここを見落とすと全体が崩れる」要点のみ
- 過剰な区切り線・見出しレベルの濫用を避ける
- 称賛・謝罪・「素晴らしい質問です」のような前置きを書かない

### 5. 数値・固有名詞・コード片

- 半角数字、コード片はバッククォートで囲う
- 固有名詞(製品名・ライブラリ名)は原語表記、初出時のみ括弧で短い説明
- バージョン番号は完全表記(`Claude Code 2.1.119`)、略称は使わない

### 6. ADR / principles で守る追加規約

- ADR 0001(本名・新規連絡先を含めない)、ADR 0002(Public→Private リンクを作らない)を遵守
- principles / practices には特定ツール用語を出さない([`meta/forbidden-words.txt`](~/ws/claude-system/meta/forbidden-words.txt))
- adapter 層でのみ固有用語を使う

### 7. レビュー観点

- 同じことを 2 回書いていないか(冗長は信号比を下げる)
- 抽象→具体の順か(逆だと読み手が文脈を持てない)
- 「なぜ」が書かれているか(「何を」だけだと判断材料が消える)
- 5 年後の自分が読んで意味が通じるか(時相依存の表現「最近」「現状の」を避ける)

## チェックリスト

- [ ] 1 文 60 字以内が大半
- [ ] 段落冒頭に結論
- [ ] 「ですます」「である」が文書内で統一されている
- [ ] 英数字と全角の間の空白が統一
- [ ] 絵文字 / 過剰装飾 / 称賛 / 謝罪が含まれていない
- [ ] 「深掘り」「活用」「レバレッジ」「させていただきます」を含まない
- [ ] 本名・personal email literal・呼称が含まれていない(ADR 0001)
- [ ] Private リソースへの URL / git remote が含まれていない(ADR 0002)
- [ ] principles / practices 配置の文書なら禁止語が混入していない

## アンチパターン

- 1 文に複数の主語・複数の主張を詰め込み、修飾の入れ子で読み返さないと意味が取れない
- 結論を最後に置き、読者が最後まで読まないと判断できない
- 「弊社では」「素晴らしい」「させていただきます」等のビジネス文体で技術内容を埋もれさせる
- 同じ概念を「コミット」「commit」「commitment」のように表記揺らしする
- 5 年後に意味不明になる時相表現(「最新の」「最近の」)を見出しに使う

## 関連

- [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md) — 過剰装飾禁止、Why ベースのコメント
- [`principles/01-context-economy.md`](~/ws/claude-system/principles/01-context-economy.md) — 信号比、出力もコンテキストを消費する
- [`meta/decisions/0001-anonymity-policy.md`](~/ws/claude-system/meta/decisions/0001-anonymity-policy.md)
- [`meta/decisions/0002-public-private-boundary.md`](~/ws/claude-system/meta/decisions/0002-public-private-boundary.md)
- [`meta/forbidden-words.txt`](~/ws/claude-system/meta/forbidden-words.txt) — principles / practices で機械検出される禁止語
