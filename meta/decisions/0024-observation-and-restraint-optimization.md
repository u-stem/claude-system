# ADR 0024: 観測と抑止の最適化 — 毎ターン診断のティア化、subagent push の機械的抑止、集計の分離

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-08-09
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

[ADR 0023](./0023-harness-sync-2.1.226.md) の同期作業中および直後に、**測れば分かるのに測っていなかった**ことが 4 件表面化した。運用者の指示(2026-08-09)により 4 領域を実測し、それぞれ採否を決めた。

契機となった最大の事象は、ADR 0023 を執筆している最中に **subagent が 10 コミットを Public な `origin/main` へ自動 push した**ことである(10:27:18〜10:27:52)。ADR 0023 §8 で「バックグラウンドセッションからの push を禁止する」と user-level CLAUDE.md に書いた、まさにそのコミット自身が、その禁止に違反して公開された。指示による抑止が効かないことが同一セッション内で実証された。

## Decision

### 1. `doctor.sh` を fast / full にティア化し、Stop hook は fast を使う

**実測(2026-08-09)**: `doctor.sh` は full で 6.10〜6.73 秒。内訳は委譲テスト 10 本が 3.86 秒(63%)、shellcheck が 1.34 秒(22%)、残りが約 0.9 秒。

- `stop-session-doctor.sh` はこれを**バックグラウンドで**回すため体感レイテンシは増えない。この点で ADR 0023 の security-auditor が挙げた「毎ターン +1.9 秒の遅延」および私自身の当初理解は**誤りだった**(実測で訂正)
- しかし `ulimit -t 10`(CPU 秒)の上限があり、6.10 秒は **61% を消費**していた。超過すると doctor が途中で殺され `last-doctor.log` が**エラーなしに不完全になる**。無音の劣化である
- **判断**: `--fast` を新設し、shellcheck と委譲テストを省く。両者はコミット前の関心事で、CI(`doctor.yml` / `shellcheck.yml`)が既にゲートしている。毎ターンの hook に残すべきは**実機のドリフト検出**(symlink / settings 同期 / プラグイン整合 / 秘密混入)であり、これは fast 層に全て残した
- **効果**: 6.73 秒 → **0.80 秒(88% 削減)**。ulimit 消費は 67% → 8% となり無音切断の失敗モードが実質消滅
- **検証**: fast 層でも settings ドリフトを検出することを、実機 settings を一時改変して WARN 発火を確認(復元済み)。full 60 checks / fast 50 checks

### 2. subagent からの `git push` を機械的に deny する

指示レベルの抑止が実証的に失敗したため、`pre-bash-guard.sh` に移す。principles/06「抑制は最終手段」に照らしても、**指示を試して失敗した後**であれば機械化は最終手段として正当である。

- **判別手段の実測**: SessionStart の `source` は使えない(値は `startup` / `resume` / `clear` / `compact` / `fork` のみで、背景か否かを表さない。公式 doc で確認)。代わりに **PreToolUse payload の `agent_type` / `agent_id` が subagent 呼び出しのときだけ現れる**ことを実測した:

  | 呼び出し元 | payload キー |
  |---|---|
  | メインセッション | `cwd, effort, hook_event_name, permission_mode, prompt_id, session_id, tool_input, tool_name, tool_use_id, transcript_path` |
  | subagent | 上記 + **`agent_id`, `agent_type`**(`agent_type=code-reviewer` を観測) |

- **実装**: `agent_type` が存在し、かつコマンドが `git ... push` にマッチしたら deny。**commit と add は許可したまま**にする(ローカルに commit してあれば作業は失われず、差し止めるのは公開だけ)。メインセッションは `agent_type` を持たないため運用者の push は従来どおり
- **実装の作り直し(2026-08-09、code-reviewer の指摘)**: 初版は単一の正規表現で「`git` の後に `push` が出現するか」を見ていた。これは**両方向に壊れていた**:

  | 入力 | 初版 | あるべき |
  |---|---|---|
  | `/usr/bin/git push` / `command git push` / `env git push` / `sh -c "git push"` | allow | **deny** |
  | `git commit -m 'fix push behavior'` | **deny** | allow |

  後者は「commit は許可する」という本節の保証に正面から反する。"push" はコミットメッセージにありふれた語であり、正常な commit が止まる。**正規表現ではなく解析に置き換えた**: 引用符を空白に潰して単純コマンドへ分割し、環境変数代入とラッパー(`command` / `env` / `nohup` / `sudo` / `xargs` / `sh -c` 等)を剥がして実行プログラムを特定し、`basename` が `git` のときだけ**最初の非オプショントークン**をサブコマンドとして判定する。値を取るグローバルオプション(`-C` / `-c` / `--git-dir` 等)は次のトークンごと読み飛ばす
- **検証**: `tests/test-pre-bash-guard.sh` を 9 → **25 ケース**に拡張(上表の回避形 7 種 / 値付きオプション 3 種 / メッセージ中の "push" 4 種 / メインセッション許可 / commit・add 許可 / `--force` 継続 deny)。実エージェントでも `git push --dry-run` の拒否と回避非試行を確認済み
- **原理的に届かない範囲(正直な記録)**: `G=git; $G push` のような変数間接参照、`git pus\h` のような分割、shell alias は静的解析では解決できない。解決するにはコマンドを実行してみる必要があり、それは PreToolUse hook にできることではない

### 2a. しかしこの層では足りない — 実インシデントはツールを通っていなかった

security-auditor の指摘を受けて transcript を実測したところ、**本 ADR の契機となった 10 コミットは Bash ツールを経由していなかった**ことが確定した。

- インシデント時刻(01:27:18〜01:27:52 UTC)のメインセッション transcript に記録されている tool_use は `Edit` / `bash tools/doctor.sh` / `tools/sync-settings.sh --apply` / `git status` / `git log` / `git fetch` のみで、**`git commit` も `git push` も 1 件も無い**。全期間で `git push` の tool_use は事後に運用者が明示実行した 2 件だけ
- つまりハーネスが git を内部実行しており、**PreToolUse は発火しない**。`agent_type` の判定精度をいくら上げても、この経路は構造的に捕捉できない
- ADR 0023 §8 の「実エージェントで拒否を確認した」は、**型付き subagent が Bash で明示的に push した場合**の検証であって、インシデントの再現ではなかった

**対処: 主防衛を git 自身の層へ移す**。`tools/githooks/pre-push` を新設し、`CS_ALLOW_PUSH=1` が無い push を拒否する(`core.hooksPath` は既に `tools/githooks` を指している)。誰が git を起動しても効く唯一の層である。

- 逃げ道は 1 語(`CS_ALLOW_PUSH=1 git push origin main`)で、対話運用の摩擦はほぼ無い
- `git push --no-verify` は pre-push を丸ごと飛ばすため、`settings.json.template` の `permissions.deny` に `Bash(git push*--no-verify*)` を追加した(従来 deny は commit 側のみで push 側は素通りだった)
- **PreToolUse 層は残す**。置換ではなく多層化する。subagent には即座に理由付きで拒否が返るほうが、git 層で失敗するより早く正しく伝わる
- pre-push はガード自己検査(`test-pre-bash-guard.sh` / `test-user-identifier-patterns.sh`)も実行してから通す。壊れたガードを公開しないための位置として適切で、実測 2.3 秒は push の頻度に対して無視できる
- **限界**: この pre-push は claude-system リポジトリ限定である(`core.hooksPath` はリポジトリローカル設定)。他プロジェクトには効かない
- **残る限界**: 判別できるのは *subagent* であって「バックグラウンドセッション全般」ではない。subagent でない独立した背景セッションが `agent_type` を持つかは未確認で、そこは依然 CLAUDE.md §8 の指示に依存する

### 3. `loop-report.sh` で委譲エージェントとハーネス内部を分離する

**実測**: `subagent-log.jsonl` 313 件のうち、委譲 83 / ハーネス内部(`(internal)`)115 / 旧レコード(agent_type 空)115。**73% がノイズ**だった。集計はこれらを同列に並べていたため、「empty model rate 62%」のような数字が出て計測基盤が壊れているように見えていた。

- **当初の見立ては誤りだった**。「310 件中 71 件が空 = 計測基盤に穴」と報告したが、切り分けると: `agent_type` は 8 月分 56/56 で完全(過去の欠測は修正済み)、`spawn_depth` も 56/56、`exit_code` も 56/56。`model` を欠く 46 件は**すべて `(internal)`** で、これは「メインセッションの transcript から model を誤帰属しない」という設計どおりの意図的な空である
- `parent_agent_id` が 0/313 なのも**正常**。単層委譲が保たれている限り親は存在しない(ADR 0022 §5)
- **判断**: 集計を委譲エージェントのみに絞り、内部・旧レコードは件数だけ表示する。effort 分布を追加(ADR 0013 が必要とする軸)。フィールドの有効期間(model は 2026-06 から、spawn_depth は 2026-07-25 から、agent_type は 2026-08 から完全)をレポート本文に明記し、全期間平均が過小評価になる罠を塞ぐ
- **効果**: 委譲のみの empty model rate は **9.6%**(混在時の見かけ 62% に対して)。分割が網羅的・排他的であること(83+115+115=313)を実測確認
- **副産物**: 単層委譲の受け入れ条件(ADR 0023 §5)を実データで確認できた。**`spawn_depth >= 2` は 0 件**

### 4. 常時コンテキストは削減しない(実測のうえ不採用)

**実測した常時ロード量(合計 26,552 bytes ≒ 6,600 tokens)**:

| 構成要素 | bytes | 比率 |
|---|---|---|
| user-level CLAUDE.md | 10,025 | 38% |
| project CLAUDE.md(本リポジトリ) | 7,261 | 27% |
| superpowers の SessionStart 注入(`using-superpowers/SKILL.md`) | 3,063 | 12% |
| プラグイン skill 記述(16) | 3,045 | 11% |
| 自前 skill 記述(16) | 1,882 | 7% |
| 自前 subagent 記述(8) | 1,276 | 5% |

- ADR 0023 §5 で「skill 記述 1,882 → 4,927 bytes」と記録したが、**superpowers の SessionStart 注入 3,063 bytes を数え落としていた**。プラグインの実際の常時コスト は 6,108 bytes(全体の 23%)であり、注入分は compact のたびに再投入される
- **プラグイン側は削減不能**: 個別 skill を無効化する設定キーは存在しない(`disableBundledSkills` は全 bundled skill の一括無効のみ、`disableSkillShellExecution` は実行抑止であって記述は残る)。削減手段は superpowers 全体を外すことに限られ、これは運用者の導入判断(2026-08-08)と security-auditor の「無条件継続可」判定に反する
- **自前側も削減不能**: 2 つの CLAUDE.md(全体の 65%)に**リテラル重複はゼロ**(25 文字以上の共通行を機械照合)。役割分離(user-level = 全プロジェクト共通の振る舞い / project = 本リポジトリの編集規約)が効いており、削減は governance を削ることと同義になる
- **判断**: 現状維持。6,600 tokens は 1M 窓に対して十分小さく、削減の代償(統制の喪失、または導入判断の反故)が利得を上回る
- **再評価トリガー**: ハーネスが per-skill の無効化機構を追加したら、重複する 7 skill(`test-driven-development` / `verification-before-completion` / `requesting-code-review` / `receiving-code-review` / `writing-skills` / `dispatching-parallel-agents` / `subagent-driven-development`、計 1,244 bytes)を無効化する。`commands/update-check.md` の定点観測に追加した

## Consequences

- **Positive**: 毎ターンの CPU が 88% 減り、無音切断の失敗モードが消えた。指示では止まらなかった push が機械的に止まり、実エージェントで実証済み。集計が委譲ループの実態を映すようになり、ADR 0013 が必要とする model / effort 分布が初めて読める形になった。単層委譲の遵守が実データで確認できた
- **Negative**: doctor の fast 層はテストと shellcheck を見ないため、CI に出すまで検出されない回帰が生じうる(コミット前は full を回す運用に依存)。push 抑止は subagent に限られ、独立した背景セッションには依然として指示レベルの抑止しかない。常時コンテキストはプラグイン導入前より 23% 重いまま据え置かれる
- **Neutral**: `doctor.sh` の checks 数が文脈で変わる(full 60 / fast 50)。過去ログを集計するときはフィールドの有効期間を考慮する必要がある(レポートに明記済み)

## Related

- [ADR 0023](./0023-harness-sync-2.1.226.md) — 本 ADR の契機。§8 に push 事故と機械化の記録
- [ADR 0013](./0013-role-based-effort-modulation.md) — effort 校正(§3 の集計分離が読める形にした対象)
- [ADR 0015](./0015-delegation-chain-and-mandatory-delegation.md) — 単層委譲(§3 で遵守を実データ確認)
- [ADR 0019](./0019-loop-engineering-phased-adoption.md) — 観測ループ(`loop-report.sh` の位置づけ)
- [ADR 0022](./0022-harness-sync-2.1.220.md) — `spawn_depth` / `parent_agent_id` の記録追加
- [`tools/doctor.sh`](../../tools/doctor.sh) — `--fast` ティア
- [`adapters/claude-code/user-level/hooks/pre-bash-guard.sh`](../../adapters/claude-code/user-level/hooks/pre-bash-guard.sh) — subagent push の deny
- [`tests/test-pre-bash-guard.sh`](../../tests/test-pre-bash-guard.sh) — 9 ケースの固定
- [`tools/loop-report.sh`](../../tools/loop-report.sh) — 委譲 / 内部の分離集計
