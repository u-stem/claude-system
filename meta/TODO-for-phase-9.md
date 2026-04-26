# Phase 9 への申し送り TODO

このファイルは Phase 1 / Phase 2 / Phase 3 等での運用・整理判断のうち、
Phase 9(検証・レトロ・整備)で一括判断・整理すべきものを記録する場所。

## 「旧資産からの継承」セクションの整理判断

`principles/` および `practices/` の各ファイルに **「旧資産からの継承」** セクションを設けているが、価値の濃淡が混在している:

- 意味のあるもの: 旧資産で個別 heuristic として表現されていたものを抽象化した経緯を残し、後から「この原則の根拠は何か」を辿れる
- プレースホルダ的なもの: 「旧資産には対応する独立章がなかった」「同居していた」のような事実記述のみで、後から読んでも judgment が働かない

Phase 9 のレトロで以下を一括判断する:

- [ ] 各ファイルの「旧資産からの継承」セクションを目視レビュー
- [ ] 削除する / 「該当なし」と明記する / 別ファイルに外出しする(例: `meta/migration-from-claude-settings.md` への集約)を選ぶ
- [ ] 整合した方針に従って一括書き換え

### 判断時の補助情報

- Phase 1.5 として独立フェーズ化する案もあったが、即時の作業影響なしとして見送り済み(Phase 3 時点)
- Phase 9 で他の整理タスクと並行実施する想定
- 「旧資産」の具体的な参照は ADR 0002(Public/Private 境界)に従い、URL・git remote を含めない記述になっているか確認する

### 関連

- [`principles/00-meta.md`](../principles/00-meta.md) — 共通フォーマット 6 セクションの定義(うち 1 つが「旧資産からの継承」)
- [`meta/migration-inventory.md`](./migration-inventory.md) — 旧 claude-settings の取り込み判断台帳
- [`meta/migration-from-claude-settings.md`](./migration-from-claude-settings.md) — 旧資産との関係を集約するファイル
