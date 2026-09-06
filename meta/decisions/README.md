# 決定索引(現行の決定と再評価トリガー)

claude-system で**今この瞬間に生きている決定**を 1 画面に集めた索引。変更を計画するときはまずこのファイルを読む。行はその場で編集する現在形の文書で、過去の状態は保持しない。経緯・検証・退けた案の詳細は出典の ADR と [`meta/CHANGELOG.md`](../CHANGELOG.md) にある。運用規則は [`practices/adr-workflow.md`](../../practices/adr-workflow.md)。

## 規約

- 1 行 = 決定 / 根拠 / 再評価トリガー / 退けた案 / 出典(ADR 番号)。出典が複数なら最新を先に書く
- ADR は `NNNN-kebab-case.md`。連番・欠番禁止、撤回しても番号は残す。Status は `Proposed` / `Accepted` / `Rejected` / `Withdrawn`(0001〜0026 に残る `Superseded` 系は凍結された履歴)
- 新 ADR は 60 行以内・5 項目(決定 / 根拠 / 再評価トリガー / 不採用と理由 / 影響ファイル)。テンプレは [`adapters/claude-code/project-fragments/adr-template.md`](../../adapters/claude-code/project-fragments/adr-template.md)、採番は `tools/new-adr.sh`
- ADR を起票するのは、設定や共通指示に落とし込めない方針判断か、本索引の決定を覆すときだけ。旧 ADR は編集しない。覆すときは新 ADR の「覆す決定」欄と本索引の出典欄で表す
- 将来の実行の約束は同じコミットで [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) へ転記する。転記しない約束は履行されないものとして扱う
- Decider は ADR 0001 の識別子規約に従う(本名・新規連絡先を書かない)。Status 語彙・番号の実在・一覧との一致・覆す欄と注記の相互一致・60 行上限は `tests/check-doc-parity.sh` が検査する
- 「覆す」は決定本体を変えたときに限る。条件付き約束の撤回は索引の再評価トリガー欄で「閉じた」と書く。覆した旧決定は退けた案へ移し、消さない
- 索引の既存行の決定を覆す変更は、1 行で書けても ADR を起票する。新しい行の追加やトリガー・退けた案の更新は実物の隣の注記 + `meta/CHANGELOG.md` 1 行で足りる。その場合の出典欄は `注記: <ファイル>` か `CHANGELOG YYYY-MM-DD` と書く
- Status は起票時の状態で固定し、以後の覆しは索引でのみ表す。`Proposed` の ADR は採択されるまで索引に載せない

## 現行の決定

### 識別子と Public/Private 境界

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| 本名・個人呼称・新規連絡先を成果物に書かない。ローカル `git config user.*` を override しない | 個人情報が README / LICENSE / commit author に焼き込まれた実例 | 例外を許すときは ADR に理由を書く | なし | 0001 |
| 追跡ファイルに GitHub handle と個人 email の literal を書かない(例外: LICENSE の Copyright holder、GitHub URL の path、commit 履歴、明示プレースホルダ) | 書かなければ allowlist も検出緩和も要らない | handle 例外の境界に迷うケース | allowlist 化、handle 完全禁止、検出 paths 除外 | 0006 |
| Public 成果物から Private リソースへの直接リンクを作らない。旧設計から昇華した内容の出典は抽象的に書き、旧設定との関係は `meta/migration-from-claude-settings.md` に集約 | 第三者にはリンクが切れ、境界が曖昧化する | なし | 都度の個別判断 | 0002 |
| `/Users/<name>/` と `-Users-<name>-` を編集時 warn + commit 時 block の 2 段で検出。パターンは `hooks/_lib.sh` の単一ソース | 規範だけでは混入を偶然にしか見つけられない | multi-OS 展開 | block 統一、warn 統一 | 0008 |
| 会話索引(episodic-memory)は全プロジェクト横断のまま、検索結果を Public 成果物へ転記しない | 除外設定が無く Private の会話がヒットする | 索引側に除外機構が付いたとき | 索引の分割 | 0023 |

### 構造と記録

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| principles → practices → adapters → projects の 4 層。`meta/forbidden-words.txt` が唯一の真実源。配置は `~/ws/claude-system` 固定 | 層越境を機械検出できる | 別ツールへ乗り換え時に再利用性を検証 | モノリシック指示、フラット構造、環境変数パス化 | 0004 |
| 記録は決定索引 + 60 行以内の ADR + CHANGELOG。旧 ADR は凍結し、根拠は実物の隣に置く | 物語 ADR が判断を妨げ、Status 保守が過去の判断を再燃させた | なし | 現行形式の継続、ADR 廃止 | 0027 |
| 収束ループ(反復レビュー)の独立 practice 化は見送り、`iterative-review.md` の節で受ける | 適用 2 文脈のみ。`check` command の削除(2026-09-06)で文脈は 1 つ減った | 3 文脈で運用されたとき | 独立ファイル化 | 0019 |
| ADR の将来の約束は同じコミットで TODO へ転記 | 転記しない約束は 3 か月未履行だった | なし | なし | 0025 |
| `v0.1.0` タグは運用者判断待ち(不可逆・外向き) | 自動発行しない | 運用者が判断したとき(TODO 18) | 自動発行 | 0025 |
| 観測は failure-log / subagent-log / rework-log を hook で記録し `loop-report.sh` で集計する。gating はしない。昇格採否とアーカイブ実行は人間 | 測れば分かるのに測っていなかった。道具だけでレトロは回らない | レトロ連動の自動化(TODO 10、2026-10 判断) | SessionStart での昇格ドラフト生成、レトロ自動起動 | 0024 / 0019 / 0012 |
| principles 07(還流)は昇格させず `refactoring-trigger.md` の節で受ける | 「計測なき格上げをしない」の自己適用 | 収束構造が 3 文脈 + 月次レトロ 3 回 + 四半期見直し | 即時新設 | 0019 |

### メモリ

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| auto memory + episodic-memory の 2 層。Memory MCP は不採用 | 役割重複、セマンティック検索の欠如、可搬性 | 明示的な関係性グラフが要るとき | Memory MCP 継続、外部 SaaS、独自実装 | 0003 |
| episodic-memory は plugin の実インストールが要る(`tools/setup-plugins.sh`、doctor が WARN) | 宣言だけで 3 か月動いていなかった | なし | なし | 0023 |
| subagent 個別の永続メモリは使わない | 2 層構成を崩す | レビュー指摘の再発が観測されたとき | `memory:` フィールド採用 | 0027 |

### 委譲とモデル

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| メインは司令役。委譲トリガーは 5 クエリ超 / 10 ファイル以上 / 大量出力 / 独立並列。返却は構造化結論のみ | 中間出力が戻れば圧縮の利得を失う | なし | なし | 0011 |
| 単層連鎖(探索→計画→反証→実装→レビュー→最終ゲート→文書追従)。自前 subagent の `tools` に `Agent` を含めず構造的に保証。委譲ファーストは指示レベル、hook で強制しない | 物理強制は軽微作業の損益を壊す。観測の一元化 | 多段委譲を採るときは 0015 の改訂とセット | Edit/Write ブロック hook、`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` | 0027 / 0022 / 0015 |
| 探索は組み込み `Explore`(CLAUDE.md を読まず安価)。越権監査は組み込みエージェントに効かず、防衛は `pre-bash-guard.sh` とハーネスの tool 制限 | 自前 explorer は同役割で CLAUDE.md 17KB を毎回読んでいた | なし | explorer 維持、組み込み向け allowlist | 0027 |
| 主モデル `claude-fable-5-1[1m]`、fallback `["claude-opus-5[1m]"]`。反証役と最終ゲートは `model: fable`、他は alias(opus / sonnet / haiku) | 新世代での再評価(model-selection 手順 8)。高重要・低頻度は上位側 | 次世代の公開、`subagent-log.jsonl` の品質信号 | 全 alias 据え置き、上位 3 役 fable | 0027(0016 / 0022 を覆す) |
| メインループ effort は単一 `xhigh`。ロール別 effort は委譲先の `model` / `effort` で実現し固定テーブルにしない。subagent は `high` 以下 | 頻度 × 検証可能性 × 致命度。xhigh 以上の parse-error 安全性は subagent で未検証 | per-task effort 機構、opus 系ロールで parse-error 頻発 | 手動上下のみ、固定テーブル | 0013 / 0022 |
| ツール呼び出し parse-error は上流事象。層 0(機械タスクを軽量へ)+ 層 A(StopFailure 通知)+ `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70`。層 B(外部 watchdog)は保留 | 根絶不能。1M 高占有 + 強い thinking が誘発 | 上流の恒久修正、StopFailure が出力を honor | 設定で根絶、Stop hook 回復、無制限 auto-continue | 0014 |
| 可逆は自律実行、不可逆・外向きは確認。Workflow / loop / scheduled はオプトイン。この線引きは hook で機械強制しない | 並列・背景実行が安価になった世代以降の前提。文脈依存の判断は二値判定になじまない | なし | 線引きの hook 化(false-positive で運用を阻害) | 0010 / 0009 |

### ハーネス設定

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| `settings.json` は template ⊕ machine-overrides のビルド成果物。手編集廃止、`sync-settings.sh` が配置、git hooks が自動適用、doctor が drift 検知。overrides に方針リストを書かない | 手動マージで deny が実機に届かなかった | なし | symlink 配置、PostToolUse 即時適用、常駐 watcher | 0017 / 0022 |
| `~/.claude/{CLAUDE.md,agents,commands,hooks,skills}` は symlink、`settings.json` は実体 | 切り替え済み(2026-05) | なし | なし | 0025 / 0007 |
| `attribution: {commit:"", pr:""}` でセッション URL の自動付与を抑止 | Public repo にセッション URL を混入させない。2026-09-06 の 5 コミットに trailer / URL が無いことで実挙動を確認 | なし | なし | 0018 |
| env は `SUBPROCESS_ENV_SCRUB` / `AUTOCOMPACT_PCT_OVERRIDE=70` / `EXPERIMENTAL_AGENT_TEAMS` の 3 つ。`ENABLE_PROMPT_CACHING_1H` は削除 | サブスクリプションでは 1h TTL が既定で no-op | AGENT_TEAMS の GA | `promptCacheTtl`(同じく no-op) | 0027 |
| MCP は採用しない(ブラウザは `claude-in-chrome`、GitHub は `gh` CLI)。宣言系統(`setup-mcp.sh` / `servers.template.json` / inline `mcpServers`)は撤去 | 一度も実機に届いていなかった。`mcpServers` は settings の無効キー | CLI で代替できない外部連携が要るとき | opt-in 宣言の維持、宣言↔実体検査の設計 | 0027(0026 §4 / 0018 §1 を覆す) |
| 不採用の settings: `disableBundledSkills` / `requiredMinimumVersion` / `CLAUDE_CODE_SUBAGENT_MODEL` / `sandbox.network.strictAllowlist` / `crossSessionInbound` / `outputStyle` / `timeFormat` / `PreModelSwitch` hook / `CLAUDE_CODE_ENABLE_TODO_TOOLS` / `autoMode.classifyAllShell`(allow-list を打ち消す)/ `workflowSizeGuideline` / `DirectoryAdded` / `git commit --amend` の deny(正当な用途を止める) | 個人運用に不要、または前提と衝突 | strictAllowlist は列挙粒度の改善、crossSessionInbound は複数マシン運用の開始 | なし | 0027 / 0026 / 0022 / 0018 / 0016 |
| doctor は `claude` CLI を呼ばない(毎ターンの Stop hook から走る) | 入れ子セッションの起動を避ける | なし | CLI 経由の宣言↔実体検査 | 0023 |
| ハーネス pin は実インストール版に一致させ(`adapters/claude-code/VERSION`)、README の散文と `check-doc-parity.sh` で対にする | 2 回ずれた | なし | pin をテスト済み全版の列挙にする | 0026 |

### 外部連携

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| セッション外・イベント / 時刻起点・外部 SaaS 連携はワークフローエンジン(セルフホスト n8n)、セッション起点はハーネス。Claude Code ↔ n8n は `localhost:5678/webhook/cc-*` と `docker compose` のみ、n8n からホスト実行しない、`.env` / `backups/` は Read deny + 指示(`compose exec … env` は機械保証しない)。真実源は Private repo、claude-system は記録のみ | 常駐が要る用途(TODO 10)と、境界を設計と呼べない permissions の実態 | TODO 10 の判断(2026-10)、24 時間稼働が要るフロー、Server CLI export の deprecated 化 | MCP 経由、claude-system 内テンプレート、docker.sock、広い carve-out、常駐バックアップ | 0028 |

### ガードレール

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| `permissions.deny` + `pre-bash-guard.sh` の多層(破壊コマンド / `--no-verify` / subagent push)。指示で効かないものは機械化する | 指示だけでは push 事故が起きた | なし | 全 hook の deny 統合 | 0024 / 0004 |
| `cd` は deny(絶対パスと `git -C` を使う。作業ディレクトリの移動は遅く、hook の cwd 前提を崩す) | 実測で遅延と誤動作 | なし | なし | 注記: settings.json.template |
| Betterleaks の allow は `dir` / `git` / `config` / `version` のみ。`validate` / `--validation`(検出した秘密を発行元 API へ送る)と `github` / `gitlab` / `huggingface` / `s3` は deny | 送信系は都度確認する方針 | なし | `betterleaks *` の包括 allow | 注記: settings.json.template |
| subagent の push は PreToolUse の `agent_type` で deny、主防衛は `tools/githooks/pre-push`(`CS_ALLOW_PUSH=1` で通す)。他リポジトリには効かない | ハーネス内部の git 実行は PreToolUse を通らない | 独立背景セッションの判別手段が現れたとき | 正規表現による判定 | 0024 |
| doctor は fast(毎ターン Stop hook)/ full(コミット前・CI)の 2 ティア | ulimit 10 秒の 61% を消費していた | なし | 単一ティア | 0024 |
| 失敗記録は PostToolUseFailure(Bash)で 3 形の payload を防御的に読む。intent / 14 日窓 / 集計 | PostToolUse は失敗時に発火しない | payload 形の変更(テストと e2e で検出) | docs 形のみ、Stop hook で transcript 走査 | 0020 |
| 秘密検出はローカル層 Betterleaks(`.gitleaks.toml` 互換)、CI は gitleaks-action | 既存設定で両者の検出結果が一致 | CI Action の確認(TODO 20)、gitleaks の修正停止 | gitleaks 据え置き(0018 / 0021 / 0022 / 0023 で 4 回) | 0027(0018 §4 / 0021 §4 / 0022 §7 / 0023 §10 を覆す) |
| 出力キャップ hook は撤去し、`bashOutputMaxChars: 30000` を明示(既定と同値)。超過分はファイル退避 | 上限で流入は有界、超過分は退避で失われない。hook は末尾以外を不可逆に捨てていた | 既定値の変更 | hook 維持 | 0027(0012 を覆す) |
| 死文化した deny(`Write(path)` 7 件)は即削除。deny は実効ルールのみ | 履歴で追跡できる | 2.1.210 未満のマシン追加 | 残置 | 0021 |
| CI の doctor は macOS runner | BSD コマンド前提が方針 | Linux 運用の開始 | Linux で skip、両 OS 対応 | 0026 |

### 供給網とプラグイン

| 決定 | 根拠 | 再評価トリガー | 退けた案 | 出典 |
|---|---|---|---|---|
| 依存は公開後 7 日待つ。機械ブロックは `bun add` 系のみで、plugin / bunx / brew は公開日を手動確認 | タイポスクワットと乗っ取り | なし | なし | 0026 / 0023 |
| プラグインは superpowers / episodic-memory / elements-of-style の 3 件。`// auditedPluginVersions` と実インストールの一致を doctor が検査し、更新時は持ち込み能力を棚卸しする。episodic-memory の更新時は監視下で `npm install` を実行し lockfile を固定し直す | 宣言と実体が 3 か月乖離していた。ラッパーが `npm install` を自走する | 持ち込み能力(hook / MCP / agent)の増減 | Context7、Frontend Design | 0023 / 0021 |
| superpowers の重複 skill は無効化しない。常時コンテキストは削減しない | 使用実績で 5 本が現役。`skillOverrides` は plugin 対象外、`Skill(name)` deny は description を残す | 使用回数 0 の skill が出たとき(0024 §4 の条件付き約束は閉じた) | `Skill(name)` deny | 0027 / 0024 |
| 自前 skill / command は使用実績で剪定する(180 日 0 回は削除候補)。frontmatter は `name` / `description` のみ | `/skill-doctor` で 13 件が 0 回だった | 次回 update-check の `/skill-doctor` | 全件維持 | 0027 |
| 移行スクリプトは再実行可能に保ち、構造変更 = migrate / 値配置 = sync と責務分離 | dangling symlink で移行が中断した実例 | なし | 移行側で値も配置 | 0007 |

## ADR 一覧(0001〜0026 は凍結)

| # | タイトル | Status | 日付 |
|---|---|---|---|
| [0001](./0001-anonymity-policy.md) | 匿名性ポリシー | Accepted | 2026-04-26 |
| [0002](./0002-public-private-boundary.md) | Public/Private 境界 | Accepted | 2026-04-26 |
| [0003](./0003-memory-architecture.md) | メモリアーキテクチャ | Accepted | 2026-04-26 |
| [0004](./0004-system-architecture-summary.md) | システムアーキテクチャ総括 | Accepted | 2026-04-29 |
| [0005](./0005-bootstrap-completion-and-deferral.md) | bootstrap 完了と Phase 10 遅延 | Accepted | 2026-04-29 |
| [0006](./0006-no-user-identifiers-in-system.md) | ユーザー識別子を書かない | Accepted | 2026-04-29 |
| [0007](./0007-phase10-migration-script-robustness-and-boundary.md) | 移行スクリプトの堅牢性と責務境界 | Accepted | 2026-05-04 |
| [0008](./0008-mechanical-detection-of-user-identifier-paths.md) | ユーザー識別子パスの機械検出 | Accepted | 2026-05-04 |
| [0009](./0009-opus-48-autonomy-tuning.md) | 自律性チューニング | Accepted | 2026-05-29 |
| [0010](./0010-opus-48-harness-settings-sync.md) | ハーネス同期 2.1.156 | Partially superseded by 0016 | 2026-05-29 |
| [0011](./0011-delegation-orchestration-protocol.md) | 委譲・オーケストレーション規約 | Accepted | 2026-05-29 |
| [0012](./0012-token-economy-mechanization.md) | トークン経済の機械化(出力 cap は 0027 が撤去) | Accepted | 2026-05-29 |
| [0013](./0013-role-based-effort-modulation.md) | ロール別 effort の変調 | Accepted | 2026-05-31 |
| [0014](./0014-tool-call-parse-error-resilience.md) | parse-error 耐性 | Accepted | 2026-06-05 |
| [0015](./0015-delegation-chain-and-mandatory-delegation.md) | 委譲チェーンと委譲ファースト | Accepted | 2026-06-06 |
| [0016](./0016-fable-5-harness-settings-sync.md) | ハーネス同期 2.1.170(Fable 5。tier 据え置きは 0027 が置換) | Partially superseded by 0022 | 2026-06-10 |
| [0017](./0017-settings-auto-sync.md) | settings の決定論的レンダリングと自動同期 | Accepted | 2026-06-10 |
| [0018](./0018-harness-sync-2.1.197.md) | ハーネス同期 2.1.197(MCP pin と Betterleaks 据え置きは 0027 が置換) | Accepted | 2026-07-01 |
| [0019](./0019-loop-engineering-phased-adoption.md) | ループエンジニアリングの段階導入 | Accepted | 2026-07-08 |
| [0020](./0020-failure-hook-event-migration.md) | failure hook の PostToolUseFailure 移行 | Accepted | 2026-07-11 |
| [0021](./0021-harness-sync-2.1.217.md) | ハーネス同期 2.1.217(Betterleaks 据え置きは 0027 が置換) | Accepted | 2026-07-22 |
| [0022](./0022-harness-sync-2.1.220.md) | ハーネス同期 2.1.220(Opus 5。model pin と Betterleaks 据え置きは 0027 が置換) | Accepted | 2026-07-25 |
| [0023](./0023-harness-sync-2.1.226.md) | ハーネス同期 2.1.226(プラグイン実導入。Betterleaks 据え置きは 0027 が置換) | Accepted | 2026-08-08 |
| [0024](./0024-observation-and-restraint-optimization.md) | 観測と抑止の最適化(§4 は 0027 が閉じた) | Accepted | 2026-08-09 |
| [0025](./0025-symlink-switchover-record-and-release-tagging.md) | symlink 切り替え記録とリリースタグ | Accepted | 2026-08-09 |
| [0026](./0026-harness-sync-2.1.229.md) | ハーネス同期 2.1.229(§4 は 0027 が撤去で解決) | Accepted | 2026-08-13 |
| [0027](./0027-fable-5-1-sync-and-pruning.md) | Fable 5.1 同期と使用実績に基づく剪定 | Accepted | 2026-09-06 |
| [0028](./0028-n8n-workflow-engine-boundary.md) | ワークフローエンジン(セルフホスト n8n)の切り分け・境界・配置 | Accepted | 2026-09-06 |
