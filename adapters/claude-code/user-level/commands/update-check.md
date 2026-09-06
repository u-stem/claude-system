---
name: update-check
description: Claude Code の最新情報を調査し、設定の更新提案を行う
---

# 設定更新チェック

claude-system の機械層をハーネスの現行版に追随させる調査手順。結果は `meta/decisions/README.md`(決定索引)の該当行を更新し、索引にある決定を覆すときだけ ADR を起票する(`practices/adr-workflow.md`)。

## 0. 先に計測する

- `claude --version` と `adapters/claude-code/VERSION` の差分。上流 CHANGELOG はローカルキャッシュ `~/.claude/cache/changelog.md` にあるので、差分範囲を全文読む(要約に頼らない)
- `claude -p /skill-doctor` で自前 skill / command と plugin skill の使用回数と listing コストを取る。180 日 0 回のものは削除候補(2026-09-06 の剪定基準)
- `bash tools/doctor.sh` と `bash tools/loop-report.sh` で drift と委譲の実態を見る

## 1. Claude Code 本体

- 新設・変更・廃止された settings キー、hook event、subagent / skill / command の frontmatter 仕様
- `adapters/claude-code/README.md` の影響範囲マップを全行走査し、変更なしの行も「変更なし」と記録する
- hook payload の前提(`agent_type` による subagent 判定など)は合成 payload のテストでは証明にならない。組み込み `Explore` に `git push --dry-run` を実行させ、`pre-bash-guard.log` に deny が記録されることで確認する

## 2. プラグイン

- `claude plugin list` と `// auditedPluginVersions` の一致(`tools/doctor.sh` が WARN する)。上流の版は `gh api repos/<owner>/<repo>/releases` で公開日を確認し、公開後 7 日未満なら待つ
- 更新したら持ち込み能力(skills / hooks / agents / MCP)を棚卸しして `// auditedPluginVersions` を更新する。プラグイン由来の hook は `permissions.deny` の統治外
- **公開日は自分で確認する**: `practices/supply-chain-hygiene.md` の 7 日ルールを機械的に守るのは `bun add` 系だけ(`check-package-age.sh`)。`claude plugin install` / `bunx` / `brew` 経路は手動で守る
- superpowers の重複 skill 7 本を個別に無効化する案は 2026-09-06 に閉じた。`/skill-doctor` で 5 本が現役と判明し、`skillOverrides` は plugin skill を対象外、`Skill(name)` deny は description を listing に残すため利得がない。再評価トリガー: 使用回数が 0 に落ちた skill が出たとき

## 3. パフォーマンス / コスト

- prompt cache / auto-compact / effort の新オプション。claude.ai サブスクリプションでは `promptCacheTtl` と `ENABLE_PROMPT_CACHING_1H` は no-op(API key / Bedrock / Vertex / Foundry 向け)
- モデル世代が変わったら `practices/model-selection.md` 手順 8 に従い subagent の tier を再評価する(2026-09-06: 反証役と最終ゲートを `fable` に)

## 4. ガードレール

- 秘密検出はローカル層(`tools/setup.sh` / `tools/doctor.sh` / pre-commit テンプレート)が Betterleaks(gitleaks 後継、`.gitleaks.toml` をそのまま読む)、CI は gitleaks-action のまま。CI 側の置換は保守された Action を確認できたら行う(TODO 参照)
- `sandbox.network.strictAllowlist`: 不採用継続(allowlist 列挙対象が広く「静かなツール不能」が先行する)。粒度の改善を定点観測
- `crossSessionInbound` / `dialogExpiry`: 未使用のため据え置き。複数マシン運用の開始が実質的なトリガー
- MCP は採用しない(ブラウザは `claude-in-chrome`、GitHub は `gh` CLI)。宣言系統は 2026-09-06 に撤去した

## 出力形式

```markdown
# Update Check 結果 (YYYY-MM-DD)

## 新機能・変更点
- <項目>(出典: <URL>)

## 推奨アクション
- [ ] <アクション>(影響ファイル: ...)

## 不採用の判断
- <候補>(理由: ...)
```

## 更新ポリシー

- 古い設定は即削除する(Git 履歴で追跡できる)。追加・削除は `meta/CHANGELOG.md` に記録する
- VERSION 更新は `adapters/claude-code/README.md` の移行プレイブックに従う
- 外部調査は `research-summarizer` に委譲し、原典 URL 付きで受け取る。ローカルキャッシュの CHANGELOG と突き合わせる
