# ADR 0021: Harness Settings Synchronization (Claude Code 2.1.217)

- **Status**: Accepted
- **Date**: 2026-07-22
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

前回の harness 同期は ADR 0018(2.1.197 / 2026-07-01)、その後 ADR 0020 で VERSION を 2.1.206 に更新した。実インストール版は **2.1.217** まで進み、11 パッチ分(2.1.213 は欠番)の差分が蓄積した。

`update-check` command による調査(research-summarizer 4 系統への委譲 + 一次ソース裏取り: CHANGELOG raw / 公式 permissions doc / npm registry / GitHub releases API)で以下を確定した:

- **Claude Code 最新**: 2.1.217(出典: `raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`)
- **最重要差分**: v2.1.210 以降、file permission チェックは `Edit(path)` / `Read(path)` ルールのみ照合する。`Write(path)` / `NotebookEdit(path)` / `Glob(path)` ルールは「受理されるが一切マッチしない」死文となり、起動時警告が出る(出典: `code.claude.com/docs/en/permissions.md`「Edit rules cover all file-editing tools」)
- **gitleaks 最新**: v8.30.1(2026-03-21)のまま。追従漏れなし。後継 Betterleaks(`betterleaks/betterleaks`、2026-02-03 開始)は引き続き様子見
- **MCP 最新**: `@playwright/mcp` 0.0.78 / `chrome-devtools-mcp` 1.6.0 / `sequential-thinking` 2026.7.4(いずれも npm registry 実測)
- **プラグイン**: superpowers v6.1.1(2026-07-02)/ episodic-memory v1.4.2(2026-05-21)は活発、elements-of-style はコンテンツ完成型で更新なし。~~marketplace 経由の自動更新のため設定変更不要~~ ← **誤記録。ADR 0023 で訂正**: 3 件とも実機に未インストールで、更新される対象自体が存在しなかった(上流リポジトリの活発さの調査は正しいが、それを自環境の状態と取り違えた)

計画は devil-advocate の反証レビューを経て確定した(検証への positive テスト追加、breaking 確認ゲートの粒度統一、影響範囲マップ全行走査の記録)。

## Decision

### 1. 機械層を 2.1.217 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `adapters/claude-code/VERSION` | `2.1.206` | `2.1.217` | 実最新版に pin を同期 |
| `settings.json.template` deny | `Write(...)` 7 件あり | 7 件削除 | §2 参照 |
| `settings.json.template` `@playwright/mcp` | `0.0.77` | `0.0.78` | 最新へ pin(GitHub releases で breaking なしを確認。唯一の破壊的変更 0.0.72 は通過済み) |
| `mcp/servers.template.json` `chrome-devtools-mcp` | `1.4.0` | `1.6.0` | 最新へ pin(1.5.0 / 1.6.0 の release notes を確認、features / fixes のみで breaking なし) |
| `mcp/servers.template.json` `sequential-thinking` | `2025.12.18` | `2026.7.4` | 最新へ pin(2025-12-18 以降のコミットを確認、SDK bump / z.coerce 修正 / tool annotations 追加のみで breaking なし) |
| `commands/update-check.md` | 後継名なし | Betterleaks を明記 | 次回以降の定点観測対象を具体名で固定 |

### 2. 死文化した `Write(path)` deny 7 件を削除する

削除対象: `Write(~/ws/claude-settings/**)` / `Write(**/*.backup-*)` / `Write(./.env)` / `Write(./.env.*)` / `Write(~/.ssh/**)` / `Write(~/.aws/**)` / `Write(~/.gnupg/**)`。

- 7 件すべてに同一パスの `Edit(...)` deny が既存であり、v2.1.210 以降は Edit ルールが全編集ツール(Write / NotebookEdit 含む)を統治する
- 削除は update-check の更新ポリシー「古い設定は即削除(Git 履歴で追跡可能)」に従う。残置案(旧クライアント互換のための defense-in-depth)は devil-advocate が提示したが、残置の便益が「2.1.210 未満のマシンでの保護」のみで、現運用は本マシン 1 台(2.1.217)のため不採用
- **削除前の実効性確認(positive テスト)**: scratchpad 配下の使い捨てディレクトリで headless セッション(2.1.217)から `./.env` への Write を試行し、`Edit(./.env)` deny による拒否(`DENIED: File is in a directory that is denied by your permission settings.`、ファイル未作成)を実測。併せて起動時警告がまさに当該 7 件を「not matched by file permission checks」と列挙することを確認した
- 削除対象のうち `.env` / `.ssh` / `.aws` / `.gnupg` 系 5 件は `pre-edit-protect.sh` の hook カバー外であり、削除後の Write 防御は「Edit deny の統治」のみになる(claude-settings / backup 系 2 件は hook が独立防御)。上記 positive テストがこのギャップの実効を担保する

**前提条件(将来の再評価トリガー)**: 本判断は「全運用マシンが 2.1.210 以上」で成立する。2.1.210 未満のクライアントが同じ template を sync すると当該パスへの Write 保護が失われるため、別マシン追加時(TODO-for-v0.2 #9)は最新 CLI 導入を前提とする。

### 3. 影響範囲マップの走査結果(変更なし行を含む全行記録)

| 領域 | 結果 |
|------|------|
| permissions 構文 | **要対応 → 対応済み**(§2) |
| hooks matcher / フィールド構文 | 変更なし。SessionStart に `source: "fork"` が追加(2.1.214)されたが check-failure-patterns.sh は source 非依存で影響なし |
| hook event 種別 | 新規イベントなし(CHANGELOG 一次ソース確認)。PostToolUseFailure 継続 |
| skill frontmatter 仕様 | 変更なし(2.1.216 の修正は plugin skill の slash 表示のみ) |
| subagent frontmatter 仕様 | 変更なし。ネスト委譲がデフォルト無効化(2.1.217、`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`)+ 同時 20 / セッション 200 の上限追加(2.1.212 / 2.1.217)。ADR 0015 の「メイン主導の単層連鎖」前提がハーネス既定になった(設定変更不要、方針とハーネスが一致) |
| MCP server 設定スキーマ | スキーマ変更なし。pin のみ更新(§1) |
| enabledPlugins | 採用 3 プラグインとも存続(marketplace 自動更新) ← **誤記録。ADR 0023 で訂正**: 当時 3 件とも未インストールであり、marketplace 自動更新は起きていなかった |
| attribution 構文 | 変更なし(`commit` / `pr` の空文字抑止を継続) |
| `~/.claude/` ディレクトリ構造 | 変更なし |
| env 変数 | 廃止・改名なし。新設の上限系(`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` 等)は既定値で運用 |
| デフォルトモデル / effort | 影響なし(Fable 5 / fallback Opus 4.8 / xhigh を維持。ADR 0016 の判断を継続) |
| Task tool `mode` 非推奨(2.1.212) | リポジトリ内参照ゼロ(grep 済み)で影響なし |

### 4. 不採用の判断

| 候補 | 判断 | 理由 |
|------|------|------|
| Betterleaks への乗り換え | 据え置き | ローンチ半年未満。config 互換・pre-commit 対応・CI 実績の様子見。ADR 0018 の「2026 末を目安に再評価」を継承し、update-check command に後継名を明記して定点観測化 |
| 新規プラグイン Context7 | 不採用 | ドキュメント参照・メモリ用途が episodic-memory と重複し、ADR 0003 の 2 層メモリ構成(auto memory + episodic-memory)と衝突。運用者確認済み(2026-07-22) |
| 新規プラグイン Frontend Design | 不採用 | 公式 marketplace インストール数上位だが三次情報のみで一次検証未了。コンテキスト消費増のコストが先行。運用者確認済み(同上)。次回 update-check で再評価 |
| 新規 MCP(Context7 / Figma / Brave Search) | 不採用 | 三次情報のみ。既存構成の代替を要する決定打なし |
| 新 UI 系設定(`emojiCompletionEnabled` / `vimInsertModeRemaps` / `axScreenReader` / `wheelScrollAccelerationEnabled`) | 不採用 | 既定値で問題なし。個人運用に不要 |
| `sandbox.filesystem.disabled`(2.1.216) | 不採用 | ファイルシステム分離を弱める方向の設定であり、ガードレール多層化の方針に反する |
| 調査報告中の `Notification` hook / `Tool(param:value)` 構文 / `claude mcp login` | 非採用(記録のみ) | research-summarizer の報告にあったが CHANGELOG 一次ソースで確認できず(docs 要約経由の混入と推定)。次回 update-check で docs 側の存在確認から再評価 |
| pre-commit ecosystem の Dependabot 対応(2026-03) | 不採用 | pre-commit-hooks に新規 hook なし。現行 hooks 構成に影響なし |

## Consequences

- **Positive**: 方針層と機械層の世代整合が回復。起動時警告 7 件が消え、deny リストが実効ルールのみになる(死文の排除は「LLM の自制に頼らない物理ブロック」の可読性を保つ)。MCP pin の遅れを解消。ADR 0015 の単層委譲前提がハーネス既定と一致したことを記録
- **Negative**: 2.1.210 未満のクライアントを将来このまま追加すると、hook 非カバーの機密パス(`.env` / `.ssh` / `.aws` / `.gnupg`)への Write 保護が Edit ルール統治の成立に依存する。§2 の前提条件で管理する
- **Neutral**: template 更新はコミット時に `tools/sync-settings.sh`(ADR 0017)経由で配置済み `~/.claude/settings.json` へ自動反映される。プラグインは marketplace 自動更新のため本 ADR の対象外

## Related

- [ADR 0015](./0015-delegation-chain-and-mandatory-delegation.md) — 単層委譲前提のハーネス既定化(§3)
- [ADR 0016](./0016-fable-5-harness-settings-sync.md) / [ADR 0018](./0018-harness-sync-2.1.197.md) — 先行する harness 同期(Betterleaks 据え置き判断の継承元)
- [ADR 0017](./0017-settings-auto-sync.md) — template 更新の自動反映機構
- [ADR 0020](./0020-failure-hook-event-migration.md) — VERSION 2.1.206 の由来
- [ADR 0003](./0003-memory-architecture.md) — Context7 不採用の判断軸(2 層メモリ構成)
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — deny 移行 / playwright pin
- [`adapters/claude-code/user-level/mcp/servers.template.json`](../../adapters/claude-code/user-level/mcp/servers.template.json) — MCP pin
- [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) — pin を 2.1.217 に同期
- [`adapters/claude-code/user-level/commands/update-check.md`](../../adapters/claude-code/user-level/commands/update-check.md) — Betterleaks の定点観測化
