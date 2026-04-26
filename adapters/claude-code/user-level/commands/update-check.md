---
name: update-check
description: Claude Code の最新情報を調査し、設定の更新提案を行う
---

# 設定更新チェック

claude-system の設定を最新のベストプラクティスに更新するため、以下の調査を行う。

## 調査項目

### 1. Claude Code 本体

- 最新バージョンとリリースノート
- 新機能・新設定オプション
- 非推奨になった設定
- `~/ws/claude-system/adapters/claude-code/VERSION` との差分

### 2. プラグイン

- 公式プラグイン / superpowers-marketplace 等の新規追加
- 既存プラグイン(`elements-of-style` / `episodic-memory` / `superpowers`)のアップデート
- 推奨プラグインの変更

### 3. MCP サーバー

- 採用中の MCP(`chrome-devtools` / `playwright`)の新バージョン
- 新規 MCP の検討余地
- 既存 MCP の代替・改善

### 4. パフォーマンス / コスト

- 新しい最適化オプション(prompt caching / context compaction 設定 等)
- トークン効率化の手法
- モデル選択基準の見直し(`practices/model-selection.md` への影響)

### 5. ガードレール

- gitleaks の新ルール / 新バージョン
- pre-commit-hooks の新規 hook
- Phase 7b で実装した hooks との整合

## 調査ソース

調査は **`research-summarizer` subagent** に委譲することを優先(原典 URL 付き要約で監査可能性を担保)。

主な情報源:

1. https://github.com/anthropics/claude-code/releases
2. https://docs.claude.com/(または公式ドキュメント)
3. https://github.com/anthropics/claude-plugins-official(または該当 marketplace)
4. https://github.com/gitleaks/gitleaks/releases
5. Web 検索で最新のベストプラクティス

## 出力形式

```markdown
# Update Check 結果 (YYYY-MM-DD)

## 新機能・変更点
- <項目>(出典: <URL>)

## 推奨アクション
- [ ] <アクション>(影響ファイル: ...)

## 不採用の判断(検討したが見送り)
- <候補>(理由: ...)

## 参考リンク
- <URL>
```

## 更新ポリシー

- **古い設定は即削除**(Git 履歴で追跡可能)
- 非推奨になった設定は `meta/CHANGELOG.md` に記録して削除
- 新しい設定を追加したら `meta/CHANGELOG.md` を更新
- 重大判断(設計方針の変更)は ADR を起票(`adr-writing` skill)
- VERSION 更新は `adapters/claude-code/README.md` の「移行プレイブック」10 ステップに従う

## 関連

- subagent: `research-summarizer`(調査委譲)
- skill: `adr-writing`(重大判断の記録)
- skill: `dependency-review`(依存追加・更新時)
- adapter: `~/ws/claude-system/adapters/claude-code/README.md`(影響範囲マップ + 移行プレイブック)
