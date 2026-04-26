# claude-code adapter

`principles` と `practices` を Claude Code(Anthropic CLI)の語彙に翻訳して具体化する適応層。

特定ツール固有の用語(CLAUDE.md / skill / subagent / hook / settings.json / slash command / MCP / `~/.claude/`)が登場するのは**この層以下のみ**(`meta/forbidden-words.txt` で機械検出される)。

## 前提バージョン

[`./VERSION`](./VERSION) を参照(現在: 2.1.119)。

VERSION 更新時のチェックリストは [Claude Code 仕様変更時の影響範囲マップ](#claude-code-仕様変更時の影響範囲マップ) に従う。

## 利用している Claude Code 機能

| 機能 | 利用箇所 | 役割 |
|------|----------|------|
| 階層的 CLAUDE.md(user-level / project-level) | `user-level/CLAUDE.md` | 全プロジェクト共通の出力衛生・作業フロー・禁止事項を定義 |
| `@<file>` 参照 | 各種ドキュメント内 | 段階的開示の入口 |
| skill(段階的開示で読まれる能力単位) | `user-level/skills/`(Phase 4) | TDD・debugging・PR レビュー等の能力単位 |
| subagent(独立コンテキストの補助エージェント) | `subagents/`(Phase 5) | code-reviewer・doc-writer・explorer 等 |
| settings.json(permissions / hooks / env / mcpServers / enabledPlugins) | `user-level/settings.json.template` | permissions.deny で物理ブロック、hooks で機械的防御(Phase 7b) |
| permissions.deny / allow | settings.json 内 | LLM の自制に頼らず物理的に書き込みを拒否 / permission prompt の抑制 |
| hooks(SessionStart / PreToolUse / PostToolUse / Stop / StopFailure / SubagentStop / PreCompact / SessionEnd) | `user-level/hooks/`(Phase 7b) | typosquatting 防御・失敗フィードバックループ・dispatcher パターン |
| slash command | `user-level/commands/`(Phase 4 検討) | 旧 commands(check / review / test / update-check)を継承予定 |
| MCP server 設定(`mcpServers`) | settings.json 内 | chrome-devtools / playwright(API キー不要のもののみ template に含める) |
| プラグイン管理(`enabledPlugins`) | settings.json 内 | superpowers / elements-of-style / episodic-memory |

## ディレクトリ構成

```
adapters/claude-code/
├── README.md              本ファイル
├── VERSION                前提バージョン(プレーンテキスト)
├── user-level/            ~/.claude/ にリンクされる個人共通設定
│   ├── CLAUDE.md          全プロジェクト共通指示(完了報告・出力衛生・禁止事項等)
│   ├── settings.json.template  permissions / hooks / env / mcpServers の雛形
│   ├── skills/            Phase 4 で能力単位を配置
│   │   └── _index.md
│   └── hooks/             Phase 7b で機械的防御を配置
│       └── _README.md
├── subagents/             ~/.claude/agents/ にリンクされる補助エージェント
│   └── _index.md          Phase 5 で本体作成
├── project-templates/     新規プロジェクト用のひな形(Phase 6)
└── project-fragments/     既存プロジェクトに追記される断片(Phase 6)
```

## 設定階層と Phase 10 でのリンク

```
~/.claude/                                                  (ディレクトリ)
├── CLAUDE.md   → adapters/claude-code/user-level/CLAUDE.md  (symlink)
├── skills      → adapters/claude-code/user-level/skills      (symlink)
├── hooks       → adapters/claude-code/user-level/hooks       (symlink)
├── agents      → adapters/claude-code/subagents              (symlink)
└── settings.json                                              (cp 配置、マシン固有値の差し込みのため symlink にしない)
```

切替前(Phase 0〜9)は `~/.claude/` → `~/ws/claude-settings/` の現運用を維持する。
切替手順は Phase 10、ロールバックは `tools/migrate/rollback-from-claude-system.sh`(Phase 7a)。

## Claude Code 仕様変更時の影響範囲マップ

Claude Code がアップデートされた場合、以下を順に確認する:

| 仕様変更領域 | 影響を受けるファイル | 確認手順 |
|--------------|----------------------|----------|
| `permissions.deny` / `allow` の構文 | `user-level/settings.json.template` | 公式ドキュメントの permissions セクション差分確認 → deny ルールの構文整合 → `jq` で JSON 妥当性 |
| `hooks.<event>` の matcher / フィールド構文 | `user-level/settings.json.template`, `user-level/hooks/*.sh`(Phase 7b) | 各 hook event のスキーマ差分確認 → 対応 hook の入出力契約の更新 |
| 利用可能な hook event 種別 | 同上 | 新 event 追加時は guardrail 設計を再評価 |
| skill の frontmatter 仕様 | `user-level/skills/*/SKILL.md`(Phase 4) | name / description / recommended_model 等のフィールドが廃止・追加されていないか |
| subagent の frontmatter 仕様 | `subagents/*.md`(Phase 5) | name / description / tools 等のフィールド整合 |
| MCP server 設定スキーマ | `user-level/settings.json.template` の `mcpServers` | パッケージバージョン更新と引数構文差分 |
| プラグイン管理(`enabledPlugins`) | 同上 | 採用プラグインの存続確認 |
| `~/.claude/` 配下のディレクトリ構造 | Phase 10 の symlink 配置 | リンク先パスの妥当性、`tools/setup.sh`(Phase 7a)の更新 |
| env 変数(`CLAUDE_CODE_*`) | settings.json `env` セクション | 廃止・改名された変数の特定 |
| デフォルトモデル / effort | settings.json `model` / `effortLevel` | `practices/model-selection.md` の指針と整合 |

## 移行プレイブック(VERSION を上げるとき)

1. Claude Code の changelog / 公式ドキュメントを確認
2. 上記「影響範囲マップ」の各行を順に点検
3. `user-level/settings.json.template` を更新
4. 影響を受ける skill / subagent / hook を更新(各 Phase で実装済みの分)
5. `meta/CHANGELOG.md` に変更点を記録(Why を含めて)
6. 必要なら ADR を起票(`practices/adr-workflow.md` 参照)
7. `VERSION` ファイルを書き換え
8. `tools/doctor.sh`(Phase 7a)で整合性確認
9. 機械検証(禁止語チェック / gitleaks / JSON 妥当性)を通す
10. 1 セッション動作確認した上でコミット

破壊的変更(skill / subagent / hook の互換性が壊れる場合)は MAJOR バージョンアップ相当として扱い、ADR を必ず起票する。

## クロスレイヤー参照のパス規約

`user-level/skills/<name>/SKILL.md` や `subagents/<name>.md` から他層(`principles/` / `practices/` / `meta/`)を参照する場合、**絶対パス `~/ws/claude-system/<path>` 形式を使用する**。

### 判断の理由

- skills は `~/ws/claude-system/adapters/claude-code/user-level/skills/<name>/SKILL.md` という 4 階層深い位置にあり、相対パス(`../../../../meta/...`)はリンク数が読みにくい
- Phase 10 で `~/.claude/skills/` → `~/ws/claude-system/adapters/claude-code/user-level/skills/` に symlink される。symlink を辿るかどうかで相対パスの解決先が変わるため(physical 解決と lexical 解決の差)、絶対パスのほうが曖昧さが少ない
- `${CLAUDE_SYSTEM_ROOT}` のような環境変数経由は markdown レンダラ・ツールが展開しないため不採用
- claude-system は本システムの設計上 `~/ws/claude-system/` に固定配置される(Phase 10 の symlink 設計、`tools/setup.sh` の前提)。別パスへの配置を許容しないことを規約として明示する

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
- [`meta/TODO-for-phase-7b.md`](../../meta/TODO-for-phase-7b.md) — hooks 実装の取り込み対象
- [`meta/decisions/0003-memory-architecture.md`](../../meta/decisions/0003-memory-architecture.md) — `enabledPlugins.episodic-memory` の根拠
