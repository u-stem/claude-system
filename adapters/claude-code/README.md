# claude-code adapter

`principles` と `practices` を Claude Code(Anthropic CLI)の語彙に翻訳して具体化する適応層。

特定ツール固有の用語(CLAUDE.md / skill / subagent / hook / settings.json / slash command / MCP / `~/.claude/`)が登場するのは**この層以下のみ**(`meta/forbidden-words.txt` で機械検出される)。

## 前提バージョン

[`./VERSION`](./VERSION) を参照(現在: 2.1.263)。

VERSION 更新時のチェックリストは [Claude Code 仕様変更時の影響範囲マップ](#claude-code-仕様変更時の影響範囲マップ) に従う。この行と `VERSION` の一致は `tests/check-doc-parity.sh` が機械検査する(ADR 0022 → 0023 間で 2 重にずれた前科があるため / ADR 0026)。

## 利用している Claude Code 機能

| 機能 | 利用箇所 | 役割 |
|------|----------|------|
| 階層的 CLAUDE.md(user-level / project-level) | `user-level/CLAUDE.md` | 全プロジェクト共通の出力衛生・作業フロー・禁止事項を定義 |
| `@<file>` 参照 | 各種ドキュメント内 | 段階的開示の入口 |
| skill(段階的開示で読まれる能力単位) | `user-level/skills/` | commit / ADR / Next.js+Supabase 等の能力単位 |
| subagent(独立コンテキストの補助エージェント) | `subagents/` | code-reviewer・doc-writer・security-auditor 等 |
| 組み込み `Explore` / `/code-review` / `/security-review` | ハーネス組み込み(本リポジトリにファイル実体なし) | 内部探索・簡易レビュー・セキュリティセルフチェック。CLAUDE.md を読まないため軽量 |
| settings.json(permissions / hooks / env / enabledPlugins / attribution) | `user-level/settings.json.template` | permissions.deny で物理ブロック、hooks で機械的防御 |
| permissions.deny / allow | settings.json 内 | LLM の自制に頼らず物理的に書き込みを拒否 / permission prompt の抑制 |
| attribution(`commit` / `pr`) | settings.json 内 | commit/PR から claude.ai セッション URL(harness 自動 attribution)を抑止(ADR 0002 / 0018) |
| hooks(SessionStart / PreToolUse / PostToolUse / PostToolUseFailure / Stop / StopFailure / SubagentStop) | `user-level/hooks/` | typosquatting 防御・失敗フィードバックループ・dispatcher パターン |
| slash command | `user-level/commands/` | `review-loop` / `team` / `update-check` の 3 本(用途は後述の「slash command 一覧」) |
| プラグイン管理(`enabledPlugins` / `extraKnownMarketplaces`) | settings.json 内 + `tools/setup-plugins.sh` | superpowers / elements-of-style / episodic-memory。**宣言と導入は 2 段階**(settings に宣言 → `setup-plugins.sh` が `claude plugin install` を実行)。宣言だけでは入らない(ADR 0023) |

MCP(Model Context Protocol)は不採用([`meta/decisions/0003-memory-architecture.md`](../../meta/decisions/0003-memory-architecture.md))。`settings.json.template` に MCP サーバー設定は存在せず、登録用の設定ファイル・スクリプトも持たない。

## slash command 一覧

| command | 用途 |
|---------|------|
| [`review-loop`](./user-level/commands/review-loop.md) | レビュー→修正→レビューの反復ループ(立て直し既定 + 修正確認の継続 + 最終ゲート) |
| [`team`](./user-level/commands/team.md) | 委譲チェーン(計画→反証→実装→レビュー→ゲート)をメイン主導で回す |
| [`update-check`](./user-level/commands/update-check.md) | Claude Code の最新情報を調査し、設定の更新提案を行う |

ごく小さく可逆な単発レビューは組み込み `/code-review` で足りる(本リポジトリの command には含めない)。

## ディレクトリ構成

```
adapters/claude-code/
├── README.md              本ファイル
├── VERSION                前提バージョン(プレーンテキスト)
├── user-level/            ~/.claude/ にリンクされる個人共通設定
│   ├── CLAUDE.md          全プロジェクト共通指示(完了報告・出力衛生・禁止事項等)
│   ├── settings.json.template  permissions / hooks / env の雛形
│   ├── skills/            能力単位を配置
│   │   └── _index.md
│   ├── commands/          slash command を配置
│   └── hooks/             機械的防御を配置
│       └── _README.md
├── subagents/             ~/.claude/agents/ にリンクされる補助エージェント
│   └── _index.md
├── project-templates/     新規プロジェクト用のひな形
└── project-fragments/     既存プロジェクトに追記される断片
```

## 設定階層とリンク構成

```
~/.claude/                                                  (ディレクトリ)
├── CLAUDE.md   → adapters/claude-code/user-level/CLAUDE.md  (symlink)
├── skills      → adapters/claude-code/user-level/skills      (symlink)
├── hooks       → adapters/claude-code/user-level/hooks       (symlink)
├── commands    → adapters/claude-code/user-level/commands    (symlink)
├── agents      → adapters/claude-code/subagents              (symlink)
└── settings.json                                              (cp 配置、マシン固有値の差し込みのため symlink にしない)
```

この構成への切り替えは 2026-05-04 に完了済み。張り直し手順はルート [`README.md`](../../README.md) の「シンボリックリンク切り替え」、ロールバックは `tools/migrate/rollback-from-claude-system.sh`。

## Claude Code 仕様変更時の影響範囲マップ

Claude Code がアップデートされた場合、以下を順に確認する:

| 仕様変更領域 | 影響を受けるファイル | 確認手順 |
|--------------|----------------------|----------|
| `permissions.deny` / `allow` の構文 | `user-level/settings.json.template` | 公式ドキュメントの permissions セクション差分確認 → deny ルールの構文整合 → `jq` で JSON 妥当性 |
| `hooks.<event>` の matcher / フィールド構文 | `user-level/settings.json.template`, `user-level/hooks/*.sh`(Phase 7b) | 各 hook event のスキーマ差分確認 → 対応 hook の入出力契約の更新 |
| 利用可能な hook event 種別 | 同上 | 新 event 追加時は guardrail 設計を再評価(PostToolUseFailure は v2.1.206 で存在を実測確認、導入バージョンは未特定。log-bash-failure.sh が依存) |
| skill の frontmatter 仕様 | `user-level/skills/*/SKILL.md` | name / description のフィールドが廃止・追加されていないか |
| subagent の frontmatter 仕様 | `subagents/*.md`(Phase 5) | name / description / tools / model / effort のフィールド整合 |
| slash command の frontmatter 仕様 | `user-level/commands/*.md` | name / description のフィールド整合(`tools/doctor.sh` が検査)。ADR 0021 以降の走査記録が対象にしていた行を本表に追加(ADR 0026) |
| プラグイン管理(`enabledPlugins` / `extraKnownMarketplaces`) | `user-level/settings.json.template`, `tools/setup-plugins.sh` | **上流の存続確認だけで終わらせない**。①採用プラグインが marketplace に存続しているか ②**宣言と実体が一致しているか**(`tools/doctor.sh` の「declared plugins vs installed」/ `tools/setup-plugins.sh --dry-run`)③更新時は持ち込み能力(hooks / subagent / skill)の増減を棚卸し。`enabledPlugins` は宣言にすぎず導入は別操作(ADR 0023。この行が①だけだったため 3 か月の乖離を 2 世代の ADR が見逃した) |
| attribution / commit・PR 添付情報の構文 | `user-level/settings.json.template` の `attribution` | セッション URL 抑止方式の変更確認(安定スキーマは `commit` / `pr` のみ、`additionalProperties: false`) |
| `~/.claude/` 配下のディレクトリ構造 | `tools/sync.sh` の symlink 配置 | リンク先パスの妥当性、`tools/setup.sh` の更新 |
| env 変数(`CLAUDE_CODE_*`) | settings.json `env` セクション | 廃止・改名された変数の特定 |
| デフォルトモデル / effort | settings.json `model`(`claude-fable-5-1[1m]`)/ `fallbackModel`(`["claude-opus-5[1m]"]`)/ `effortLevel`(`xhigh`) | `practices/model-selection.md` の指針と整合、モデル世代交代時は subagent の `model` tier も再評価(`update-check` 手順 8) |

## 移行プレイブック(VERSION を上げるとき)

1. Claude Code の changelog / 公式ドキュメントを確認
2. 上記「影響範囲マップ」の各行を順に点検
3. `user-level/settings.json.template` を更新(コミットすると git hook が配置済み `~/.claude/settings.json` へ自動反映する。`tools/sync-settings.sh` / ADR 0017)
4. 影響を受ける skill / subagent / hook を更新
5. `meta/CHANGELOG.md` に変更点を記録(Why を含めて)
6. 必要なら ADR を起票(`practices/adr-workflow.md` 参照)
7. `VERSION` ファイルを書き換え
8. `tools/doctor.sh` で整合性確認
9. 機械検証(禁止語チェック / Betterleaks / JSON 妥当性)を通す
10. 1 セッション動作確認した上でコミット

破壊的変更(skill / subagent / hook の互換性が壊れる場合)は MAJOR バージョンアップ相当として扱い、ADR を必ず起票する。

## クロスレイヤー参照のパス規約

`user-level/skills/<name>/SKILL.md` や `subagents/<name>.md` から他層(`principles/` / `practices/` / `meta/`)を参照する場合、**絶対パス `~/ws/claude-system/<path>` 形式を使用する**。

### 判断の理由

- skills は `~/ws/claude-system/adapters/claude-code/user-level/skills/<name>/SKILL.md` という 4 階層深い位置にあり、相対パス(`../../../../meta/...`)はリンク数が読みにくい
- `~/.claude/skills/` → `~/ws/claude-system/adapters/claude-code/user-level/skills/` に symlink されている。symlink を辿るかどうかで相対パスの解決先が変わるため(physical 解決と lexical 解決の差)、絶対パスのほうが曖昧さが少ない
- `${CLAUDE_SYSTEM_ROOT}` のような環境変数経由は markdown レンダラ・ツールが展開しないため不採用
- claude-system は本システムの設計上 `~/ws/claude-system/` に固定配置される(symlink 設計と `tools/setup.sh` の前提)。別パスへの配置を許容しないことを規約として明示する

### 適用範囲

| 参照元 | 参照先 | 推奨パス形式 |
|--------|--------|--------------|
| `principles/<file>.md` | 同層 / `practices/` | 相対(`./<file>` / `../practices/<file>`) |
| `practices/<file>.md` | `principles/` | 相対(`../principles/<file>`) |
| `adapters/claude-code/user-level/skills/<name>/SKILL.md` | `principles/` / `practices/` / `meta/` | **絶対**(`~/ws/claude-system/<layer>/<file>`) |
| `adapters/claude-code/subagents/<name>.md` | 同上 | **絶対**(`~/ws/claude-system/<layer>/<file>`) |
| `adapters/claude-code/user-level/CLAUDE.md` | 他層 | 既存通り相対(直近 4 階層程度の深さに収まる) |
| `adapters/claude-code/README.md`(本ファイル)/ `_index.md` 系 | 他層 | 相対 |

skill 内・subagent 内の同一 skill/subagent ディレクトリ内の参照(`./references/foo.md` 等)は相対のまま。

判断のレベルは「層配置の運用規約」であり、principles 層の改訂や機械的ガードレール変更には該当しないため ADR は起票しない(`practices/adr-workflow.md` の判断基準を参照)。

## 関連

- [`principles/`](../../principles/) — 本層が翻訳元とする不変原則
- [`practices/`](../../practices/) — 本層が翻訳元とする抽象パターン
- [`meta/forbidden-words.txt`](../../meta/forbidden-words.txt) — principles / practices に混入してはならない語
- [`meta/migration-inventory.md`](../../meta/migration-inventory.md) — 旧 claude-settings からの取り込み判断
- [`meta/CHANGELOG.md`](../../meta/CHANGELOG.md) — Phase 7b で取り込んだ hooks 実装の経緯
- [`meta/decisions/0003-memory-architecture.md`](../../meta/decisions/0003-memory-architecture.md) — `enabledPlugins.episodic-memory` の根拠
