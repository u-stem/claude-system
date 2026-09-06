# ADR 0023: Harness Sync 2.1.226 — プラグイン宣言と実体の乖離、および供給網の閉包

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-08-08
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

前回の harness 同期は ADR 0022(2.1.220 / 2026-07-25)。実インストール版は **2.1.226** まで進み、6 パッチ分の差分が蓄積した。`update-check` command による調査(`research-summarizer` を 2 系統 × 独立 2 回委譲し、CHANGELOG raw の逐語取得・npm registry 実測・公式 settings doc・ローカル実測で一次裏取り)で以下を確定した。確認時刻は 2026-08-08。

- **v2.1.221**: 背景セッションの既定が「作業保全のため commit して push」に変更。Bash 権限チェックのバイパス修正(zsh の `[[ ]]` 正規表現条件)。`mode: "mask"` sandbox 資格情報マスキング(Linux/WSL 限定、macOS は `deny` にフォールバック)
- **v2.1.222**: PreToolUse auto-allow hook が背景エージェントタスクでツール制限を迂回していたバグの修正。worktree 分離の徹底。subagent の `effort:` 表示バグ修正。Remote Control auto-start を repo-local settings から有効化不可に。**`ultraplan` 廃止**
- **v2.1.223**: Bash 権限バイパス 2 件の修正(コマンドの一部隠蔽、タブ/不可視 Unicode パディング)。`modelOverrides` の未知キー無視を仕様確定。`CLAUDE_CODE_DISABLE_1M_CONTEXT` の対象をネイティブ 1M 窓の全モデルへ拡大。**`/review` を `/code-review` の alias 化**
- **v2.1.224(最大量)**: `crossSessionInbound` / `dialogExpiry` 設定の追加、cross-session `SendMessage`、`archive` プラグインソース(SHA-256 pin 可)、sandbox 資格情報マスキング拡張。**200-subagent/session の spawn 上限を撤廃**(並行数・depth 上限は不変)。sandbox の末尾スラッシュ deny がバイパス可能だったバグの修正
- **v2.1.225**: gateway spend-limit、`claude agents` の workspace trust prompt、cross-session メッセージの放置修正
- **v2.1.226**: **bug fix のみ**(CHANGELOG に個別エントリなし)
- MCP: `@playwright/mcp` が 0.0.78 → **0.0.79**(2026-08-06 公開、registry 実測)。`chrome-devtools-mcp` 1.6.0 / `sequential-thinking` 2026.7.4 は最新のまま。gitleaks 8.30.1 も最新のままでセキュリティ修正なし

あわせて本 ADR は、調査過程で顕在化した**方針と実機の乖離**を主要論点として扱う。ADR 0022 が扱った乖離(設定が方針を静かに上書き)とは**方向が逆**で、今回は**設定が宣言し実機が持っていない**:

- `enabledPlugins` が宣言する 3 プラグインは、**2026-04-26 のブートストラップ以来一度もインストールされていなかった**。`claude plugin list` = "No plugins installed."、`~/.claude/plugins/installed_plugins.json` = `{"version":2,"plugins":{}}`(2026-05-04 以降未更新)、marketplace 未登録で実測確認
- 根因は ADR 0003 の Positive「`settings.json` の `enabledPlugins` で完結し、別途のセットアップが不要」という**事実の誤り**。`enabledPlugins` は宣言にすぎず、導入には `claude plugin marketplace add` + `claude plugin install` が別途必要である
- 結果として ADR 0003 のメモリ 2 層構成は auto memory の 1 層でしか動いておらず、user-level CLAUDE.md §9 の「『前に話した X は?』は episodic-memory」は 3 か月以上**実行不能な指示**だった
- ADR 0021 / 0022 は影響範囲マップに「採用 3 プラグインとも存続(marketplace 自動更新)」と 2 世代にわたり記録していたが、**未インストールなら自動更新も存続確認も起きていない**。上流リポジトリの活発さの調査は正しく、それを自環境の状態と取り違えた誤記録である

計画は devil-advocate の反証レビューを経て大幅に修正した(`crossSessionInbound` 据え置き論拠の差し替え、push ガードを「事前確認」形から禁止形へ、doctor 検査を CLI 呼び出しからファイル読みへ、過去 ADR 訂正と影響範囲マップ全行走査の追加)。プラグイン導入と push ガード方針の 2 判断は運用者確認済み(2026-08-08)。

## Decision

### 1. 機械層を 2.1.226 に同期する

| 対象 | 変更前 | 変更後 | 根拠 |
|------|--------|--------|------|
| `adapters/claude-code/VERSION` | `2.1.220` | `2.1.226` | 実最新版に pin を同期 |
| `adapters/claude-code/README.md` 前提バージョン | `2.1.217` | `2.1.226` | ADR 0022 で VERSION を上げた際の**追随漏れ**を是正(VERSION が 2.1.220、README が 2.1.217 で 2 重にずれていた) |
| `settings.json.template` playwright pin | `0.0.78` | `0.0.79` | registry 実測の最新。削除された非推奨 `--output-mode` は当リポジトリの args(`["-y","@playwright/mcp@<ver>"]`)で不使用のため影響なし。インライン 1 系統のみの登録で二重更新も不要 |
| `settings.json.template` `extraKnownMarketplaces` | なし | superpowers-marketplace | §2 参照 |

### 2. プラグイン 3 件を実導入し、宣言と実体を一致させる

`superpowers` v6.2.0 / `elements-of-style` v1.0.0 / `episodic-memory` v1.4.2 を導入し、`claude plugin list` で 3 件とも `enabled` を確認した。

**`extraKnownMarketplaces` を template 管理下に置く**のが本節の中核判断である。`claude plugin marketplace add` は marketplace 宣言を配置済み `~/.claude/settings.json` に直接書き込むが、このファイルは template ⊕ machine-overrides の決定論的レンダリング成果物(ADR 0017)であり、**template に持たない限り次回 sync で消える**。実測でこれを確認した(`sync-settings.sh --dry-run` が `extraKnownMarketplaces` を削除差分として表示)。放置すれば、本 ADR の template 変更をコミットした瞬間に post-commit hook の自動同期が marketplace 登録を消し、宣言だけが残る元の壊れた状態へ戻っていた。

- 副次的効果として、marketplace 宣言がリポジトリ管理下に入り**別マシンでも再現**される
- `installed_plugins.json` は Claude Code 側の状態ファイルでありリポジトリ管理しない(実体は各マシンのもの)

### 3. 導入で持ち込まれた能力の全列挙

供給網の観点から「何が入ったか」を記録する(ADR 0021 §3 / 0022 §8 の全行記録様式に準じる)。

| プラグイン | hooks | MCP | subagent | skills |
|-----------|-------|-----|----------|--------|
| `episodic-memory` v1.4.2 | `SessionStart(startup\|resume\|clear)` → `node cli/episodic-memory.js sync --background` | `episodic-memory`(ローカル node ラッパー) | `search-conversations` 1 体 | 1 |
| `superpowers` v6.2.0 | `SessionStart(startup\|clear\|compact)` → `hooks/run-hook.cmd session-start` | なし | なし | 14 |
| `elements-of-style` v1.0.0 | なし | なし | なし | 1 |

- payload の実配置は `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>`(`installed_plugins.json` の `installPath` で確認)。§6 と直結する
- subagent が 8 体 → 9 体になった(`search-conversations` が加わる)。委譲先ロスターの変化として記録する
- `gitCommitSha` が `installed_plugins.json` に記録されるため、導入時点の実体は事後検証可能

### 4. 供給網防御に空白が残ることを、塞がずに記録する

導入によって、本リポジトリのガードレール設計に以下の空白が生じた。**今回は塞がない**が、無記録にはしない。

- **`Bash(claude *)` は allow 済み**のため、`claude plugin marketplace add` / `install` は permission prompt なしで通る
- **`check-package-age.sh` は `bun add` / `npm add` / `uv add` / `cargo add` にしか発火しない**。第三者 marketplace からの取得は設計上の対象外で、`practices/supply-chain-hygiene.md` の 7 日クールダウンも typosquat 防御もかからない
- **プラグイン由来の hook は `permissions.deny` の統治外**(hook はツール呼び出しではない)。`sync-settings.sh` のドリフト検査も `doctor.sh` もプラグイン側 hooks を見ない。つまり**セッション毎に実行されるコードの一部が監査対象外**になった

これは「deny は物理ブロック(LLM の自制に頼らない)」という本リポジトリの中核姿勢と正面から衝突する。**閉包が壊れた事実は次回の update-check で必ず再点検する**(`commands/update-check.md` に項目追加済み)。

**外部通信の実態(security-auditor の実測。当初「いずれもローカル実行、外部送信の宣言なし」と書いたのは誤りだった)**:

| プラグイン | 外部通信 |
|---|---|
| `superpowers` v6.2.0 | **なし**(SessionStart hook は `skills/using-superpowers/SKILL.md` を読んで stdout に JSON を出すのみ。ネットワーク送信・資格情報アクセス・ファイル書き込み・外部プロセス起動のいずれもない) |
| `elements-of-style` v1.0.0 | **なし**(hook を持たない) |
| `episodic-memory` v1.4.2 | **3 系統あり**。① Anthropic API(要約サブプロセス、§4a)② HuggingFace CDN(埋め込みモデル `Xenova/bge-small-en-v1.5` の初回取得)③ npm registry(§4a) |

### 4a. `episodic-memory` の統治外経路は 1 段深い(実測)

`cli/mcp-server-wrapper.js` は依存欠落を検知すると plugin dir で `npm install --no-audit --no-fund` を **node の `spawn` で自動実行**する。これは Bash ツールを経由しないため、`permissions.deny` も PreToolUse hook も `check-package-age.sh` も**一切かからない**。§4 が記録した「hook が統治外」よりさらに一段深く、**任意の npm パッケージ取得とネイティブビルドまでが統治外**だった。

- 導入直後は `node_modules` が存在せず、**プラグインは動作していなかった**(`ERR_MODULE_NOT_FOUND`)。`claude plugin list` の `enabled` は導入状態の確認であって動作確認ではない
- 同梱 lockfile が無く、直接依存 8 件はすべて `^` レンジだった
- **対処**: 次回セッション開始時の無監視 install を待たず、監視下で手動 `npm install` を実行し **`package-lock.json` を固定**した。実測結果: 380 パッケージ、**すべて `registry.npmjs.org` 由来**(外部リゾルバなし)、install script を持つのは既知の 7 件(`better-sqlite3` / `esbuild` ×3 / `fsevents` / `onnxruntime-node` / `protobufjs` / `sharp`)。プラグイン更新のたびに再実施が必要
- 要約は `resume: <sessionId>` と実プロジェクトの `cwd` を渡して Claude サブプロセスを無人起動する(`allowedTools` / `permissionMode` / `canUseTool` の明示指定なし)。過去会話に混じる外部由来テキストによる間接プロンプトインジェクションの経路が理屈上開く
- **監視下 `sync` 1 回の実測(2026-08-09)**: 「Generating summaries for 10 conversation(s)」「(13 more need summaries - will process on next sync)」とログに出力され、**1 回あたり 10 会話**という上限がコード読解どおりであることを確認。埋め込みモデルのロードと DB スキーマ移行も同時に走る。処理中に権限プロンプトは一度も出なかった。ただしこれは「サブプロセスがツールを要求しなかった」ことの観測にすぎず、**要求した場合に拒否されるか(claude-agent-sdk の既定ツール可用範囲)は依然として未実証**である

### 4b. 会話索引は全プロジェクト横断を維持し、境界は運用規約で担保する(ADR 0002)

`episodic-memory` は `~/.claude/projects` と `~/.codex/sessions` を**無条件に全件走査**する。除外手段(`CONVERSATION_SEARCH_EXCLUDE_PROJECTS` env / `~/.config/superpowers/conversation-index/exclude.txt`)は既定で未設定であり、実測時点で会話アーカイブは **687MB / 18 プロジェクト分**、索引 DB は 96MB あった(旧環境由来のデータを含む)。

つまり Public な claude-system のセッションから、MCP `search` と `search-conversations` subagent 経由で **Private プロジェクトの会話本文を検索・引用できる**。ADR 0002 が禁じるのは Public 成果物への Private リンク・具体名であって検索そのものではないが、その材料が常時 1 コマンドで手元に来る状態になる。

- **判断**: 索引範囲は**全プロジェクト横断を維持する**(過去会話の検索性を優先。運用者確認済み 2026-08-08)。機械的な除外は行わない
- **代償の担保**: user-level CLAUDE.md §2(出力衛生)に「episodic-memory の検索結果を Public 成果物へ転記しない」を明記した。ADR 0002 の情報源レイヤと同じ規律を、新しい参照経路にも適用する
- **正直な記録**: これは機械的強制ではなく規約による担保である。principles/06「抑制は最終手段」に整合する選択だが、違反は事後検出もできない。境界侵犯が実際に起きたら exclude.txt による機械的除外へ切り替える

### 5. `superpowers` の skill 競合は受け入れ条件付きで受容する

`superpowers` は 14 skill を持ち込み、うち複数が本リポジトリの確立済み規約と重複する。

| 持ち込み skill | 競合先 |
|---|---|
| `dispatching-parallel-agents` / `subagent-driven-development` | **単層委譲規約**(ADR 0015 / 0022 §5)。再委譲を誘発しうる |
| `test-driven-development` | user-level CLAUDE.md §5 の TDD 規約、自前 `testing-typescript` / `testing-python` |
| `verification-before-completion` | user-level CLAUDE.md §1 完了報告フォーマット |
| `requesting-code-review` / `receiving-code-review` | 自前 `/review` / `/review-loop` / `code-reviewer` subagent |
| `writing-skills` | 自前 `skill-creation` skill |

- **コンテキスト増分の実測**: skill の frontmatter(常時ロードされる name + description)は superpowers が 2,448 bytes / 14 件、episodic-memory 334 / elements-of-style 263。合計 3,045 bytes で、自前 16 skill の 1,882 bytes を上回る。ADR 0021 §4 が Frontend Design プラグインを「コンテキスト消費増のコストが先行」として不採用にした基準を、既存宣言にも同じく適用するための数値である。skill 本体は段階的開示のため常時ロードされない
- **受け入れ条件**: 導入後しばらく `tools/loop-report.sh` で **`spawn_depth >= 2` が 0 件**であることを確認する(ADR 0022 §5 で `subagent-stop-record.sh` が `parent_agent_id` / `spawn_depth` を記録済み)。発生していれば、`enabledPlugins` から `superpowers` を落とすか ADR 0015 を改訂するかを選ぶ
- **正直な記録**: 上記は本 ADR 時点で**未観測**である。3 件同時導入のため、問題発生時の切り分けは skill 単位ではなくプラグイン単位になる

### 6. 自前ツールがプラグインを消す欠陥を是正する

`tools/cleanup-claude-code-runtime.sh` の削除対象に `plugins/cache` が含まれ、help は「plugins/ は触らない(cache サブディレクトリのみ)」と安全であるかのように記載していた。しかし §3 のとおり**プラグイン payload はまさに `plugins/cache/` 配下に存在する**。放置すれば、このツールを一度実行した時点で今回の是正が自前ツールによって巻き戻り、「宣言のみ」状態が再発していた。

- TARGETS から `plugins/cache` を削除し、削除しない理由をコード側コメントと `--help` の両方に実測日付付きで明記した
- キャッシュという名前に反して破棄不能である、という反直感的な事実そのものが記録対象である

### 7. 再発を機械検出し、導線を作る

- **`tools/doctor.sh`**: 「template で `true` 宣言されたプラグインが `installed_plugins.json` に存在するか」を検査する。設計上の制約を 3 つ課した:
  - **`claude` CLI を呼ばない**。`doctor.sh` は Stop hook から毎ターン走るため、CLI 呼び出しは marketplace 更新やネットワーク待ちを毎ターン誘発する。判定はファイル読みのみ
  - **片方向**(宣言 → 未インストールのみ WARN)。逆方向は一時的な試用のたびに鳴るため検査しない
  - **スキーマガード**。`installed_plugins.json` は非公開スキーマのため、`version` が既知値(`2`)でなければ検査をスキップして WARN する。`~/.claude` 未配備マシン・CI では既存慣行に倣い informational で抜ける
  - 検出側・非検出側・スキーマガードの 3 方向を実測確認済み
- **`tools/setup-plugins.sh`**(新設): template の `extraKnownMarketplaces` / `enabledPlugins` を**読むだけ**の冪等スクリプト。宣言源は template 1 箇所に保つ(`setup-mcp.sh` と同型)。`--dry-run` 対応
- **導線**: `meta/multi-device-setup.md` に手順 5 を新設、`tools/setup.sh` の Next steps と help に追記、`tools/README.md` に登録。**`setup.sh` から自動実行はしない**(`setup-mcp.sh` と同じく、ネットワークに出る操作は明示的な別ステップとする)。スクリプトを作っても導線がなければ二度目の死蔵になるため、この 3 点はセットで行う

### 8. バックグラウンドセッションからの `git push` を禁止する

v2.1.221 の既定変更(背景セッションは作業保全のため commit して push する)に対し、user-level CLAUDE.md §8 に**禁止形**で追記した。

- **禁止形にした理由**: §6-2 は既に「不可逆・外向き操作のみ事前確認」と規定しており、「push は事前確認を要する」は増分ゼロの再掲にすぎない。加えて背景セッションには確認する相手がおらず、非対話文脈で「事前確認」は実行不能な指示になる(無視されるか停止する)。§8 は全て「〜しない」形の禁止列挙であり、禁止形が節の性質とも整合する
- 抑止したいのは push そのものではなく「作業保全という理由づけによる例外」であるため、「commit までに留める。ローカルに commit してあれば作業は失われない」と代替行動まで書いた
- **Update(2026-08-09): 指示だけでは効かないことが実証され、機械化した**
  - 本 ADR を書いた同じセッション中に、**subagent が 10 コミットを Public な `origin/main` へ自動 push した**(10:27:18〜10:27:52)。運用者も私も指示していない。皮肉にも、この禁止規約を追加したコミット自身がその禁止に違反して公開された。CLAUDE.md への記述は subagent の挙動を止められないことが実証的に確定した
  - **判別手段の実測**: SessionStart の `source` は使えない(値は `startup` / `resume` / `clear` / `compact` / `fork` のみで、背景か否かを表さない)。代わりに **PreToolUse payload の `agent_type` / `agent_id` が subagent 呼び出しのときだけ現れる**ことを実測確認した。メインセッションは `[cwd, effort, hook_event_name, permission_mode, prompt_id, session_id, tool_input, tool_name, tool_use_id, transcript_path]`、subagent はこれに `agent_id` + `agent_type` が加わる(`agent_type=code-reviewer` を観測)
  - **実装**: `pre-bash-guard.sh` が「`agent_type` が存在 かつ コマンドが `git ... push`」を deny する。commit と add は許可したまま(ローカルに commit してあれば作業は失われず、公開だけを差し止める)。メインセッションは `agent_type` を持たないため影響を受けない
  - **検証**: `tests/test-pre-bash-guard.sh` で 9 ケースを固定し、実エージェントでも `git push --dry-run` の拒否を確認した
  - **訂正(2026-08-09、code-reviewer の指摘)**: 上記の「実証済み」は**ハッピーパス 1 本のみの検証**であり、過大な表現だった。初版の正規表現は両方向に欠陥があった — `/usr/bin/git push` / `command git push` / `env git push` / `sh -c "git push"` を**素通しし**、逆に `git commit -m 'fix push behavior'` を**誤って deny** していた(「commit は許可」という本節の保証に正面から反する)。実装をサブコマンド解析方式に置き換え、25 ケースで固定し直した。詳細は [ADR 0024](./0024-observation-and-restraint-optimization.md) §2
- **残る限界(2026-08-09 の再調査で本質的な穴が判明)**: 判別できるのは *subagent* であって「バックグラウンドセッション全般」ではない。それ以上に重要なのは、**本節の契機となった 10 コミット自体が Bash ツールを経由していなかった**ことが transcript の実測で確定した点である(当該時刻の tool_use に `git commit` / `git push` が 1 件も無い)。PreToolUse はツール呼び出しにしか発火しないため、**この経路は構造的に捕捉できない**。主防衛は `tools/githooks/pre-push` へ移した([ADR 0024](./0024-observation-and-restraint-optimization.md) §2a)。本節のガードは早期フィードバック層として残す
- **注意点(実測)**: 導入した marketplace のクローン `~/.claude/plugins/marketplaces/superpowers-marketplace/.claude/settings.local.json` は `Bash(git push)` / `Bash(git commit:*)` / `Bash(python3:*)` を allow する project-level 設定を同梱している。cwd がそのディレクトリのときにしか読まれないため通常運用では無効だが、本節の方針と字面が衝突する。**当該ディレクトリを作業 cwd にしない**

### 9. 過去 ADR の誤記録を訂正する

ADR 0022 §4 が ADR 0016 の誤帰属を明示訂正した様式を踏襲する。訂正しなければ次回の update-check が同じ行を素通しするため、該当箇所に直接注記した。

- `ADR 0021` の Context「marketplace 経由の自動更新のため設定変更不要」および影響範囲マップ「enabledPlugins: 採用 3 プラグインとも存続(marketplace 自動更新)」
- `ADR 0022` の影響範囲マップ 同上の行
- `ADR 0003` に Update 節を追加(Positive「セットアップ不要」が偽であったこと、Negative の Transformers.js ロード時間が現行世代で未計測であること)

### 10. 不採用の判断

| 候補 | 判断 | 理由 |
|------|------|------|
| `crossSessionInbound`(2.1.224) | 据え置き、定点観測化 | **セッション間メッセージングを使う運用が現状ない**。また既定は「両セッションの permission-mode クラスから毎回判断」という動的挙動で、その決定表を本リポジトリは保有していない。使用開始を再評価トリガーとし、その時点で `accept` / `refuse` を明示決定する。<br>※ 当初案は「`hold` は `dialogExpiry` 失効でメッセージが drop されるため、ADR 0022 の strictAllowlist 不採用と同型」としていたが、反証レビューで**論理が成立しない**と判明し撤回した。strictAllowlist の主因は列挙対象の広さとメンテコストであり、enum 1 値の本設定とはコスト構造を共有しない。また `hold` の欠点で `accept` / `refuse` まで退けるのは 3 択のうち 1 択の欠点を全体に及ぼす誤り。ADR 0022 §4 が訂正した「表層の類似による論理の借用」を繰り返すところだった |
| `dialogExpiry`(2.1.224) | 既定 `5m` を維持 | 上記に同じ(使用開始時に併せて判断) |
| sandbox 資格情報マスキング拡張(2.1.221 / 2.1.224) | 不採用 | macOS では file masking が `deny` にフォールバックし、拡張オプションは `network.tlsTerminate` が前提。個人 macOS 環境では前提が成立しない |
| `strictKnownMarketplaces` / `blockedMarketplaces` の owner wildcard(2.1.223) | 対象外 | managed settings 専用。個人環境に managed settings は存在しない |
| `archive` プラグインソース + SHA-256 pin(2.1.224) | 記録のみ | 現在の 3 プラグインは github marketplace 経由。zip 配布のプラグインを採る場合は SHA-256 pin を必須とする(§4 の空白を部分的に埋める手段になりうる) |
| 200-subagent spawn cap 撤廃(2.1.224) | 記録のみ | 撤廃されたのは**セッション総数**の上限で、単層委譲規約が依拠する depth 上限と並行数上限は不変 |
| `/review` の `/code-review` alias 化(2.1.223) | 記録のみ | 自前 `/review`(指定ファイルの簡易レビュー)が built-in を shadow し従来動作を維持する。本セッションの skill 解決で自前定義が採用されていることを確認。ただし**上流で `/review` が別の意味を持った**ため、`/code-review` を使いたい場合は明示的にそう打つ必要がある |
| `ultraplan` 廃止(2.1.222) | 対応不要 | リポジトリ内に参照ゼロ(grep 確認) |
| `CLAUDE_CODE_DISABLE_1M_CONTEXT` の対象拡大(2.1.223) | 対応不要 | shell 環境・template・実機 settings のいずれにも未設定を実測確認。主モデル `claude-opus-5[1m]` の 1M 窓は影響を受けない |
| `modelOverrides` / managed-settings 系(2.1.223) | 対象外 | リポジトリ内に参照ゼロ(grep 確認) |
| Betterleaks 乗り換え | 据え置き、ただし**次回は正式な再評価対象へ格上げ** | gitleaks 8.30.1 にセキュリティ修正がなく追随の緊急性はない。一方 Betterleaks は v1.7.3 / 週次リリース / 原作者主導 / `.pre-commit-hooks.yaml` 同梱 / 旧 config 互換の明記まで揃い、ADR 0021 の「若いため見送り」の前提は変化した。次回は当リポジトリの `.gitleaks.toml` + Phase 7b hooks + CI に対する並行運用検証(false positive 差分の実測)を行う |
| self-hosted-runner / gateway spend-limit / `ANTHROPIC_BEDROCK_REGION_PREFIX`(2.1.224-225) | 対象外 | Team/Enterprise 機能、gateway・Bedrock 不使用 |
| feedback-survey の model settings アップロード(2.1.224) | 記録のみ(運用注意) | 同意ベースかつ secret は redact されるが、**同意すると system prompt(= CLAUDE.md の内容)が送信される**。Public な claude-system の CLAUDE.md 自体は公開情報だが、Private プロジェクトの project-level CLAUDE.md が含まれうる点を運用者が認識しておく(ADR 0002) |

### 11. 影響範囲マップの走査結果(変更なし行を含む全行記録)

| 領域 | 結果 |
|------|------|
| permissions 構文 | 変更なし。ただし 2.1.221 / 2.1.223 で Bash 権限チェックのバイパス 3 件(zsh `[[ ]]`、コマンド一部隠蔽、タブ/不可視 Unicode パディング)が修正された。**本リポジトリの deny 群が依拠する前提が上流で強化された**形で、追随作業は不要だが VERSION を現行に保つ動機になる |
| hooks matcher / フィールド構文 | 変更なし。2.1.222 で PreToolUse auto-allow hook が背景エージェントタスク(要約 / compaction / rename)でツール制限を迂回していたバグが修正された。自前 hook 群の実効性が上がる方向で、設定変更不要 |
| hook event 種別 | 新設・廃止なし |
| skill frontmatter 仕様 | 変更なし。2.1.221 の「プラグインの `skills` パスに `"."` を受理」はプラグイン作成側の話で該当なし。2.1.222 の `disable-model-invocation` 拒否メッセージ改善は当該フィールド未使用のため影響なし |
| subagent frontmatter 仕様 | 変更なし。2.1.222 の「spinner の effort ラベルが subagent 自身の `effort:` を表示するよう修正」は、**per-subagent `effort:` が honor されている外部裏付け**となる(ADR 0013 Update 2026-06-05 の実測と整合)。**プラグイン由来で `search-conversations` が 1 体追加**(§3) |
| MCP server 設定スキーマ | スキーマ変更なし。pin 更新のみ(§1)。**プラグイン由来で `episodic-memory` MCP が 1 件追加**(§3、自前 2 系統の登録経路の外) |
| enabledPlugins | **要対応 → 対応済み**(§2)。宣言のみで 3 か月以上未導入だった。過去 2 ADR の当該行は誤記録として訂正(§9) |
| attribution 構文 | 変更なし |
| `~/.claude/` ディレクトリ構造 | **変更あり**。`plugins/` 配下に `cache/`(payload 実体)/ `marketplaces/` / `known_marketplaces.json` / `.last_inuse_sweep` が新設された。自前 cleanup ツールとの衝突を §6 で是正 |
| env 変数 | 廃止・改名なし。新設 `ANTHROPIC_BEDROCK_REGION_PREFIX` / `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT` はいずれも不使用。`CLAUDE_CODE_DISABLE_1M_CONTEXT` は未設定を実測確認 |
| デフォルトモデル / effort | 変更なし。ADR 0022 で確定した `claude-opus-5[1m]` / `xhigh` / fallback Opus 4.8 を維持。2.1.221 の「effort `xhigh`/`max` かつ thinking 無効時の WebSearch 400 エラー」修正は、xhigh 運用では常時 thinking のため元々該当しない |
| slash command | `/review` が上流で `/code-review` の alias になった(§10)。自前 `/review` が shadow して従来動作を維持 |
| プラグイン管理(`enabledPlugins`)| 上記 enabledPlugins 行に統合 |

## Consequences

- **Positive**: 3 か月以上「宣言のみ」だったプラグイン層が実体を得て、ADR 0003 のメモリ 2 層構成が初めて実効化した。乖離は `doctor.sh` の WARN で再発が機械検出され、`setup-plugins.sh` + 導線 3 点で別マシンでも再現される。`extraKnownMarketplaces` の template 管理化により、自動同期が marketplace 登録を消す経路を塞いだ。自前 cleanup ツールがプラグインを消す欠陥を、実害が出る前に実測で発見・是正した。過去 2 世代の ADR の誤記録を訂正し、同じ行が次回も素通しされる経路を断った
- **Negative**: 第三者プラグインの導入により、**セッション毎に実行される hook の一部が `permissions.deny` と自前 hook 群の監査閉包の外に出た**(§4)。`episodic-memory` に至っては node の `spawn` 経由で任意の npm 取得とネイティブビルドまでが統治外だった(§4a。lockfile 固定で当面は封じたが、プラグイン更新のたびに再発する)。供給網防御(`check-package-age.sh`)も marketplace 経由の取得には及ばない。全プロジェクト横断の会話索引により Private→Public の参照経路ができ、境界は機械強制ではなく規約でしか担保していない(§4b)。`superpowers` の 14 skill には単層委譲規約や自前 skill と競合するものが含まれ、規約が静かに破れる経路が増えた。これらの受け入れ条件(`spawn_depth >= 2` の非発生)は**本 ADR 時点で未観測**である。背景セッションの push 禁止も、CLAUDE.md の指示がハーネス既定を上書きできるかを実測しておらず実効性は未検証
- **Neutral**: subagent が 8 体 → 9 体、常時ロードされる skill 記述が約 1,882 bytes → 約 4,927 bytes に増えた。委譲先の選定と `subagent-log.jsonl` の集計はこの前提で読む。3 件を同時導入したため、問題が起きた際の切り分け単位は skill ではなくプラグインになる。`installed_plugins.json` の `gitCommitSha` により導入時点の実体は事後検証可能

## Related

- [ADR 0003](./0003-memory-architecture.md) — メモリ 2 層構成(本 ADR で「セットアップ不要」の誤りを Update 訂正)
- [ADR 0013](./0013-role-based-effort-modulation.md) — per-subagent `effort:`(2.1.222 の修正が honor を外部裏付け)
- [ADR 0015](./0015-delegation-chain-and-mandatory-delegation.md) — 単層委譲規約(§5 の受け入れ条件の対象)
- [ADR 0017](./0017-settings-auto-sync.md) — 決定論的レンダリング(§2 の `extraKnownMarketplaces` 判断の根拠)
- [ADR 0021](./0021-harness-sync-2.1.217.md) — 前回同期(enabledPlugins 行を §9 で訂正)
- [ADR 0022](./0022-harness-sync-2.1.220.md) — 前回同期(誤記録訂正の様式を踏襲、enabledPlugins 行を §9 で訂正)
- [`tools/setup-plugins.sh`](../../tools/setup-plugins.sh) — 宣言を読むだけの冪等導入スクリプト(新設)
- [`tools/doctor.sh`](../../tools/doctor.sh) — 宣言 vs 実インストールの片方向検査
- [`tools/cleanup-claude-code-runtime.sh`](../../tools/cleanup-claude-code-runtime.sh) — `plugins/cache` を削除対象から除外
- 外部: [Claude Code CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) / [settings リファレンス](https://code.claude.com/docs/en/settings)
