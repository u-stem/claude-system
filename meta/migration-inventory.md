# claude-settings 棚卸しインベントリ

- **棚卸し日**: 2026-04-26
- **旧リポジトリ**: `~/ws/claude-settings/`(GitHub 既存リポジトリに保全済み)
- **作成元**: Phase 0.5
- **対象範囲**: 旧 claude-settings の git tracked ファイル + 主要構造物。`projects/`, `telemetry/`, `history.jsonl`, `backups/`, `file-history/`, `statsig/`, `plugins/cache/`, `ide/`, `paste-cache/`, `session-env/`, `shell-snapshots/`, `todos/`, `tasks/`, `debug/`, `cache/`, `downloads/`, `mcp-needs-auth-cache.json`, `stats-cache.json`, `double-shot-latte/` など `.gitignore` 対象の Claude Code ランタイム生成物は対象外
- **総ファイル数**: 57(+ 空ディレクトリ `teams/` 1 件)

## 分類凡例

| 記号 | 意味 |
|------|------|
| **A** | 取り込み: 新システムにそのまま、または微修正で取り込む |
| **B** | 抽象化して取り込み: 本質を抽出し principles/practices/adapter に昇華 |
| **C** | 参考のみ: 直接取り込まないが、新システム作成時の参考にする |
| **D** | 廃棄: 古い・誤っている・不要 |

## ファイル別分類

### ルートドキュメント(7 件)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `CLAUDE.md` | 111 | **B** | `principles/`, `practices/`, `adapters/claude-code/user-level/CLAUDE.md` | 「AI協働開発ガイド」。原則(テストなしで実装しない/Why コメント/コード設計/禁止事項) → principles・practices へ昇華。Opus 4.7 挙動・コンテキスト管理・プロジェクトフック運用方針 → adapters/claude-code 側へ。言語別スタイル(TS/Python/Rust/Go) → practices/coding-styles 系。メモリ方針 → adapter |
| `settings.json` | 312 | **A** | `adapters/claude-code/user-level/settings.json` (テンプレート化、`.gitignore` 対象) | env/permissions/hooks/enabledPlugins/mcpServers の中核設定。Phase 3 で取り込み、ハードコードされた絶対パス(`/Users/<user>/...` 形式)を `${HOME}` または環境変数化。chezmoi/sed テンプレート化推奨 |
| `settings.local.json` | 7 | **C** | (参考のみ) | `Bash(gitleaks detect *)` 1 行のみ。新システム側では Phase 7b で gitleaks 設定が独立に入るため、ここの内容は不要。「ローカル override 機構の使い方」の例として記憶のみ |
| `README.md` | 407 | **B** | `adapters/claude-code/README.md`(Phase 3 で詳細化) | 構成説明は新システムの新構造に合わせて再構築する。Hook 一覧表、許可コマンド表、パフォーマンス最適化表は再利用価値が高い |
| `REFERENCES.md` | 85 | **A** | `meta/references.md` または `practices/references.md` | t-wada / ハーネスエンジニアリング / AI 駆動開発 / 設計思想 / Claude Code リンク集。短く独立しており、ほぼそのまま転記可 |
| `CHANGELOG.md` | 186 | **C** | (参考のみ) | 旧 claude-settings の歴代変更履歴。新システムは独自の `meta/CHANGELOG.md` を Phase 0 で開始済み。**旧 CHANGELOG への参照は新 `meta/CHANGELOG.md` には一切残さない**(ADR 0002 方針: Public→Private リンクを作らない)。v2.1.x 系 Claude Code 機能の採否経緯は Phase 7b で参照する価値があるが、その場合も「事実だけを書き起こす」形で取り込み、リンクは張らない |
| `.gitignore` | 40 | **B** | `adapters/claude-code/user-level/.gitignore`(雛形) | Claude Code 自動生成ディレクトリ列挙(`projects/`, `telemetry/` 等)が貴重。Phase 3 の user-level セットアップで再利用 |

### ルートスクリプト(5 件)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `clean.sh` | 106 | **A** | `tools/cleanup-claude-code-runtime.sh` | Claude Code 自動生成キャッシュ(debug/, file-history/, paste-cache/ 等)を保持期間で掃除する優秀な実装。冪等、--dry-run 対応。Phase 7a で `tools/` に移植 |
| `setup.sh` | 42 | **B** | `tools/setup.sh` (Phase 7a) | 旧版は単に `~/.claude/` への symlink 作成のみ。新システムでは chezmoi 連携や Phase 10 の symlink 切替を含めて再設計 |
| `setup-mcp.sh` | 67 | **B** | `tools/setup-mcp.sh` (Phase 7a) | MCP 個別追加スクリプト。新システムでは MCP 設定を adapter 層で宣言的に管理し、setup から呼び出す方式に再設計 |
| `setup-plugins.sh` | 82 | **B** | `tools/setup-plugins.sh` (Phase 7a) | プラグインインストール手順。superpowers / LSP / ワークフロー 9 件をリストし `claude plugin install` 呼び出し。プラグイン一覧は adapter 層に宣言、setup は読むだけにする方が DRY |
| `validate.sh` | 167 | **B** | `tests/` 配下と `tools/doctor.sh` に分割 | JSON 構文/シェルスクリプト構文/frontmatter/必須ファイル検証。Phase 9 のテストと Phase 7a の doctor に分割再構成。pre-commit hook 連携部分は Phase 7b 参考 |

### agents/(6 件、Subagents)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `agents/code-reviewer.md` | 67 | **A** | `adapters/claude-code/subagents/code-reviewer.md` | Sonnet/effort:high。セキュリティ・AI ハルシネーション・誤魔化し検出・コード品質・デッドコード・パフォーマンス・既存パターン整合の 7 観点。優れた粒度 |
| `agents/doc-writer.md` | 31 | **A** | 同上 | Haiku/low。コード変更に伴う doc 更新提案。Why ベース、過剰ドキュメント忌避の原則 |
| `agents/explorer.md` | 21 | **A** | 同上 | Haiku/low。コードベース探索専門。「必要最小限のファイルのみ読む」「結果を簡潔にまとめる」 |
| `agents/refactor-planner.md` | 47 | **A** | 同上 | Sonnet/high。実装はせず計画のみ。code smell 5 種・段階的計画・テスト戦略 |
| `agents/security-reviewer.md` | 51 | **A** | 同上 | Sonnet/high。インジェクション/認証認可/秘密情報/データ処理。重大度順 (Critical→Low) で報告 |
| `agents/test-runner.md` | 31 | **A** | 同上 | Haiku/low。bun test / uv run pytest / cargo test / go test ./... 切替 |

→ Phase 5 でほぼそのまま `subagents/` に取り込み。命名規則とフロントマター(model/effort)は Opus 4.7 期に整備済み

### commands/(4 件、Slash Commands)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `commands/check.md` | 39 | **A** | `adapters/claude-code/user-level/commands/check.md` | lint + 型チェック + テスト一括。言語別 (TS/Python/Rust/Go) のコマンド分岐 |
| `commands/review.md` | 11 | **A** | 同上 | 軽量レビュー。`$ARGUMENTS` でファイル指定。詳細は code-reviewer subagent に誘導 |
| `commands/test.md` | 19 | **A** | 同上 | テスト実行 + 失敗解析 + 修正案(実行はしない)。言語別コマンド |
| `commands/update-check.md` | 60 | **A** | 同上 | Claude Code 本体・プラグイン・MCP・パフォーマンスの最新情報調査。出力フォーマット定義 |

→ Phase 4 で取り込み。slash command として運用継続

### skills/(8 件、Skills)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `skills/tdd/SKILL.md` | 61 | **A** | `adapters/claude-code/user-level/skills/tdd/SKILL.md` | t-wada 思想 TDD。Red/Green/Refactor、One-assertion、Arrange-Act-Assert |
| `skills/debugging/SKILL.md` | 43 | **A** | 同上 | 体系的デバッグ 5 ステップ(症状/仮説/調査/検証/修正)。「推測で修正しない」 |
| `skills/pr-review/SKILL.md` | 88 | **A** | 同上 | PR レビュー(機能/AI ハルシネーション/誤魔化し/品質/デッドコード/セキュリティ/テスト)。テンプレ込み |
| `skills/changelog/SKILL.md` | 60 | **A** | 同上 | git log → カテゴリ分類 (Added/Fixed/Changed 等) → Markdown 生成 |
| `skills/refactor/SKILL.md` | 61 | **A** | 同上 | テストが緑前提のリファクタリングワークフロー。code smell 5 種・パターン 6 種 |
| `skills/investigate/SKILL.md` | 39 | **A** | 同上 | 調査をサブエージェント委譲しメインコンテキスト保護。「10 ファイル以上は必ずサブエージェント」 |
| `skills/session-handoff/SKILL.md` | 54 | **A** | 同上 | `.claude/handoff.json` JSON ベースの引き継ぎ。Anthropic Initializer→Coding Agent パターン |
| `skills/quality-gate/SKILL.md` | 64 | **A** | 同上 | 完了前 5 項目チェック(テスト/型 lint/セキュリティ/ドキュメント/コード品質) |

→ Phase 4 で取り込み。t-wada 由来の TDD 等は principles 層への昇華も検討余地あり

### hooks/(8 件、ハーネス用シェル + JSON)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `hooks/check-failure-patterns.sh` | 36 | **A** | `adapters/claude-code/user-level/hooks/check-failure-patterns.sh` | SessionStart hook。`.claude/failure-log.jsonl` から繰り返しパターン(check/check-types/test カテゴリ別 ≥3 回)を検出して通知。harness feedback loop の中核 |
| `hooks/check-package-age.sh` | 117 | **A** | 同上 | PreToolUse hook (パッケージ追加時)。npm/PyPI/crates レジストリで初回公開日を取得し、`PACKAGE_MIN_AGE_DAYS`(デフォルト 7)以内なら deny。typosquatting 防御。優れた実装、Phase 7b ガードレールの重要資産 |
| `hooks/filter-test-output.sh` | 14 | **A** | 同上 | PreToolUse hook (テストコマンド時)。`tail -150` でラップしてコンテキスト圧縮。Opus 4.7 期に 50→150 に拡張済み |
| `hooks/log-bash-failure.sh` | 29 | **A** | 同上 | PostToolUse Bash hook。終了コード ≠ 0 を検出し、command 内容から category(test/check-types/check)を判定して `log-failure.sh` に渡す |
| `hooks/log-failure.sh` | 25 | **A** | 同上 | `.claude/failure-log.jsonl` への JSONL 追記。category と最初の error 行を記録 |
| `hooks/require-review-before-commit.sh` | 39 | **A** | 同上 | PreToolUse hook (git commit)。`REQUIRE_REVIEW_BEFORE_COMMIT=1` 時のみ動作。`.claude/.review-done` マーカーで pass。Opus 4.7 期に opt-in 化 |
| `hooks/format-on-save.json` | 16 | **C** | (参考) | PostToolUse(Edit\|Write) で prettier/black/rustfmt を呼ぶ参考 JSON。`_comment` で「マージしてください」と指示。Phase 7b で settings.json テンプレートに統合検討 |
| `hooks/protect-secrets.json` | 16 | **C** | (参考) | `*.env` `*.env.*` `*secrets*` `*credential*` `*.pem` `*.key` への書き込みを `exit 2` でブロックする PreToolUse(Edit\|Write)。新 settings.json では既に `permissionDecision: "deny"` 方式に進化し、deny パターンも `permissions.deny` に取り込まれている(`./.env`, `./.env.*`, `./secrets/**`, `./**/credentials*`, `./**/*secret*`, `./**/*.pem`, `./**/*.key`, `./.env` Write/Edit 含む)。**Phase 7b の `permissions.deny` で網羅可能、本ファイルは廃止して良い。本人固有の機密パスは含まれない**(汎用パターンのみ)。確認のため一時的に `/tmp/protect-snippet-readcheck.json` にコピーして読み取り、その後削除済み。元ファイルの deny ルールは触れていない |

### hooks/examples/(7 件、プロジェクト配置用テンプレート)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `hooks/examples/post-edit-typescript.sh` | 31 | **A** | `adapters/claude-code/project-templates/post-edit/typescript.sh` | biome check / tsc --noEmit。silent on success / exit 2 on failure |
| `hooks/examples/post-edit-monorepo-bun.sh` | 47 | **A** | 同 (`monorepo-bun.sh`) | Turborepo+bun workspace 用。filter ベース、log-failure.sh と連携。**取り込み時に旧 `@myapp/web` 等の具体名は明示プレースホルダ(v3 マスタープラン規約の `{{PROJECT_NAME}}` 形式)に置換する**。例: `--filter {{PROJECT_NAME}}/web` |
| `hooks/examples/post-edit-python.sh` | 30 | **A** | 同 (`python.sh`) | ruff check --fix + mypy |
| `hooks/examples/post-edit-rust.sh` | 26 | **A** | 同 (`rust.sh`) | cargo fmt + cargo clippy --all-targets --all-features -D warnings |
| `hooks/examples/post-edit-go.sh` | 31 | **A** | 同 (`go.sh`) | gofmt + goimports + go vet |
| `hooks/examples/post-stop-test.sh` | 21 | **A** | `adapters/claude-code/project-templates/post-stop/auto-detect.sh` | bun test / npm test / pytest / cargo test / go test 自動検出 |
| `hooks/examples/post-stop-monorepo-bun.sh` | 16 | **A** | 同 (`monorepo-bun.sh`) | bun run test の monorepo 版、log-failure.sh 連携 |

→ Phase 6 で project-templates として取り込み。monorepo 用はプロジェクト名置換が必要なため fragment として配布する選択肢もある

### mcp/(2 件)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `mcp/README.md` | 53 | **B** | `adapters/claude-code/mcp/README.md` | MCP サーバー(github/sequential-thinking/playwright/memory)の手動セットアップ手順 + token 取得手順。新システムでは memory を削除した経緯(long-term-memory-design)を反映して再構成 |
| `mcp/servers.template.json` | 38 | **A** | 同 (`servers.template.json`) | github / sequential-thinking@2025.12.18 / @playwright/mcp@0.0.70 / @upstash/context7-mcp@2.1.6 の固定バージョンテンプレート。Phase 3 でそのまま転記、バージョンは update-check で見直す |

### rules/(3 件)

| ファイル | 行数 | 分類 | 取り込み先候補 | 内容要約 / 注記 |
|---------|------|------|----------------|----------------|
| `rules/code-style.md` | 42 | **B** | `principles/coding-style.md` または `practices/coding-style.md` | 命名/インポート/ファイル構成/エラーメッセージ/禁止パターン。普遍的な原則が多く principles に昇格可能。`paths` frontmatter は Claude Code 固有なので adapter 側で再付与 |
| `rules/security.md` | 44 | **B** | `principles/security-baseline.md` + `practices/supply-chain.md` | 入力バリデーション/脆弱性パターン/依存関係/シークレット。前半は principles、依存関係(supply chain 部分)は practices に分割。Phase 7b の hooks 設計と整合 |
| `rules/testing.md` | 40 | **B** | `principles/testing-baseline.md` または `practices/testing.md` | テスト命名/データ/境界(unit/integration/e2e)/不要なもの/禁止パターン |

### docs/superpowers/specs/(3 件、設計記録)

ADR 0002 方針に従い新 claude-system には **転記しない**(旧 Private リポジトリ側に保管継続)。ただし**ここから昇華された要素**を新システムのどこに取り込むかの対応関係を本表で残す(将来「あの設計判断はどこから来たのか」を辿れるように)。

| ファイル | 行数 | 分類 | 昇華先 | 内容要約 / 注記 |
|---------|------|------|--------|----------------|
| `docs/superpowers/specs/2026-04-01-harness-improvement-design.md` | 158 | **C** | Phase 7b の hooks 設計全般、`practices/` のフィードバックループ章 | 7 軸ハーネス改善の設計書。post-edit/post-stop ディスパッチャ、failure-log 自己参照ループの根拠資料 |
| `docs/superpowers/specs/2026-04-01-supply-chain-defense-design.md` | 152 | **C** | Phase 7b の `check-package-age.sh` 取り込み、`practices/supply-chain.md`、`principles/security-baseline.md` の依存関係セクション | 4 層防御(バージョン固定/PreToolUse/lockfile 検証/ルール)の設計。typosquatting/侵害バージョン対策の根拠 |
| `docs/superpowers/specs/2026-04-01-long-term-memory-design.md` | 102 | **C** | Phase 3 メモリ章、Phase 4 で作成する `meta/decisions/00NN-memory-architecture.md`(連番採番) | 2 層メモリ(auto memory + episodic-memory)+ Memory MCP 廃止。Memory architecture ADR の根拠資料 |

### docs/superpowers/plans/(4 件、実装計画)

ADR 0002 方針に従い新 claude-system には **転記しない**。タスクの内容で新システムにとって重要なもののみ抽出し、対応する Phase の TODO に転記する。

| ファイル | 行数 | 分類 | 抽出対象 | 内容要約 / 注記 |
|---------|------|------|----------|----------------|
| `docs/superpowers/plans/2026-04-01-harness-improvement.md` | 920 | **C** | `meta/TODO-for-phase-7b.md` のディスパッチャパターン項 | ハーネス改善 16 タスクの詳細計画 |
| `docs/superpowers/plans/2026-04-01-supply-chain-defense.md` | 296 | **C** | `meta/TODO-for-phase-7b.md` の supply chain 項 | 6 タスクの詳細計画 |
| `docs/superpowers/plans/2026-04-01-long-term-memory.md` | 182 | **C** | `meta/TODO-for-phase-4.md` の memory architecture ADR 項 | 4 タスクの詳細計画 |
| `docs/superpowers/plans/2026-04-01-remaining-improvements.md` | 233 | **C** | Phase 7a / Phase 7b の TODO に必要なものを抽出 | ハーネス改善後の残タスク(README 更新/Playwright MCP 追加/CwdChanged hook/effort frontmatter 等) |

### その他

| エントリ | 種別 | 分類 | 注記 |
|---------|------|------|------|
| `teams/` | 空ディレクトリ | **D** | Agent Teams 用に作成されたが未使用。新システムでは作成しない(必要なら Phase で改めて) |

## 集計

| 分類 | 件数 | 主な内容 |
|------|------|---------|
| **A: 取り込み** | 35 | settings.json、agents 6、commands 4、skills 8、hooks 6 (sh)、hooks/examples 7、mcp/servers.template.json、REFERENCES.md、clean.sh |
| **B: 抽象化** | 11 | CLAUDE.md、README.md、.gitignore、setup 系スクリプト 4、validate.sh、mcp/README.md、rules 3 |
| **C: 参考のみ** | 11 | settings.local.json、CHANGELOG.md、hooks 参考 JSON 2、docs/superpowers/specs 3 + plans 4 |
| **D: 廃棄** | 1 | teams/ (空) |
| **合計** | 58 | (57 ファイル + 1 空ディレクトリ) |

## Phase 1 以降への提言

### Phase 1 (Principles 層)

旧 `CLAUDE.md` と `rules/` から以下を昇華(特定ツール名抜きで普遍記述へ):

- **テスト駆動原則**: 「テストなしで実装しない」「バグ修正は再現テストから」「リファクタはテスト緑から」(`CLAUDE.md`, `skills/tdd`, `rules/testing.md` 由来)
- **小さな完了の連続**: 「小さく作り、小さくコミット」(`CLAUDE.md`)
- **検証主義**: 「AI の出力は必ず検証する」「Don't trust, verify」(`CLAUDE.md`, `skills/quality-gate`)
- **コード設計の核**: 「Parse, don't validate」「不変性優先」「全ケース網羅」(`CLAUDE.md`)
- **禁止事項**: 「TODO で先送りしない」「『たぶん大丈夫』を残さない」「存在確認なしのパッケージ・架空 API を使わない」(`CLAUDE.md`)
- **セキュリティ基盤原則**: 入力バリデーション/拒否リストより許可リスト/依存関係のバージョン固定(`rules/security.md`)
- **テストの境界原則**: unit/integration/e2e の分離(`rules/testing.md`)
- **個人情報の取り扱い**: ADR 0001 由来(これは `meta/TODO-for-phase-3.md` で別途扱い)

skills の中で principles に昇格できる候補: `tdd`(t-wada 思想は普遍)、`quality-gate`(検証主義の具体化)。

### Phase 2 (Practices 層)

- **言語別コーディングスタイル**: TypeScript/Python/Rust/Go の指針(`CLAUDE.md` 言語別スタイル)
- **コミット規約**: Conventional Commits の type 表(`CLAUDE.md` Git セクション)
- **モデル選択ガイド**: Opus / Sonnet / Haiku の使い分け(`CLAUDE.md` Opus 4.7 前提の運用方針)
- **コンテキスト管理**: 1M context 前提の /compact 運用、autocompact 閾値、/clear 原則(`CLAUDE.md`)
- **メモリ運用**: auto memory と episodic-memory の使い分け(`CLAUDE.md` メモリセクション + `long-term-memory-design`)
- **サプライチェーン防御**: バージョン固定/typosquatting チェック/`PACKAGE_MIN_AGE_DAYS`/lockfile 監視(`rules/security.md` + `check-package-age.sh` + `supply-chain-defense-design`)
- **失敗フィードバックループ**: `.claude/failure-log.jsonl` → `check-failure-patterns.sh` → ルール/skill 化(`README.md` 自動フィードバックループ)

### Phase 3 (Adapter 層: Claude Code user-level)

- 新 `user-level/CLAUDE.md`: 旧 CLAUDE.md の Claude Code 固有部分(Opus 4.7 挙動/コンテキスト管理/プロジェクトフック運用方針/メモリ)を移植
- 新 `user-level/settings.json` テンプレート: 旧 settings.json をベースに、ハードコード絶対パス(`/Users/<user>/...` 形式)を環境変数化
- 新 `user-level/.gitignore`: 旧 .gitignore の Claude Code 自動生成ディレクトリ列挙を再利用
- ADR 0001 由来の「個人情報の取り扱い」セクション追加(`meta/TODO-for-phase-3.md`)
- MCP テンプレート: `mcp/servers.template.json` をそのまま、`mcp/README.md` は再構成(memory 削除済みを反映)

### Phase 4 (Skills)

- 旧 skills 8 件をすべて `user-level/skills/` に移植(`tdd`, `debugging`, `pr-review`, `changelog`, `refactor`, `investigate`, `session-handoff`, `quality-gate`)
- 旧 commands 4 件を `user-level/commands/` に移植(`check`, `review`, `test`, `update-check`)
- 命名規則は現状維持(短く動詞ベース、frontmatter で description 明示)

### Phase 5 (Subagents)

- 旧 agents 6 件をすべて `subagents/` に移植(`code-reviewer`, `doc-writer`, `explorer`, `refactor-planner`, `security-reviewer`, `test-runner`)
- model/effort 設定は維持(Opus 4.7 期に整備済み)

### Phase 6 (Project Templates / Fragments)

- 旧 `hooks/examples/` 7 件を `project-templates/post-edit/` と `project-templates/post-stop/` に分割配置
- monorepo 用は project-fragments としてパッケージ名カスタマイズ手順を併記

### Phase 7a (Tools)

- `clean.sh` → `tools/cleanup-claude-code-runtime.sh`(冪等性とインタフェースは現状維持、ハードコードパスを引数化)
- `setup.sh` → `tools/setup.sh`(symlink 切替部分は Phase 10 と統合)
- `setup-mcp.sh` / `setup-plugins.sh` → `tools/` 配下に移植、ただし MCP/プラグイン一覧は adapter 層に宣言してスクリプト側はそれを読むだけ
- `validate.sh` の doctor 部分 → `tools/doctor.sh`、テスト部分は Phase 9 へ
- `remaining-improvements.md` の中優先タスク(CwdChanged hook 追加検討)を考慮

### Phase 7b (Guardrails)

- 旧 `hooks/` 6 件 (sh) は `adapters/claude-code/user-level/hooks/` に移植
- settings.json 内の hook 構成も移植(SessionStart/PreToolUse/PostToolUse/Stop/StopFailure/SubagentStop/PreCompact/SessionEnd)
- gitleaks 統合は新規追加(旧 settings.local.json の許可ルールはそのまま不要、Phase 0 で追加した `.gitleaks.toml` を強化)
- ADR 0001 を機械的に強制する custom rule 検討(本名・呼称検出)
- `format-on-save.json` / `protect-secrets.json` 系の参考設定は README に「optional」として案内
- supply-chain-defense / harness-improvement の specs を実装根拠として参照

### Phase 9 (Verification / Tests)

- `validate.sh` の検証部分(JSON/シェル構文/frontmatter/必須ファイル)を `tests/` の自動テストに分割
- principles 層の純粋性検証(`grep -E 'Claude Code|Cursor|Codex'` で混入検出)を追加

## 棚卸し時の発見事項

### 過去の自分の指示で「なるほど」と思ったもの

1. **`hooks/check-package-age.sh` の練度**: npm/PyPI/crates 各レジストリから初回公開日を取得し、macOS BSD date と GNU date の両方に fallback する実装。typosquatting/侵害バージョン対策として完成度が高く、Phase 7b 設計の柱になる
2. **失敗フィードバックループの設計**: `log-failure.sh` → `failure-log.jsonl` → `check-failure-patterns.sh`(SessionStart で再発検出 → 通知)。同一ハーネスで「ルール化を促す」自己改善ループが既に組まれている
3. **post-edit / post-stop の責務分離**: グローバル hook は dispatcher に徹し、プロジェクト側 `.claude/hooks/post-edit.sh` を呼ぶだけ。言語非依存性と project autonomy の両立
4. **opt-in なレビュー強制**: `require-review-before-commit.sh` を `REQUIRE_REVIEW_BEFORE_COMMIT=1` のときだけ動かす設計。Opus 4.7 の自律判断を尊重しつつ、必要時にだけガードを上げる
5. **`.gitignore` の Claude Code ランタイム生成物リスト**: ここまで網羅的に列挙されているのは新システムでもそのまま流用したい資産
6. **monorepo テンプレートの実用性**: Turborepo+bun の filter 構文を活用し、編集ファイルから影響パッケージだけ lint/check する設計

### 「これは捨てた方が良い」と判断した根拠

- **`teams/`**: 空ディレクトリ。Agent Teams の `EXPERIMENTAL_AGENT_TEAMS=1` を試した名残と推測されるが、中身が無い以上記録価値なし。新システムでは Agent Teams を使うときに改めて適切な場所(adapter 層)に作る

### 確定済み回答(オーナー指示反映、2026-04-26)

1. **`teams/` の用途** → **D 廃棄で確定**。Claude Code の Teams プラン向けディレクトリで個人プランでは未使用。将来必要になれば改めて作成する
2. **`CHANGELOG.md` の旧履歴の扱い** → **新システムには一切参照を残さない**。理由: (a) 旧 claude-settings は Private リポジトリで Public な新システムからリンクしてもアクセスできない、(b) 新リポジトリの独立性を保つ、(c) Public/Private の境界を曖昧にしない、(d) 旧履歴の存在は本ファイル `meta/migration-from-claude-settings.md` に事実だけ記載されていれば十分。**新 `meta/CHANGELOG.md` は新システムの履歴のみを記録する**(ADR 0002 として恒久化)
3. **`docs/superpowers/specs/plans` を Public claude-system に含めるか** → **含めない**。新システムは完成形を見せるリポジトリにする。過程は旧 Private リポジトリ側で参照可能なので失われない。**ただし、これらから昇華された内容(principles/practices に組み込まれた要素)はインベントリで対応関係を残す**(本ファイルの該当セクション参照)
4. **`settings.local.json` の gitleaks 許可** → **C 参考で確定**。Phase 7b で `.gitleaks.toml` を新規構築する際の参考材料とし、そのまま継承はしない
5. **`Memory MCP` の扱い** → **旧で確定済みの方針(Memory MCP は使わず episodic-memory のみ)を継承**。これは重要な設計判断のため、Phase 4 で `meta/decisions/00NN-memory-architecture.md` を作成する(`meta/TODO-for-phase-4.md` 参照)
6. **`hooks/examples/post-edit-monorepo-bun.sh` のプレースホルダ戦略** → **(a) project-templates としてそのまま配布**。ただし旧 `@myapp/web` のような具体名ではなく、v3 マスタープラン規約の **`{{PROJECT_NAME}}` 形式の明示プレースホルダ**に置換する
7. **`hooks/protect-secrets.json` の中身** → **deny を一時緩和(別名 `/tmp/protect-snippet-readcheck.json` にコピーして Read、その後コピー削除、元 deny 不変)で確認済み**。中身は「`*.env` `*.env.*` `*secrets*` `*credential*` `*.pem` `*.key` への Edit\|Write を `exit 2` でブロックする PreToolUse」。確認結果は本表 hooks セクションに反映済み。**Phase 7b の `permissions.deny` で網羅可能、本ファイル自体は廃止して問題なし。本人固有の機密パスは含まれていない(汎用パターンのみ)**

## 補足: 旧 claude-settings 側の作業ツリー変更

Phase 0 で「放置」と決定済みの未 stage 変更(`M CLAUDE.md`, `M settings.json`)と未 push コミット(`9db569f`)について、本フェーズでは予定どおり読取りのみ。新システムへの取り込み判断は本インベントリ表に従って Phase 3 以降で実施する。
