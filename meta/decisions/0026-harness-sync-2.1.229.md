# ADR 0026: Harness Sync 2.1.229 — 検証手段の是正と、宣言系統に残るもう 1 つの乖離

- **Status**: Accepted
- **Date**: 2026-08-13
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

前回の harness 同期は [ADR 0023](./0023-harness-sync-2.1.226.md)(2.1.226 / 2026-08-08)。実インストール版は **2.1.229** まで進み、3 パッチ分の差分が蓄積した。`update-check` command による調査(`Explore` を 3 系統に並列委譲し、ローカルキャッシュ `~/.claude/cache/changelog.md` と GitHub raw CHANGELOG の**逐語一致**・npm registry 実測・ローカル実測で一次裏取り)で以下を確定した。確認時刻は 2026-08-13。

- **v2.1.227**: 期限切れログイントークン時にサブスクリプション階層を反映せず feature flag を評価していた問題の修正。`allowed_non_write_users` 付き `claude-code-action` で全 Bash コマンドが失敗する問題の修正。`/tui` が巻き戻された会話を復活させる問題。スラッシュコマンドメニューの表示改善
- **v2.1.228**: 内部レイアウトエラー後に再描画が完全停止する問題。**セッションクリーンアップがプロジェクトの memory フォルダを削除する問題の修正**。**設定マージの是正 — marketplace エントリはエントリ丸ごとでマージされるようになった**。claude.ai から同期された skill の堅牢化(本文中の `!` コマンド実行と `@` ファイル展開を無効化)。**Write ツールの read-before-write 規則の緩和**(新しいモデルは未読ファイルを上書き可、Edit と同基準)
- **v2.1.229**: plugin marketplace の **`command` ソース**追加。`ListAgents` が切断済み Remote Control セッションを `offline`、クラウドセッションを `cloud` とラベル付け。workflow fan-out の兄弟エージェント staggering(`CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS` で無効化可)。**sandbox のネットワークドメインリストで IPv6 リテラルは角括弧必須、曖昧な綴りは fail-closed で強制**。**`/commit-push-pr` が危険フラグ(`--force` / `--amend` / `--no-verify` 等)付きの git/gh を自動承認しなくなった**

ローカル実測で判明した点として、`~/.local/share/claude/versions/` にあるのは 2.1.226 / 2.1.227 / 2.1.229 の 3 つで、**2.1.228 のバイナリはこのマシンに存在しない**(227 → 229 へ飛んで更新された。228 の変更は 229 に内包される)。

MCP / gitleaks / プラグインの実測:

- `@playwright/mcp` 0.0.79、`@modelcontextprotocol/server-sequential-thinking` 2026.7.4、gitleaks 8.30.1 はいずれも**最新のまま**で追従漏れなし
- `chrome-devtools-mcp` のみ 1.6.0 → **1.7.0**(2026-08-10 公開)
- プラグイン 3 件の実インストール版(elements-of-style 1.0.0 / episodic-memory 1.4.2 / superpowers 6.2.0)は `// auditedPluginVersions` と**完全一致**。持ち込み能力(skills / agents / hooks / MCP)も ADR 0023 §3 の棚卸し時点から不変
- `tools/doctor.sh` は 64 checks / warn 0 / error 0

計画は `devil-advocate` の反証を通し、**3 点を修正した**:

1. **検証手段が証明になっていなかった**(最重要 / §2)。当初計画の受動観測は、狙った故障を構造的に検出できないと判明したため全面差し替えた
2. `chrome-devtools-mcp` の pin 更新を**撤回**した(§3)
3. Betterleaks を「判断が必要」という宙吊りのまま提出しようとしていた。`principles/02-decision-recording.md` の「たぶん大丈夫を確認なしで残さない」に反するため決着させた(§7)

運用者確認(2026-08-13): 作業範囲をハーネス同期に限定する / MCP 宣言系統の乖離は記録に留める / Betterleaks は TODO へ転記して次回 / `check-doc-parity` への検査追加は今回行う。

## Decision

### 1. 機械層を 2.1.229 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| [`adapters/claude-code/VERSION`](../../adapters/claude-code/VERSION) | 2.1.226 | **2.1.229** | 実インストール版に一致させる |
| [`adapters/claude-code/README.md`](../../adapters/claude-code/README.md) の前提バージョン散文 | 2.1.226 | **2.1.229** | 同一の事実を持つ 2 つ目の記述(§6 で機械検査化) |

2.1.228 のバイナリが手元に無いまま 229 を pin することについて: pin は「テストした全版の列挙」ではなく「この版を前提に整合を取った」という主張であり、`tools/check-claude-version.sh` は installed と pinned の単一値比較を行う。現に走っているのは 2.1.229 なので、他の値を書くことは WARN を恒久化するだけで意味を持たない。

### 2. hook payload の検証手段を、受動観測から能動負テストへ差し替えた

**当初計画の誤り**。「`tools/loop-report.sh` で当日ログを見て `agent_type` / `spawn_depth` / `model` が空でないことを確認する」としていたが、これは `pre-bash-guard.sh` の回帰確認として証拠能力を持たない。3 段階で崩れる:

- **読んでいる payload が別イベント**: `pre-bash-guard.sh:26` が読むのは **PreToolUse** の `.agent_type`。一方 `loop-report.sh` が読むのは SubagentStop / PostToolUse / PostToolUseFailure の 3 系統だけで、**PreToolUse payload を一度も読まない**。イベントごとに payload スキーマは独立に変わりうる
- **フォールバックが故障を隠す**: `subagent-stop-record.sh:102-103` は payload から `agent_type` が消えても meta.json サイドカーから補填する。「非空であること」を合格条件にした瞬間、検出対象の故障に対して盲目になる。同じことが `model`(transcript 由来)と `spawn_depth`(meta.json 由来)にも当てはまり、**挙げた 3 フィールドはいずれも payload 由来ではなかった**
- **既存テストも payload を検証しない**: `tests/test-pre-bash-guard.sh:41` の payload は合成。緑になるのは hook のパーサが正しいことの証明であって、2.1.229 が `agent_type` を送っている証明ではない

**差し替えた検証と実測結果**(2026-08-13T08:14Z、`Explore` subagent 経由の能動負テスト):

| 観測 | 結果 |
|------|------|
| subagent からの `git push --dry-run` | **deny された**。エラー本文に `agent_type: Explore` が入った |
| `pre-bash-guard.log` | `2026-08-13T08:14:44Z deny subagent push (agent_type: Explore, cmd: git -C ... push --dry-run)` |
| 陰性対照 `git status --short` | 通過(誤検出ではない) |
| 意図的な失敗 `bash -c 'exit 42'` | `failure-log.jsonl` に `{"ts":"2026-08-13T08:14:49Z",...,"exit_code":42,...}` |
| subagent の meta.json | `{"agentType":"Explore","parentAgentId":null,"spawnDepth":1,"model":null}` |

これで ①PreToolUse が subagent の Bash で発火する ②`agent_type` が payload に実在する ③hook のパーサが動く ④deny 判定が 2.1.229 で honor される、の 4 点が**同時に**立つ。`git *` は allow 側(`settings.json.template:109`)なので、deny は hook 以外から来ようがない。

**リスクの非対称性**(反証で追加): 仮に `agent_type` が失われても、subagent push の主防衛は `tools/githooks/pre-push`(ADR 0024 §2a)に移してあるため即座に穴が開くわけではない。`agent_type` はツール層の第一線であって唯一の防衛線ではない。

**副次的な発見**: 検証目的の意図的な失敗が `intent: "real"` として記録された。hook は `intent` を自動判定しないため、`loop-report.sh` の集計に検証由来のノイズが混じる。実害は小さいが、`check-failure-patterns.sh` の 14 日窓に現れる。今回は記録に留める。

### 3. `chrome-devtools-mcp` 1.7.0 は今回上げない

1.7.0 の公開は **2026-08-10 = 3 日前**で、`practices/supply-chain-hygiene.md` の**公開後 7 日ルールに抵触**する。

この規約は当該経路では機械的に守られない: `check-package-age.sh` が見るのは `npm view <pkg> time.created` = パッケージ名の**初**公開日(chrome-devtools-mcp は 2025-05-13)であり、版ごとの公開日ではない。さらに同 hook は `bun add` / `npm add` 等にしか発火せず、`bunx` / `claude mcp add` 経路は通過する(ADR 0023 §4 と同型の空白)。**今回は手動で規約を守った**。次回の update-check で再評価する。

この確認手順を `update-check.md` の MCP 節に明記した。

### 4. MCP 宣言系統に残るもう 1 つの乖離(塞がずに記録する)

実測で 3 つの事実が判明した:

- **`claude mcp list` に `sequential-thinking` / `chrome-devtools` が無い**。opt-in 宣言は `tools/setup-mcp.sh` の実行で初めて登録される設計なので**未登録それ自体は設計どおり**。ただし ADR 0021 の「MCP pin 更新(chrome-devtools 1.6.0 / sequential-thinking 2026.7.4)」は、実機に届いていない宣言を更新していたことになる
- **`tools/setup-mcp.sh:65-68` はサーバー名でしか冪等判定せず、版を見ない**。一度登録した後に template の pin を上げても `claude mcp add` は走らず、実機は古い版のまま動き続ける
- **`tools/doctor.sh:236-247` は `servers.template.json` を `jq empty` の構文チェックにしか掛けていない**。ADR 0023 §7 が `enabledPlugins` に入れた宣言↔実体検査の MCP 版が存在しない

ADR 0023 §1 が `enabledPlugins` で発見した「宣言だけが動き実体が伴わない」形と同型に見えるが、**決定的な差がある**: `enabledPlugins` は「宣言 = 導入されているべき」なので不一致を機械的に WARN できるのに対し、opt-in MCP は**未登録が正常状態**であり、同じ検査を作ると常時 WARN になる。何を異常と定義するかの設計が先に要るため、今回は塞がずに記録し、`update-check.md` の定点観測項目に昇格させた。

`adapters/claude-code/README.md` の影響範囲マップ「MCP server 設定スキーマ」行にも、pin 更新が実機に届かないことを明記した。

### 5. 記録のみ(設定変更を伴わない)

以下は**すべて上流 CHANGELOG 由来であり、当環境での被害・修復いずれも未観測**。ADR 0023 §9 が訂正した「上流の事実を自環境の状態と取り違える」誤記録を避けるため、この粒度で書く。

| 変更 | 当システムへの影響 |
|------|-------------------|
| [228] `extraKnownMarketplaces` のマージ意味論確定(同名エントリは丸ごと置換) | 宣言は user-level 1 層のみ・カスタムヘッダなしのため実挙動は不変 |
| [228] Write ツールの read-before-write 緩和 | 自前の `pre-edit-protect.sh` は独立に効く。`permissions.deny` の Edit ルールも影響を受けない |
| [228] セッションクリーンアップがプロジェクト memory を消すバグの修正 | メモリ層(ADR 0003)に関わる不具合だが、**当環境で被害の観測記録は無い** |
| [228] claude.ai 同期 skill の堅牢化 | 対象は claude.ai から同期された skill のみ。リポジトリ管理下のローカル skill には及ばない |
| [229] sandbox のドメイン表記規則(IPv6 は `[::1]:443`、曖昧な綴りは fail-closed) | template の `sandbox` は `failIfUnavailable` のみで `network` ブロックを持たない |
| [229] `/commit-push-pr` が危険フラグ付き git/gh を自動承認しなくなった | 既存 deny(`git push --force*` / `-f*` / `git commit*--no-verify*` / `git push*--no-verify*`)と同方向。ハーネス側のガードが 1 枚増えた形 |
| [229] `ListAgents` の `offline` / `cloud` ラベル | 観測面の変化のみ。ただし `crossSessionInbound` の再評価トリガーに影響(§8) |

### 6. `tests/check-doc-parity.sh` に VERSION ↔ README 検査を追加した

`adapters/<tool>/VERSION` の pin と、同ディレクトリ README の「現在: `<version>`」という散文の一致を機械検査する。

この対は**過去 2 回ずれた**: ADR 0022 が VERSION を上げて散文を置き去りにし、ADR 0023 が別件の作業中に「VERSION が 2.1.220、README が 2.1.217」という 2 重のズレを発見して手で直した。今回で手作業の是正は 2 回目にあたる。1 つの事実が 2 箇所にあり、どちらもテキストであるという条件は、`check-doc-parity.sh` が扱う drift の定義そのものに合致する。

TDD で追加した(`tests/test-doc-parity.sh` に 4 ケース、pass 21 / fail 0)。設計上の判断:

- **VERSION ファイルを持たない adapter はスキップ**する(`adapters/codex/` は現状 `.gitkeep` のみで pin されていない)
- **pin があるのに散文が無い README は失敗**にする。散文を消すことが赤を消す最短経路になってはならない
- 失敗メッセージは pin と散文の**両方の値**を出す。そうでなければ運用者は 2 ファイルを開いて突き合わせることになる

実装後、VERSION だけを 2.1.229 に上げた状態で検査が実際にズレを捕まえることを確認した(`[ERROR] adapters/claude-code/VERSION pins 2.1.229 but adapters/claude-code/README.md says 現在: 2.1.226`)。

残る 2 つの未検査の対(subagent frontmatter ↔ `subagents/_index.md` の表、skill frontmatter ↔ `skills/_index.md` の表)は今回触らないファイルであり、対象同一性が無いため範囲外とした(§10)。

### 7. Betterleaks の約束を ADR 本文から TODO へ転記した

ADR 0023 §10 は「次回は正式な再評価対象へ格上げ。並行運用の dry-run 比較で false positive 差分を実測して採否を決める」と手順まで書いて約束したが、**今回も着手せず 2 回連続の先送り**になった。

先送りの判断自体は、今回の作業範囲(ハーネス同期)と検証の性質(バイナリの新規取得・config 互換の実地確認・hooks 3 系統 + CI への並行実行)を踏まえれば正当でありうる。問題は**約束の保管場所**にある。ADR 本文の散文は grep されず機械検出もされないため、次回の作業者が能動的に読み返さないかぎり回収されない。これは ADR 0025 が「ADR に未来の実行の約束を書いたが、回収する仕組みと接続されていなかった」と記録した真因と同一。

[`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) 項目 19 として転記し、トリガーを「次回の harness sync で**最初に**着手」と明示、3 回目を送る場合は理由を ADR に書くことを条件にした。ADR 0025 が新設した TODO 転記規約の 2 例目にあたる。

### 8. 定点観測 4 件の再評価

| 項目 | 判断 |
|------|------|
| per-skill 無効化機構(追加されたら superpowers の重複 7 skill を無効化 / ADR 0024 §4) | 227–229 に該当機構の追加なし → **据え置き継続** |
| `sandbox.network.strictAllowlist` | 229 で綴り解釈が fail-closed 化し IPv6 表記が厳格化。粒度の改善方向ではあるが、不採用理由(allowlist 列挙対象の広さ / ADR 0022)は変わらない → **据え置き**。229 の変更を `update-check.md` に追記 |
| `crossSessionInbound` / `dialogExpiry` | 未使用のため **据え置き**。ただし 229 で `ListAgents` が他マシンの Remote Control セッションとクラウドセッションを列挙するようになったため、**複数マシン運用の開始が実質的なトリガー**になると `update-check.md` に明記 |
| Betterleaks の並行運用検証 | §7 のとおり TODO 項目 19 へ転記 |

### 9. 不採用の判断

| 候補 | 判断 | 理由 |
|------|------|------|
| `CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS`(229 新設) | 不採用 | 既定の staggering は同一 prefix の兄弟エージェントがキャッシュを再課金せず読めるようにする挙動。無効化する動機がない。`env` に増やさない |
| plugin marketplace の `command` ソース + `mode: "link"`(229 新設) | 不採用 | ローカルコマンドがプラグインディレクトリを出力し毎セッション再解決される経路。供給網の閉包(ADR 0023 §4)を弱める方向で、現状の 3 プラグインに必要がない |
| `chrome-devtools-mcp` 1.7.0 への pin 更新 | 今回不採用 | 公開 3 日で 7 日ルール抵触(§3)。次回再評価 |
| `setup-mcp.sh` の版追従修正 / `doctor.sh` への MCP 宣言↔実体検査 | 今回不採用 | 記録に留める(§4)。opt-in は未登録が正常状態のため、何を WARN とするかの設計が先に要る |
| `permissions.deny` への `git commit --amend` 追加 | 不採用 | 229 の `/commit-push-pr` 変更で当該経路は塞がった。それ以外の `--amend` は正当な用途があり、deny すると通常の履歴修正まで止まる |

### 10. 影響範囲マップの走査結果(変更なしの行を含む全行)

`adapters/claude-code/README.md` の影響範囲マップを全行走査した。あわせて、同マップ(従来 11 行)と ADR 0021 以降の走査記録(13 行)が乖離していたため、**マップ側に「slash command の frontmatter 仕様」行を追加**して是正した。

| 仕様変更領域 | 走査結果 |
|--------------|----------|
| `permissions.deny` / `allow` の構文 | **変更なし**。227–229 に構文変更の記載なし。229 の `/commit-push-pr` 変更はハーネス側の挙動で、設定構文には影響しない |
| `hooks.<event>` の matcher / フィールド構文 | **変更なし**。`_lib.sh` の `hk_deny` が出す `hookSpecificOutput` JSON が 2.1.229 で受理され続けていることを、§2 の deny 実測と当日の `deny cd` 記録で確認 |
| 利用可能な hook event 種別 | **変更なし**。227–229 で追加・改名・削除いずれもなし。使用中の 9 event はすべて不変 |
| skill の frontmatter 仕様 | **変更なし**。16 skill が `doctor.sh` の frontmatter 検査を通過(warn 0) |
| subagent の frontmatter 仕様 | **変更なし**。8 subagent の `model:` / `effort:` / `tools:` が同検査を通過 |
| slash command の frontmatter 仕様(**本 ADR で追加**) | **変更なし**。同検査を通過 |
| MCP server 設定スキーマ | **スキーマ変更なし**。pin は §3 のとおり据え置き。宣言系統の実機不達を §4 に記録し、マップ本文にも明記 |
| プラグイン管理 | **変更なし**。①3 件とも marketplace に存続 ②宣言 = 実体(`setup-plugins.sh --dry-run` 差分なし)③持ち込み能力は ADR 0023 §3 の棚卸しから不変(superpowers: skills 14 / hooks 4、episodic-memory: skills 1 / agents 1 / hooks 1 / MCP、elements-of-style: skills 1)。228 の marketplace マージ意味論の確定は §5 のとおり実挙動に影響しない |
| attribution / commit・PR 添付情報の構文 | **変更なし**。配置済み settings.json に `{"commit":"","pr":""}` が反映されていることを実測。ただし実挙動の smoke-test は ADR 0018 以来未実施のまま(§11) |
| `~/.claude/` 配下のディレクトリ構造 | **新ディレクトリ 6 件を確認**(`plans/` `sessions/` `teams/` `jobs/` `daemon/` `chrome/`)。いずれも `tools/cleanup-claude-code-runtime.sh` の TARGETS に無く、**削除対象外に倒れている**(fail-safe 側)。ADR 0023 §6 が是正したのは逆向きの欠陥(payload 実体である `plugins/cache` を消していた)であり、今回は同じ罠には嵌まっていない。**TARGETS は変更しない**: `plans/` は plan mode の成果物、`sessions/` は resume 対象で、削除対象への追加は実害が大きい側。逆に TARGETS にあって実在しないもの(`statsig` `todos` `debug` `downloads` `double-shot-latte`)は無害 |
| env 変数(`CLAUDE_CODE_*`) | **変更なし**。設定中の 4 変数(`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` / `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` / `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` / `ENABLE_PROMPT_CACHING_1H`)に廃止・改名なし。新設 1 件は §9 で不採用 |
| デフォルトモデル / effort | **変更なし**。`claude-opus-5[1m]` / `fallbackModel: ["claude-opus-4-8"]` / `effortLevel: "xhigh"` がいずれも 2.1.229 で有効(本セッションが当該設定で稼働)。`settings.machine-overrides.json` に model 系キーが混入していないことも確認(ADR 0022 の再発防止) |

### 11. 今回の範囲外(発見として記録し、次回の起点にする)

- **`settings.json.template:4` / `user-level/CLAUDE.md:83` / `subagents/explorer.md:76` の「Fable 5 期」「Opus 4.8 期」表記**。ADR 0022 で Opus 5 へ移行済みだが散文が追随していない。ただしこれらは「現在は Fable 5 期だ」という**現在形の断定ではなく履歴の連鎖**であり、Opus 5 への追記が欠けているだけで偽ではない。VERSION ↔ README の対(同一の事実を指す 2 つの現在形記述)とは性質が異なるため、運用者が今回の範囲から外した「モデル世代追従」の対象として送る
- **`meta/claude-version-log.md` が ADR 0016(2026-06-10)で止まっている**。単なる追随漏れとして 1 行足せば済む問題ではない: 表題は「モデル利用履歴」で列も日付/モデル/用途/メモなのに、唯一の直近行が記録しているのは**ハーネス同期**であり、ファイルの所掌が曖昧になっている。また `:23` の「単純な実装は Sonnet で十分」は `practices/model-selection.md:44` が自らアンチパターンとして禁じた「推奨モデルを固有銘柄名で書き込む」に該当し、`:24` は完成済みの model-selection.md を「Phase 2 で作成」と未完了扱いのまま。**所掌を決めることが修正の本体**
- **`check-doc-parity.sh` の残り 2 つの未検査の対**(subagent frontmatter ↔ `_index.md`、skill frontmatter ↔ `_index.md`)。今回触らないファイルのため対象同一性が無い
- **`check-doc-parity.sh` の `STALE_PATTERNS` へのモデル世代表記の追加**。世代表記の腐敗は同検査の設計思想に合致するが、文言を直せない今回に追加すると赤になる。「修正 + パターン追加」を次回 1 セッションでまとめる
- **ADR 0018 の smoke-test 宿題**(`attribution: {commit:"", pr:""}` によるセッション URL 抑止が実挙動として効いているかの確認)。設定の反映は確認したが、実コミットでの抑止は未検証のまま

## Consequences

### Positive

- 機械層が実インストール版に追従し、`check-claude-version.sh` の WARN が解消した
- **`agent_type` による subagent push 抑止が 2.1.229 で生きていることを一次証拠で確認した**。ADR 0023 §8 が「唯一の判別手段」と書いた信号について、payload 実在・パーサ動作・deny の honor を同時に立証する検証様式を確立した(合成 payload のテストでは代替できない領域)
- VERSION ↔ README のズレが機械検出されるようになった。過去 2 回人手で見つけた drift クラスが 1 つ閉じた
- Betterleaks の約束が、grep 可能で先送りが可視化される場所へ移った
- 影響範囲マップと走査記録の様式乖離(11 行 vs 13 行)が解消した

### Negative

- **MCP 宣言系統の乖離を塞いでいない**。`setup-mcp.sh` の版非追従は将来 pin を上げたときに黙って実機に届かない経路として残る。opt-in の性質上、単純な宣言↔実体検査は作れないため、設計を次回へ送った
- `chrome-devtools-mcp` の pin が 1 版遅れる。opt-in かつ未登録のため実害はないが、宣言としては古い
- 検証で発生させた意図的な失敗が `intent: "real"` として failure-log に残り、14 日窓の集計にノイズとして現れる
- モデル世代表記の追随漏れ 3 箇所が未修正のまま次回へ持ち越された

### Neutral

- 2.1.228 のバイナリを一度も実行しないまま 229 を pin した。228 の変更は 229 に内包されるため整合するが、「pin した版のすべてを実測した」わけではないことを明示しておく
- `~/.claude/` に増えた 6 ディレクトリは cleanup の対象外に倒れている。掃除されない側に倒れているので実害はないが、`cleanup-claude-code-runtime.sh` の TARGETS が実態を網羅していない状態は続く

## Update(2026-08-13): CI の doctor ジョブを macOS runner へ移した

本 ADR のコミットを push した直後、CI の `doctor` ジョブが失敗した。調査の結果、**本同期が原因ではなく 2026-08-09 の push から継続していた既存の失敗**であることが判明した(`shellcheck` / `secrets-scan` は緑、`doctor` のみ赤)。

### 原因

失敗していた 2 本は、いずれも**このリポジトリが macOS 前提であることに依存したコード**のテストだった:

- `tools/disable-guardrails.sh` / `enable-guardrails.sh` は `tools/_lib.sh` の `cs_require_macos()` を呼び、Darwin 以外では `[ERROR] macOS only (BSD coreutils assumed)` として **設計どおり exit 1 する**。`test-guardrails-dry-run.sh` は最初の `disable --dry-run` で `set -e` に落ち、出力ゼロで終了していた
- `hooks/check-failure-patterns.sh:30` は `date -u -v-"${WINDOW_DAYS}"d ... 2>/dev/null || true` で窓の起点を求める。GNU date は `-v` を拒否し、フォールバックが `date -d` ではなく `true` なので `cutoff` が空になり、以降のフィルタが全滅して hook が何も出力しない(8 assertion が失敗)。テスト側の `ago()` も同じ BSD 前提

Linux コンテナで両方を再現し、`cs_require_macos()` が意図的なガードであること・`check-failure-patterns.sh` が Linux で exit 0 のまま無出力になることを確認した。

顕在化の契機は 2026-08-09 の「CI の重複 lint ステップを削除し、`doctor.sh` に全テストを委譲する」変更。それ以前は CI が個別にテストを列挙しており、この 2 本は走っていなかった。

### 判断

`runs-on` を `ubuntu-latest` から **`macos-latest`** に変更した。リポジトリは PUBLIC のため macOS runner に課金は発生しない。

退けた 2 案:

- **Linux では 2 本を skip する**: CI は高速なままだが、2 本が CI で検証されなくなる。ADR 0024 が「`pre-push` は repo-local なので GitHub がガードを一度も検証していない」という穴を塞ぐために CI ステップを足した経緯と正面から逆行する
- **両 OS で動くようにする**: `cs_require_macos()` は「BSD coreutils を仮定する」という宣言そのものであり、緩めることは `CLAUDE.md` の「macOS BSD コマンド前提(GNU 互換不要)」という方針の変更にあたる。方針を変えるなら独立した ADR が要る問題で、CI を直すついでに行う判断ではない

**方針が macOS 前提である以上、その方針を検証する CI も macOS で走らせるのが唯一の整合的な読み方**だと判断した。`shellcheck` / `secrets-scan` の 2 ジョブは OS 非依存のため `ubuntu-latest` のまま残す。

gitleaks の取得はアセット名を `darwin_${ARCH}` に変え、`uname -m` からアーキテクチャを解決する形にした(runner イメージの Apple silicon 移行を pin で追わないため)。ツール導入は `command -v` で不足分のみ `brew install` する(macOS イメージは jq / shellcheck を同梱するが tree は持たない)。

### 残る限界

macOS runner は起動が遅く、ジョブ全体の実行時間は伸びる。また、この構成は「CI が macOS でしか回らない」ことを意味するので、将来 Linux 環境での利用を想定するなら方針から見直す必要がある。現時点で運用は単一 macOS マシンであり、その前提を CI が正しく反映した状態になった。

## Related

- [ADR 0023](./0023-harness-sync-2.1.226.md) — 前回の同期。§4(供給網の空白)/ §5(受け入れ条件)/ §6(cleanup の欠陥)/ §8(subagent push 禁止)/ §10(Betterleaks の格上げ)を本 ADR が引き継ぐ
- [ADR 0024](./0024-observation-and-restraint-optimization.md) — §2a の git 層 push ガード(本 ADR §2 のリスク非対称性の根拠)
- [ADR 0025](./0025-symlink-switchover-record-and-release-tagging.md) — TODO 転記規約(本 ADR §7 がその 2 例目)
- [ADR 0021](./0021-harness-sync-2.1.217.md) / [ADR 0022](./0022-harness-sync-2.1.220.md) — MCP pin 更新の記録(§4 で実機不達を補足)
- [`meta/TODO-for-v0.2.md`](../TODO-for-v0.2.md) 項目 19 — Betterleaks の並行運用検証
- [`tests/check-doc-parity.sh`](../../tests/check-doc-parity.sh) / [`tests/test-doc-parity.sh`](../../tests/test-doc-parity.sh) — §6 の実装
- [`adapters/claude-code/user-level/commands/update-check.md`](../../adapters/claude-code/user-level/commands/update-check.md) — 定点観測の更新先
- Claude Code CHANGELOG: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
