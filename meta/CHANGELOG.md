# CHANGELOG

このリポジトリの変更履歴。Phase 単位でセクション化する。

## Claude Code 2.1.197 への harness 同期(2026-07-01)

`update-check` skill による調査(WebFetch で releases / changelog / gitleaks releases / settings schema を裏取り)に基づき、機械層を Claude Code 2.1.197(2026-06-30。既定モデルが Sonnet 5 / 1M へ)に同期した。判断の本体は [ADR 0018](./decisions/0018-harness-sync-2.1.197.md)。

### harness 同期(ADR 0018)

- `adapters/claude-code/VERSION`: `2.1.170` → `2.1.197`(2.1.170 以降 27 パッチ分の差分を点検)
- `adapters/claude-code/user-level/settings.json.template`
  - `attribution: { "commit": "", "pr": "" }` 新設。Public メタリポの commit/PR に claude.ai セッション URL(harness 自動 attribution)を混入させない(ADR 0002)。安定 settings スキーマに `sessionUrl` キーは存在せず(`additionalProperties: false`)、空文字で当該 attribution ブロックごと抑止する。`Co-Authored-By` / `Generated with Claude Code` は `user-level/CLAUDE.md` の指示でモデルが別途付与するため失われない
  - `@playwright/mcp`: `0.0.75` → `0.0.77`
- `adapters/claude-code/user-level/mcp/servers.template.json`
  - `@playwright/mcp`: `0.0.75` → `0.0.77`
  - `chrome-devtools-mcp`: `1.2.0` → `1.4.0`(マイナー、破壊的変更なし)
  - `sequential-thinking`(2025.12.18)は最新のため据え置き
- `.github/workflows/doctor.yml`: `GITLEAKS_VERSION` `8.21.2` → `8.30.1`(ADR 0016 で「本体 8.30.1 が最新」と認識済みだった doctor 用 CLI pin の取り残しを解消。新規検出ルール Bedrock / Looker / Airtable を取り込む)
- モデル方針は据え置き(`claude-fable-5` / fallback `claude-opus-4-8` / `effortLevel: xhigh`)。Fable 5 は現行最上位のため Sonnet 5 既定化の影響を受けない

### code review follow-up(2026-07-01)

同期差分を `code-reviewer` subagent でレビューし、doc ギャップと既存の構造的重複を解消(TODO-for-v0.2 項目 17 をクローズ):

- `adapters/claude-code/README.md`: 新規 `attribution` キーを機能表・影響範囲マップに追加。「MCP 登録経路」節を新設
- MCP 登録経路の二重管理を解消: playwright を `mcp/servers.template.json` から除去し `settings.json.template` の inline に一本化(常時ロード=インライン / opt-in・secret=宣言)。inline playwright の runner を `npx` → `bunx` に統一(bun 優先 / user-level CLAUDE.md §5)。実環境では宣言側が未登録のため二重ロードの実害は発生前に解消

### 調査して見送った項目

- `sandbox.credentials`(v2.1.187): 不採用。認証情報をサンドボックスへ露出する allowlist で、既定サンドボックスが元々遮断するため不要
- `autoMode.classifyAllShell`(v2.1.193): 不採用。allow ルールを全停止し分類器へ回すため、精選 allow-list のトークン経済(ADR 0012)を打ち消す
- `enforceAvailableModels` / `footerLinksRegexes` / `requiredMinimumVersion` / `disableBundledSkills`: 不採用(ADR 0016 §4 と同旨)
- `TeamCreate`/`TeamDelete` 削除(v2.1.178)・`CLAUDE_CODE_SUBAGENT_MODEL` スコープ変更(v2.1.147): リポジトリ内参照ゼロ / 既に不採用のため影響なし
- betterleaks(gitleaks 後継): 実績浅く据え置き。2026 末を目安に再評価(ADR 0016 の記録を継承)

## settings.json 自動反映機構(2026-06-10)

ADR 0010/0016 で Neutral 事項として繰り越し続けた「template 更新が配置済み `~/.claude/settings.json` に自動反映されない」ギャップを解消した。判断の本体は [ADR 0017](./decisions/0017-settings-auto-sync.md)。

- **レンダリングモデル**: 配置ファイル = `jq` deep-merge(`settings.json.template` ⊕ `~/.claude/settings.machine-overrides.json`)。配置ファイルは手編集禁止のビルド成果物(`"// managed"` マーカー焼き込み)
- `tools/sync-settings.sh` 新設: dry-run(正規化 diff)/ `--apply`(バックアップ + 原子的書き込み)/ `--check`(ドリフト時 exit 1)。settings.json 配置の責務を `sync.sh` から移管(ADR 0007 の境界更新)
- `tools/githooks/{post-commit,post-merge}` 新設: template に触れたコミット / pull で `--apply` を自動実行(fail-open、git 操作は阻害しない)。結線は `setup.sh` の冪等ステップ `git config core.hooksPath tools/githooks`
- `tools/doctor.sh`: hooksPath 結線とドリフトのチェックを追加(配置のないマシン / CI では informational)
- `tests/test-sync-settings.sh` 新設: マージ優先順位・冪等性・ドリフト検知・バックアップ生成を使い捨て HOME で検証
- 初回移行: 実機の意図的ローカル値(`agentPushNotifEnabled` / `effortLevel` / `remoteControlAtStartup` / `skipWorkflowUsageWarning`)を overrides へ抽出し、陳腐化分(deny エントリ・MCP pin の遅れ)はレンダリングで解消

## Fable 5 / Claude Code 2.1.170 への harness 同期(2026-06-10)

`update-check` skill による調査(research-summarizer 4 並列委譲 + claude-code-guide での設定キー裏取り)に基づき、機械層を Fable 5 GA(2026-06-09)/ Claude Code 2.1.170 に同期した。判断の本体は [ADR 0016](./decisions/0016-fable-5-harness-settings-sync.md)。

### harness 同期(ADR 0016)

- `adapters/claude-code/user-level/settings.json.template`
  - `model`: `claude-opus-4-8` → `claude-fable-5`(Fable 5 は常時 1M context のため `[1m]` サフィックス不要)
  - `fallbackModel: ["claude-opus-4-8"]` 新設(v2.1.166 追加キー。過負荷・不達時の縮退先を明示し、安全クラシファイアの自動フォールバック先と整合)
  - `effortLevel: xhigh` 据え置き(公式 docs で Fable 5 は xhigh をサポート、デフォルトは high)
  - env コメントの世代表記を「Fable 5 期も有効維持」へ更新。`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` は据え置き
- `adapters/claude-code/VERSION`: `2.1.156` → `2.1.170`(TODO-for-v0.2 項目 16 をクローズ)
- `adapters/claude-code/user-level/CLAUDE.md` §6: autonomy 記述を「Opus 4.8 期に確立し Fable 5 期も継続」へ更新(方針の中身は ADR 0009 のまま不変)
- subagent の model tier(opus/sonnet/haiku)は据え置き。alias は引き続き有効で、Fable 化は `subagent-log.jsonl` の計測根拠が出てから再評価(ADR 0016 §2)

### 依存 pin の更新

- `settings.json.template` の `@playwright/mcp`: `0.0.70` → `0.0.75`(`mcp/servers.template.json` は更新済みだった取り残しを解消。v0.0.72 で `browser_run_code` → `browser_run_code_unsafe` 改名があるが、本リポジトリにツール名への参照はなし)
- `mcp/servers.template.json` の `chrome-devtools-mcp`: `1.1.1` → `1.2.0`(マイナー。`allowedUrlPattern` / `blockedUrlPattern` 追加、破壊的変更なし)
- `.github/workflows/secrets-scan.yml` の `gitleaks/gitleaks-action`: `v2` → `v3`(GitHub Actions の Node 20 ランタイムが 2026-09-16 に削除予定のため。gitleaks 本体 8.30.1 は最新で据え置き)

### 調査して見送った項目

- `disableBundledSkills` / `requiredMinimumVersion` 等の新キー、`CLAUDE_CODE_SUBAGENT_MODEL` env: 不採用(理由は ADR 0016 §4)
- betterleaks(gitleaks 後継、同作者): v1.4.1 まで stable・`.gitleaks.toml` 互換だが、プロジェクト開始 4 ヶ月でコミュニティ実績が浅く様子見。2026 末を目安に再評価
- 公式 plugin `security-guidance`、MCP `Context7` / GitHub MCP の常設化: 検討候補として記録のみ(既存ガードレール・運用との重複評価が先)
- episodic-memory v1.4.0 の `/search-conversations` 削除: 本リポジトリ内に同コマンドへの参照はなく対応不要(プラグイン本体の更新はローカル運用側)

## リポジトリ棚卸し + 委譲/トークン経済の ADR 起票(2026-05-29)

リポジトリ全体を分析し、stale 情報のクローズと、運用プロトコルが薄かった 2 領域(委譲オーケストレーション / トークン経済)の設計を ADR として起票した。

### 整理(stale クローズ)

- `meta/TODO-for-v0.2.md`: 先頭にステータス区分表を追加(継続保留 / トリガー待ち / 解決済みの仕分け)。項目 12(migrate スクリプトの dangling symlink 耐性)・項目 13(settings.json 配置の責務整合)は ADR 0007 + commit `8e2ed0d` で実装済みのため本文を「解決済み(クローズ記録)」へ移動
- `CLAUDE.md`「Phase 進行」節: bootstrap(Phase 0-10)完了済み(ADR 0005)の事実を反映し、`~/.claude-system-bootstrap/` を現役手順ではなく歴史的資料と位置づけ。継続課題は TODO-for-v0.2、完了履歴は CHANGELOG を参照する形へ書き換え

### ADR 起票 + 実装(Accepted)

- `0011-delegation-orchestration-protocol.md`: メイン=オーケストレータ規律の明文化。役割分離 / 委譲トリガー(定量基準)/ 渡す情報と返却スキーマ(structured output)/ 単発→ファンアウト→Workflow の段階。ADR 0009 §2(委譲積極化・方針)の運用プロトコル詳細として位置づけ
  - 実装: `practices/delegation-orchestration.md` 新設、`adapters/claude-code/subagents/_index.md` に「委譲プロトコル」節を追加
- `0012-token-economy-mechanization.md`: トークン抑制の機械化。圧縮ポイントの因果一覧 / 出力キャップ hook / `subagent-log.jsonl` を計測点に接続。principles/01 の公理を機械実装と計測へ落とす
  - 実装: `practices/token-economy.md` 新設、出力キャップ hook `pre-bash-output-cap.sh` を導入し `settings.json.template` の PreToolUse(Bash)へ結線
  - 機構の訂正: 当初 ADR は「PostToolUse でキャップ」と記したが、PostToolUse は実行済み結果を変更できないため **PreToolUse + `hookSpecificOutput.updatedInput.command`**(Claude Code v2.0.10+)でコマンドを実行前に書き換える方式へ変更。test/build/lint の単純コマンドのみ stdout を `tail`、stderr と終了コード(`PIPESTATUS`)は保持

### 文書更新

- `adapters/claude-code/user-level/hooks/_README.md`: 「Phase 3 プレースホルダ / Phase 7b 実装予定」のまま実態と乖離し、未移植の `filter-test-output.sh` を予定として記載し retire 済みの `TODO-for-phase-7b.md` への切れリンクを含んでいたため、実装済み hook 一覧へ全面更新
- `practices/README.md`: 構成表に 2 practice を追加
- `meta/decisions/README.md`: 既存 ADR 表に 0011 / 0012 を追加(Accepted)
- `meta/claude-version-log.md`: 2026-05-29 の棚卸し + ADR 0011/0012 行を追記

---

## 依存・ドキュメントの陳腐化解消(2026-05-29)

`update-check` 観点での棚卸しにより、グローバル基盤側に残っていた版ずれを解消した。

### MCP テンプレートのバージョン更新

- `adapters/claude-code/user-level/mcp/servers.template.json`
  - `chrome-devtools-mcp`: `0.20.3` → `1.1.1`(メジャーバンプ)。破壊的変更は実行時ツール挙動(`pageId` の必須化、`getSelectedMcpPage` の廃止、シグナルハンドリング刷新)が中心で、起動方法 `npx chrome-devtools-mcp@<version>` および `setup-mcp.sh` の args 受け渡しは不変のため、テンプレートの pin 更新のみで安全と確認
  - `@playwright/mcp`: `0.0.70` → `0.0.75`(minor)
  - `sequential-thinking`(`2025.12.18`)は最新のため据え置き

### ドキュメント修正

- `adapters/claude-code/README.md`: 前提バージョン散文 `現在: 2.1.119` → `2.1.156`(VERSION 本体は ADR 0010 で同期済みだが散文が取り残されていた)
- `adapters/claude-code/user-level/commands/update-check.md` ガードレール調査項目: gitleaks が feature-complete を宣言(今後はセキュリティパッチのみ、メンテナは後継プロジェクトへ移行表明)した事実を反映し、追従方針を「セキュリティ修正のみ追従 + 後継/代替の動向を継続評価」に更新

---

## Opus 4.8 自律性チューニング(2026-05-29)

運用モデルが Opus 4.7 から 4.8 に更新されたことを受け、4.7 期に専用 ADR を持たず adapter 層へ散文として点在していた自律性運用方針を ADR として正式化し、4.8 の能力(マルチエージェント・オーケストレーション / background 実行・スケジューリング / 並列ファンアウト / 構造化質問 / 遅延ツールロード)を前提に更新した。

### ADR 起票

- `0009-opus-48-autonomy-tuning.md`(autonomy 方針の初回正式記録。従来 ADR 化されていなかったため supersede 対象なし)
  - 確認抑制の線引き明文化: 可逆操作は自律実行、不可逆・外向き操作(削除 / `git push` / コミット / 外部送信)は事前確認、durable な承認は当該文脈で再利用
  - サブエージェント委譲の積極化: 並列ファンアウトが安価・確実なため境界では委譲を選ぶ。独立タスクは 1 メッセージで並列ツール呼び出しを既定化
  - Workflow(マルチエージェント・オーケストレーション)はユーザー明示オプトイン時のみ起動(token コスト大のため自動・暗黙起動しない)
  - background 実行 / スケジューリング指針: `run_in_background` は長時間タスク、harness 追跡作業はポーリングしない、`/loop` / scheduled agents は明示要求時のみ
  - 補足: 「困ったら問い直す」の手段に構造化質問を活用(既定のある選択・検証可能な事実には使わない)

### 文書更新

- `adapters/claude-code/user-level/CLAUDE.md` §6 作業フロー: 「Opus 4.7 期」→「Opus 4.8 期」+ 確認抑制の線引きと ADR 0009 参照を追記
- `adapters/claude-code/subagents/explorer.md` 起動の判断基準: 「Opus 4.7 期は単発の小タスクはメイン直接実行」→ 4.8 期は委譲寄り、広範な探索は早めに委譲(ADR 0009 参照)
- `meta/decisions/README.md`: 既存 ADR 表に 0009 を追加
- `meta/claude-version-log.md`: 2026-05-29 Opus 4.8 行を追記

履歴記録(`migration-inventory.md`、`claude-version-log.md` の過去行、ADR 0003 / 0004 の「4.7 期に構築」等)は時点の事実として変更しない。

### 機械層の同期(ADR 0010)

ADR 0009 が方針層(adapter の散文 + ADR)を更新したのに対し、harness の機械層が 4.7 期の値のまま残存していたため同期した。

- ADR 起票: `0010-opus-48-harness-settings-sync.md`
  - autonomy 方針(可逆/不可逆の線引き・委譲・Workflow オプトイン)は文脈依存判断のため hook 強制になじまないと判断し、新規 hook を増設しない方針を明記
  - 既存ガード(`permissions.deny` + `pre-bash-guard.sh` の deny/ask)が「不可逆操作は確認」の線引きを既に部分担保していることを確認・記録
- `adapters/claude-code/user-level/settings.json.template`: `model` を `claude-opus-4-7` → `claude-opus-4-8`、env コメントの 4.7 期記述に 4.8 期維持を追記
- `adapters/claude-code/VERSION`: `2.1.119` → `2.1.156`(`claude --version` で確認した実インストール版に pin 同期)
- permissions allow/deny は据え置き(モデル世代非依存)

---

## Phase 10 follow-up 2: ユーザー識別子パスの機械検出(2026-05-04)

ADR 0006 が「user identifiers literal を tree に書かない」を規範化していたが、絶対パス内ユーザー名(`/Users/<name>/`)については機械検出が空白だった。Phase 10 follow-up 1 のレビュー過程で `/Users/<name>/...` literal の混入が手動 grep で発見されたことを契機に、規範の第一防衛線を機械担保で補強する第二防衛線を追加。

### ADR 起票

- `0008-mechanical-detection-of-user-identifier-paths.md`
  - 二段階防衛: 編集時 warn(`post-edit-validate.sh`)+ commit 時 block(`.gitleaks.toml` custom rule)。レベル分けは「編集中の試行錯誤を妨げず、commit 段階では確実に止める」両立のため
  - 自己参照回避: 検出パターン自身が `/Users/` literal を含むため、検出器の定義ファイル群(`hooks/` 配下、`.gitleaks.toml` 自身)は paths allowlist で個別除外
  - ADR 0006 自身の例外節は無修正(ADR 0007 で確定した「禁じ手」方針との一貫性)
  - macOS 前提で実装、multi-OS 対応時の検出パターン拡張は Negative に明記して将来再判断

### 実装

- `adapters/claude-code/user-level/hooks/post-edit-validate.sh`:
  - 第 3 検出器として `/Users/[a-zA-Z0-9._-]+/` の grep 検出を追加(SKILL.md / forbidden-words に並列)
  - 編集対象が `adapters/claude-code/user-level/hooks/*` 配下の場合はスキップ(自己参照回避)
- `.gitleaks.toml`:
  - custom rule `[[rules]] id = "user-identifier-path"` を追加(commit 時 block レイヤ)
  - 既存 `[allowlist].paths` に hooks ディレクトリ (`adapters/claude-code/user-level/hooks/.*`) とランタイム生成物 (`\.claude/.*`) を統合追記
- `meta/integration-trace.md`:
  - Phase 9 シミュレーションログ(`sync.sh --dry-run` 出力例)の line 167-177 を `/Users/<name>/...` から `~/...` チルダ表記に置換。新規違反を allowlist で逃がす誘惑を断ち切るための既存修正(ADR 0008 の起票時に initial detection で発見)
- `meta/decisions/README.md`: 既存 ADR 表に 0008 を追加

### 検証

- 自己テスト(literal 一時挿入 → 4 段階確認 → 復元):
  - warn 検出: post-edit-validate.sh が `[hook][WARN] user-identifier path ... (ADR 0008)` を stderr 出力 → OK
  - block 検出: `git add` 後 `gitleaks` が exit 1 + custom rule `user-identifier-path` ヒット → OK
  - byte-perfect 復元: `diff -q` 完全一致 → OK
  - clean 復帰: 復元後 `gitleaks` exit 0 + `no leaks found` → OK
- `gitleaks detect --no-git --config .gitleaks.toml`: no leaks found(誤検出ゼロ)
- `shellcheck -S warning`: pass

---

## Phase 10 follow-up 1: migrate スクリプトの堅牢性と責務境界(2026-05-04)

Phase 10 実行中に発見された 2 つの観測 — `from-claude-settings.sh` が壊れた symlink で停止した点と、Step 7 の文言が `sync.sh` の自動配置と矛盾していた点 — を、再実行可能性と責務境界という共通テーマで一体的に対処した。`meta/TODO-for-v0.2.md` 項目 12, 13 を消化。

### ADR 起票

- `0007-phase10-migration-script-robustness-and-boundary.md`
  - 堅牢性方針: preflight で dangling symlink を検出 → 対話環境では削除選択、非対話環境では警告のみで続行 / Step 4 を `find -print0` ベースの局所関数に置換し dangling は skip + warn(両案併用)
  - 責務境界: `from-claude-settings.sh` = 1 回限りの構造変更、`tools/sync.sh` = 再実行可能な値配置(machine-local cp-deploy)。settings.json の cp は `sync.sh` の責務であることを明文化(案 X、文言整合)

### 実装

- `tools/migrate/from-claude-settings.sh`:
  - 冒頭ヘッダコメントを ADR 0007 の 3 つの挙動(preflight / robust copy / delegated settings.json)に揃えて書き換え
  - 局所関数 `cs_robust_copy_resolved` を新設(dangling skip + 解決可能 symlink は `cp -L`、ディレクトリは mkdir、ファイルは `cp`)
  - **Step 2.5(新規)**: dangling symlink scan + 対話削除選択(非対話は警告のみで続行)
  - **Step 4**: `cp -L -R` を `cs_robust_copy_resolved` に置換、skip 件数を末尾でサマリ表示
  - **Step 7**: 「manual placement」を撤回、「次に `tools/sync.sh` を実行」に書換(設計と挙動の整合)
  - Summary の Next step 表示を `tools/sync.sh` への誘導に書換
- `meta/decisions/README.md`: 既存 ADR 表に 0007 を追加

### 検証

- `tools/doctor.sh`: clean(error 0)
- `shellcheck -S warning`: pass(warning level)
- 挙動シミュレーション: dry-run で Step 2.5 / Step 4 / Step 7 の出力を目視確認

---

## Phase 10: 旧設定からの移行(2026-05-04)

`~/.claude/` を `~/ws/claude-settings/` への symlink から claude-system 配下を指す構成へ切り替えた。新システムでの Claude Code 起動を確認。

### 実行

- `tools/migrate/from-claude-settings.sh` は Phase 9 の `79901da`(2026-04-29 17:31)で配置済、Phase 10(2026-05-04 16:25)で実行
- 新構成: `~/.claude/{CLAUDE.md, skills, hooks, commands, agents}` が `claude-system/adapters/claude-code/` 配下への symlink
- `~/.claude/settings.json` は template と一致した状態で配置(10858 bytes)
- 永続バックアップ: `~/.claude-system-backups/migration-20260504-162515/dot-claude-resolved/`(移行前は `~/ws/claude-settings` への symlink)
- 旧 `~/ws/claude-settings/` はアーカイブ扱い(読み取り専用)

### 遭遇した issue

- Step 4 のバックアップ(`cp -L -R`)が `~/ws/claude-settings/debug/latest` の壊れた symlink(消えた実体を指す dangling link)で exit 1。当該 symlink を手動削除してリトライし復旧した
- 移行中に発見された改善点 2 件は [`TODO-for-v0.2.md`](./TODO-for-v0.2.md) に記録(migrate スクリプトの壊れた symlink 耐性 / Phase 10 手順における settings.json 配置の責務整合)

### 検証

- `from-claude-settings.sh` 内蔵の Step 8 で `tools/doctor.sh` 自動実行 → clean
- 新システムで Claude Code が起動し、CLAUDE.md / skills / hooks / commands / agents の解決を確認
- 切替後の `~/.claude/settings.json` と `adapters/claude-code/user-level/settings.json.template` を `diff` で比較 → 完全一致

---

## [v0.1.0-rc2] — 2026-04-29

rc1 のレビュー対応で「`.gitleaks.toml` の email literal は ADR 0001 違反」として複雑な対応(paths 除外 / allowlist regexes / hooks 環境変数)が入ったが、本質的な対策は「そもそもユーザー識別子を claude-system に書かない」だったと再評価。新たに ADR 0006 を起票して原則を確立し、rc1 で導入した過剰反応を簡素化した。

### Phase 9 追加対応(2026-04-29、rc1 → rc2)

- ADR 起票: `0006-no-user-identifiers-in-system.md`(ADR 0001 の具体実装)
  - 本名 / 個人 email literal / GitHub handle literal を claude-system 内に書かない
  - 例外: LICENSE Copyright holder / `https://github.com/<handle>/<repo>` の URL 自動参照 / 手順書の `<your-...>` 明示プレースホルダ / global git config 由来の commit author
- ADR 0001 修正:
  - `tanaka128821@gmail.com` literal を `<personal-email>` プレースホルダに置換
  - `u-stem` literal の例示を抽象化
  - Decision セクションに「具体実装は ADR 0006 を参照」を追記
  - 過去 Public 露出の経緯記述を抽象化(具体リポジトリ名 7 件のリストアップを撤回)
- 簡素化:
  - `.gitleaks.toml`: ADR 0001 を `paths` から除外する設定を撤回(literal が消えたため allowlist 不要)
  - `subagent-stop-audit.sh`: `SUBAGENT_AUDIT_KNOWN_EMAILS` 環境変数 + 許容アドレス除外ロジックを撤去。検出されたら本当に新規混入なのでログがそのまま実害シグナル
- 文書整合化:
  - `adapters/claude-code/user-level/CLAUDE.md` の識別子規範表を ADR 0006 ベースに更新
  - `adapters/claude-code/user-level/skills/adr-writing/SKILL.md` の DECIDER 例示から `u-stem` literal を撤去
  - `adapters/claude-code/project-templates/nextjs-supabase/_TEMPLATE_USAGE.md` の `{{DECIDER}}` 説明を「handle literal は非推奨」に修正
- `meta/decisions/README.md` の表に 0006 を追加
- `git tag v0.1.0-rc2`

### 検証

- doctor.sh: 38/38 OK / warn 0 / error 0
- gitleaks: no leaks found
- shellcheck / lint-skills / lint-principles-language / check-circular-refs / validate-frontmatter: 全 pass
- `Mikiya` / `tanaka128821` の grep: 0 hit
- `u-stem` の grep: LICENSE / GitHub URL / ADR 0006 自身のみ(すべて例外条項該当)

---

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
