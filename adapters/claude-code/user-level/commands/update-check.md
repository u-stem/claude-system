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
- **宣言と実体の一致確認**: `enabledPlugins` は宣言にすぎず `claude plugin install` が別途必要(ADR 0023)。`tools/doctor.sh` の「declared plugins vs installed」が WARN していないか、`tools/setup-plugins.sh --dry-run` で差分が出ないかを見る
- **持ち込み能力の棚卸し**: プラグイン更新時は hooks / MCP / subagent / skill の増減を確認する。プラグイン由来の hook は `permissions.deny` の統治外で、自前 hook 群の閉包から外れる(ADR 0023 §4)
- **per-skill 無効化機構の有無**: 現状 `disableBundledSkills`(一括)と `disableSkillShellExecution` しかなく、個別 skill を切れない。**機構が追加されたら**、自前規約と重複する 7 skill(`test-driven-development` / `verification-before-completion` / `requesting-code-review` / `receiving-code-review` / `writing-skills` / `dispatching-parallel-agents` / `subagent-driven-development`、計 1,244 bytes)を無効化する(ADR 0024 §4)
- **`superpowers` の skill 競合**: 自前 skill・単層委譲規約と重複する skill(`dispatching-parallel-agents` / `subagent-driven-development` / `test-driven-development` / `verification-before-completion` / `writing-skills` 等)の増減を確認し、`tools/loop-report.sh` で `spawn_depth >= 2` が発生していないか点検する(ADR 0023 §5 の受け入れ条件)

### 3. MCP サーバー

- 採用中の MCP(`chrome-devtools` / `playwright` / `sequential-thinking`)の新バージョン
- 新規 MCP の検討余地
- 既存 MCP の代替・改善
- **宣言系統の pin は実機に届かない**(ADR 0026 で実測): `tools/setup-mcp.sh` はサーバー名でしか冪等判定せず版を見ないため、一度登録した後に `mcp/servers.template.json` の pin を上げても `claude mcp add` は走らない。また `tools/doctor.sh` は同ファイルを `jq empty` の構文チェックにしか掛けておらず、`enabledPlugins` に入れた宣言↔実体検査(ADR 0023 §7)の MCP 版が無い。**pin を更新したら `claude mcp list` で実機の版を目視確認する**
- **パッケージ版を上げるときは公開日を見る**: `practices/supply-chain-hygiene.md` の公開後 7 日ルールは、`bunx` / `claude mcp add` 経路では機械的に守られない(`check-package-age.sh` は `bun add` 系にしか発火せず、見ているのはパッケージの**初**公開日)。`npm view <pkg> time` で当該版の公開日を確認する

### 4. パフォーマンス / コスト

- 新しい最適化オプション(prompt caching / context compaction 設定 等)
- トークン効率化の手法
- モデル選択基準の見直し(`practices/model-selection.md` への影響)

### 5. ガードレール

- gitleaks の更新(v8 は feature-complete 宣言済み = 今後はセキュリティパッチのみ。新機能は来ない前提で、セキュリティ修正リリースのみ追従する)
- gitleaks 後継 / 代替の動向(後継は Betterleaks = `betterleaks/betterleaks`)。**手順・判断基準・先送り時の作法は [`~/ws/claude-system/meta/TODO-for-v0.2.md`](~/ws/claude-system/meta/TODO-for-v0.2.md) 項目 19 に転記済み**(ADR 0026)。ADR 本文の散文に置いたままでは 2 回連続で先送りされたため、**次回の harness sync では最初に着手する**
- pre-commit-hooks の新規 hook
- Phase 7b で実装した hooks との整合
- `sandbox.network.strictAllowlist`(v2.1.219 追加)の採用可否を再評価(ADR 0022 で不採用: allowlist 列挙対象が広く「静かなツール不能」の失敗モードが先行。エコシステムの運用実績と設定粒度の改善を定点観測する)。v2.1.229 でドメインリストの綴り解釈が fail-closed 化し IPv6 リテラルは角括弧必須になった — 粒度の改善方向ではあるが列挙対象の広さは変わらないため据え置き継続(ADR 0026)
- `crossSessionInbound`(v2.1.224 追加、値は `accept` / `hold` / `refuse`)の採用可否。**トリガーはセッション間メッセージングの使用開始**(ADR 0023 で据え置き: 現状この機能を使う運用が無く、既定は「両セッションの permission-mode クラスから毎回判断」という動的挙動でその決定表を未取得のため。使い始める時点で明示値を決める)。併せて `dialogExpiry`(既定 `5m`、期限切れで held メッセージは drop)の妥当性も見る。v2.1.229 で `ListAgents` が他マシンの Remote Control セッションを `offline`、クラウドセッションを `cloud` と列挙するようになったため、**複数マシン運用を始めた時点が実質的なトリガー**になる(ADR 0026)

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
