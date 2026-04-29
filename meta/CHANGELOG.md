# CHANGELOG

このリポジトリの変更履歴。Phase 単位でセクション化する。

## [v0.1.0-rc1] — 2026-04-29

Phase 9 完了、Phase 10 切り替え前のリリース候補。
全 Phase 0-9 の成果物を統合し、ドキュメント整備・統合テストシミュレーション・migrate スクリプト配置(未実行)を完了。

### Phase 9: 検証 + ドキュメント整備(2026-04-29)

- 全体構造確認: `tools/doctor.sh` clean(38 / 38 OK、warn/error 0)
- ガードレール動作確認:
  - `tests/lint-principles-language.sh`: 禁止語(`settings.json`)を意図的に混入させて検出されることを確認
  - `gitleaks`: GitHub Token の検出を確認
  - `shellcheck -S warning`: 全 `.sh` ファイル pass
  - GitHub Actions 直近 push: doctor / secrets-scan / shellcheck の 3 ジョブとも success
- 統合テストシミュレーション: `meta/integration-trace.md` にシナリオ A〜D(ホーム / sugara / kairous / Phase 10 切り替え後)を文書化
- ドキュメント整備:
  - `README.md` 完成版(設計思想 / クイックスタート / 取り込み手順 / トラブルシューティング)
  - `meta/operating-manual.md` 新規(月次レトロ / 四半期 principles 見直し / Claude Code バージョンアップ手順 / 廃止判断 / hooks メンテナンス)
  - `meta/daily-routine.md` 新規(朝・退勤前・週次・バックアップ整理)
  - `meta/multi-device-setup.md` 新規(別 macOS マシン展開、chezmoi 連携)
  - `meta/glossary.md` 完成版(層 / 抽象構成要素 / Claude Code 関連 / 運用 / ガードレール / メモリ / 「Claude 運用習熟度」)
- ADR 起票:
  - `0004-system-architecture-summary.md` — 4 層構造 / forbidden-words / 機械的ガードレール 5 層 / Public 運用の総括
  - `0005-bootstrap-completion-and-deferral.md` — v0.1.0-rc1 リリース候補化と Phase 10 への遅延判断
- `meta/retrospectives/_template.md` 作成
- `meta/TODO-for-phase-9.md` 消化:
  - `branch-protection-solo-flow` の kairous 該当性確認(該当あり、kairous の `rules/workflow.md` に同等記述存在)
  - 観察 B(共通化判定軸の改訂)を `practices/refactoring-trigger.md` に反映
  - その他 v0.2 持ち越しは `meta/TODO-for-v0.2.md` に移動
- migrate スクリプト 2 本配置(`tools/migrate/from-claude-settings.sh` / `rollback-from-claude-system.sh`)、Phase 10 で実行する前提のまま未実行
- `git tag v0.1.0-rc1`

### Phase 8: 既存プロジェクト取り込み(2026-04-26 〜 2026-04-29)

- `kairous` 取り込み(2026-04-28、案 Y で `@web-apps-common.md` 追加のみ)
  - `~/ws/kairous/CLAUDE.md` の冒頭に共通 fragment への `@` 参照を追加
  - `.claude/rules/*.md` の重複削除(案 X)は v0.2 検討
- `sugara` 取り込み(2026-04-29、案 Y で `@web-apps-common.md` 追加のみ)
  - 4 件の高優先 skill 化候補を発見(`drizzle-vercel-buildcommand-migration` / `tauri-v2-3files-version-sync` / `supabase-realtime-channel-cleanup` / `next-intl-cookie-i18n-sync`)
  - 「Claude 運用習熟度」概念を発見(2 プロジェクト間の運用の時系列差を、プロジェクト固有度ではなく成熟度差として解釈する観察 A/B/C)
- `drawzzz` 取り込みは Phase 8 でスキップ(中断中、再開時に取り込み + `games-common.md` 検証)
- バックアップ: `~/.claude-system-backups/<project>-CLAUDE.md.<TIMESTAMP>` 配下

### Phase 7b: Guardrails 層(2026-04-27)

- hooks ディレクトリ実装: `pre-bash-guard.sh` / `pre-edit-protect.sh` / `check-package-age.sh`(supply chain 防御)/ `log-bash-failure.sh` + `log-failure.sh`(failure feedback ループ)/ `post-edit-dispatcher.sh` + `post-edit-validate.sh` / `post-stop-dispatcher.sh` + `stop-session-doctor.sh` / `subagent-stop-record.sh` + `subagent-stop-audit.sh` / `check-failure-patterns.sh`
- `settings.json.template` の hooks セクション結線
- `.github/workflows/` 追加: `doctor.yml` / `secrets-scan.yml` / `shellcheck.yml`
- `.gitleaks.toml` allowlist / placeholder 整備
- `tools/disable-guardrails.sh` / `tools/enable-guardrails.sh` 追加(opt-out で hooks 一時無効化)
- `.gitignore` に Claude Code project-local `.claude/` 配下を追加

### Phase 7a: ツール群(2026-04-27)

- `tools/_lib.sh`(共通ヘルパー / 色付き出力 / ロック / バックアップパス / 対話ヘルパー)
- `tools/sync.sh`(`--dry-run` / `--force` + `CLAUDE_SYSTEM_ALLOW_SYNC=1` セーフガード)
- `tools/doctor.sh`(整合性チェック、`tests/*.sh` 委譲呼び出し)
- `tools/setup.sh`(新環境セットアップ、chezmoi 検出のみ)
- `tools/new-project.sh`(対話 / 引数 / scratch モード)
- `tools/adopt-project.sh` / `unadopt-project.sh` / `restore-project.sh`
- `tools/new-skill.sh` / `tools/new-adr.sh`(プロジェクト内 ADR 起票も含む)
- `tools/cleanup-backups.sh` / `cleanup-claude-code-runtime.sh`(後者は手動実行のみ)
- `tools/check-claude-version.sh` / `tools/setup-mcp.sh`
- `tests/lint-skills.sh` / `lint-principles-language.sh` / `check-circular-refs.sh` / `validate-frontmatter.sh`

### Phase 6: プロジェクトテンプレート + Fragments(2026-04-27)

- `project-fragments/`: `web-apps-common.md` / `games-common.md` / `board-game-design-common.md` / `pre-commit-config.template.yaml` / `adr-template.md`
- `project-templates/`: `nextjs-supabase` / `pixi-game` / `board-game-doc`(成熟度: 完成 / skeleton / 暫定 を `_README.md` でラベリング)
- `skills/project-tech-stack-decision`(技術スタック選定支援)

### Phase 5: 共通 Subagents(2026-04-27)

- `subagents/`: `code-reviewer` / `security-auditor` / `doc-writer` / `refactor-planner` / `explorer` / `research-summarizer`
- `subagents/_index.md` で全 subagent の一覧と起動契機を整理
- SubagentStop hook の枠を `meta/TODO-for-phase-7b.md` に予約

### Phase 4: 共通 Skills(2026-04-27)

- Tier 1 skills(汎用): `commit-conventional` / `pr-description` / `adr-writing` / `skill-creation`
- Tier 2 skills(中位): `dependency-review` / `security-audit`
- Tier 3 skills(下位): `nextjs-supabase-base` / `nextjs-supabase-rls` / `japanese-tech-writing`
- 言語別 style skills: `typescript-strict` / `python-style` / `go-style` / `rust-style`
- 言語別 testing skills: `testing-typescript` / `testing-python`

### Phase 3: Adapter 基盤(2026-04-27)

- `adapters/claude-code/user-level/CLAUDE.md`(全プロジェクト共通指示の確定版)
- `adapters/claude-code/user-level/settings.json.template`(permissions deny + allow / env / hooks 結線枠)
- `adapters/claude-code/user-level/mcp/servers.template.json`(secret 必須サーバーは含めない)
- `adapters/claude-code/VERSION`(2.1.119)
- クロスレイヤー参照のパス規約(skills / subagents は絶対パス)を `adapters/claude-code/README.md` に記述

### Phase 2: Practices 層(2026-04-27)

- 14 ファイル: `adr-workflow` / `skill-design-guide` / `session-handoff` / `project-bootstrap` / `refactoring-trigger` / `update-propagation` / `model-selection` / `testing-strategy` / `development-workflow` / `secure-coding-patterns` / `supply-chain-hygiene` / `secrets-handling` / `coding-style-conventions` / `commit-conventions`
- 各 practice は「関連する原則 / トリガー / 手順 / 判断基準 / アンチパターン / 旧資産からの継承」の 6 セクション

### Phase 1: Principles 層(2026-04-27)

- 7 ファイル: `00-meta` / `01-context-economy` / `02-decision-recording` / `03-skill-composition` / `04-progressive-disclosure` / `05-separation-of-concerns` / `06-evolution-strategy`
- 各 principle は「公理 / 帰結 / 運用への落とし込み / アンチパターン / 関連する practices / 旧資産からの継承」の 6 セクション
- 機械検出される禁止語(`meta/forbidden-words.txt`)を確定

### Phase 0.5: 旧設定の棚卸し(2026-04-26)

- `meta/migration-inventory.md`(取り込み判断 A / B / C 分類)
- 旧 `docs/superpowers/specs/plans/` 群は ADR 0002 方針により転記しない(C 分類)
- ADR 0002(Public/Private 境界)起票

### Phase 0: 旧設定の保全 + 新リポ初期化(2026-04-26)

- リポジトリ初期化(v3 マスタープランに基づく)
- ディレクトリ構造作成: `principles/` / `practices/` / `adapters/{claude-code,codex}/` / `projects/` / `tools/migrate/` / `tests/` / `meta/{decisions,retrospectives}/` / `.github/workflows/`
- ルートに `README.md` / `CLAUDE.md` / `LICENSE`(MIT)/ `.gitignore` / `.gitleaks.toml` / `VERSION`(0.1.0)を配置
- 各層に骨子の README を配置
- バックアップ専用ディレクトリ `~/.claude-system-backups/` 作成
- ADR 0001(匿名性ポリシー)起票
- gitleaks スキャン: 旧 claude-settings の git 履歴は clean を確認(232 件の検出はすべて gitignore 対象のランタイムログ)

---

## 関連

- [`decisions/`](./decisions/) — ADR
- [`integration-trace.md`](./integration-trace.md) — Phase 9 統合テストシミュレーション
- [`retrospectives/_template.md`](./retrospectives/_template.md) — 月次レトロのテンプレート
- [`TODO-for-v0.2.md`](./TODO-for-v0.2.md) — v0.2 以降に持ち越した項目
