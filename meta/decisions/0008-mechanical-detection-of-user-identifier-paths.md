# ADR 0008: Mechanical Detection of User-Identifier Paths

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-05-04
- **Decider**: プロジェクトオーナー

## Context

ADR 0006 で「user identifiers literal(本名 / personal email / GitHub handle / 絶対パス内のユーザー名)を tree に書かない」を第一防衛線として確定し、`.gitleaks.toml` の paths allowlist と `subagent-stop-audit.sh` の env-var 除外を撤廃して規範ベースの運用に整理した。しかし ADR 0006 が確立したのは**規範**であり、それを担保する**機械検出**は絶対パス系について空白のまま残っていた。

ADR 0007 起票プロセスのレビューで、CHANGELOG の初稿に `/Users/<name>/ws/claude-settings` という絶対パス literal が混入していたことが手動 grep で発見された。これは「規範の第一防衛線が、ヒューマンレビューでしか担保されていなかった」という事実の表面化である。既存の機械検出を点検すると:

- `pre-edit-protect.sh`: 編集 fragment しか見ないため、既存ファイル全体への混入は検出できない
- `post-edit-validate.sh`: `principles/` `practices/` 配下の forbidden-words(特定ツール用語)のみ
- `subagent-stop-audit.sh`: email 形と claude-settings / private repo 文字列のみ
- `.gitleaks.toml`: API key / token のデフォルトルールに依存、`/Users/<name>/` 形のユーザー識別子は対象外

つまり「規範はあるが検出が無い」状態が ADR 0006 採択以来 1 週間続いており、ADR 0007 起票時に偶然見つかったが、次回も同じ運に頼れる保証は無い。ADR 0006 の第一防衛線(規範)に、第二防衛線(機械検出)を補強する必要がある。

### 自己整合性の要請

本 ADR は「絶対パスでユーザー識別子を漏らすな」という原則の機械的実装を定義する性質上、その**実装定義 ADR 自身がユーザー識別子 literal を含むのは自己撞着**である。原則の宣言と実装の双方が同じ規範を満たさなければ、規範自体が「例外あり」として弱体化する。本 ADR の本文と関連実装は、規範と実装の自己整合性を保つことを設計目標に含める。

## Decision

### 1. 二段階防衛(編集段階 + commit 段階)

ユーザー識別子パスの混入を、編集時刻と commit 時刻の 2 段階で検出する:

| 段階 | 検出器 | レベル | 役割 |
|---|---|---|---|
| 編集時 | `post-edit-validate.sh` | **warn** | 早期気付き。誤検出時の操作性を優先(`hk_warn` で stderr に警告のみ、blocking しない) |
| commit 時 | `.gitleaks.toml` custom rule | **block** | 最終防衛。誤検出よりも漏洩防止を優先(gitleaks の標準 block 動作) |

warn / block を 1 段に統一せず分けるのは、編集中の試行錯誤(プレースホルダで書き直す等)を妨げず、しかし commit に進む段階では確実に止めるため。

### 2. 検出パターン

両検出器とも以下の正規表現で検出する:

```
/Users/[a-zA-Z0-9._-]+/
```

macOS の home directory 規約 `/Users/<username>/...` の冒頭 2 セグメントを捕捉する。`/Users/` の直後 1 文字目から末尾の `/` までを username とみなす。

### 3. 自己参照回避は paths allowlist で対処

検出パターン自身が `/Users/` literal を含むため、検出器が自身の定義ファイルを編集 / スキャン対象に含めると false-positive を起こす。これを **paths allowlist** で個別除外する:

- `post-edit-validate.sh` 側: 編集対象 path が `adapters/claude-code/user-level/hooks/` 配下にある場合は本検出をスキップ(他の検出 — SKILL.md / forbidden-words — は走る)
- `.gitleaks.toml` 側: 既存 `[allowlist].paths` 配列に `adapters/claude-code/user-level/hooks/.*` を追記して統合する(新規 allowlist ブロックは作らない)

検出パターン定義の literal が必要な場所は **`hooks/` ディレクトリと `.gitleaks.toml` 自身に限定**される。本 ADR や CHANGELOG では `<name>` プレースホルダで記述し、allowlist の対象に含めない。

### 4. ADR 0006 自身の例外節は改訂しない

ADR 0006 の例外節(LICENSE Copyright holder / URL 内の自動参照 / 明示プレースホルダ)は GitHub handle / personal email を対象とする規定であって、絶対パス内ユーザー名はそもそも例外節の射程外である。よって ADR 0006 自身は無修正のまま、本 ADR が空白を埋める階層化として位置づく。これは ADR 0007 で「ADR 0006 自身の改訂は禁じ手」として確定した方針との一貫性を保つ。

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|---|---|---|
| **block 統一(両検出器とも block)** | 不採用 | 編集中の試行錯誤を阻害する。プレースホルダへの書き換え途中で commit していなくても block されると、開発のリズムが崩れる。warn → block の二段階のほうが実用的 |
| **warn 統一(両検出器とも warn)** | 不採用 | gitleaks は CI / pre-commit hook で block する前提で運用されており、warn だけでは「最終防衛」として機能しない。ADR 0006 の規範を実効化する要件と矛盾 |
| **検出パターンを文字列分割で literal 回避**(`'/Us' + 'ers/'` のような動的構築) | 不採用 | 可読性が悪化する。grep / regex の標準的な記述から逸脱した hack で、後の保守者が「なぜこんな書き方なのか」を辿れない。paths allowlist による解決のほうが意図が明示的 |
| **`forbidden-words.txt` に `/Users/` を追記** | 不採用 | `forbidden-words.txt` は principles / practices 層に特定ツール用語が混入することを防ぐ専用機構で、検出範囲も `*/principles/*|*/practices/*` に限定されている。ユーザー識別子検出は範囲も用途も異なる責務であり、混在させると両機構の意図が曖昧になる |
| **ADR 0006 自身を改訂して「絶対パス内ユーザー名」を例外節に追加** | 不採用 | ADR 0007 で「ADR 0006 自身の改訂は禁じ手」として確定済み。例外節に追加するのではなく、ADR 0006 の規範を維持したまま検出層で空白を埋めるのが筋 |
| **本 ADR を起票せず、コードコメントだけで残す** | 不採用 | 機械的ガードレールの新設(hooks 拡張 + gitleaks custom rule 追加)は ADR 起票の典型条件(`meta/decisions/README.md` の起票タイミング条項)に該当する。後の読者が「なぜ `/Users/` 検出があるのか」「なぜ二段階なのか」を辿れる根拠が必要 |

### 脚注: 自己参照型検出器の一般原則について

「検出器が自身の定義ファイルを引っかける」問題は本 ADR の局所事象を超えた一般問題でもある。例えば将来別種の検出器(言語別の禁止トークン検出など)を増やすときも同じ構図が再現する可能性がある。今回はスコープ拡大を避け、本 ADR では「paths allowlist で個別対処」という具体策に留める。同種の問題が複数の検出器で再現するようになった時点で、別 ADR として「自己参照型検出器の設計原則」を起票する選択肢を残しておく。

## Consequences

### Positive

- **ADR 0006 の物理的担保**: 規範のみだった第一防衛線に、編集段階の早期警告(warn)と commit 段階の最終 block の二層が付く。次回の literal 混入が偶然の手動 grep に頼らず検出される
- **自己整合性の確立**: 規範を定める ADR(0006)、ADR 起票の禁じ手を確定する ADR(0007)、規範を機械的に担保する ADR(0008)が一体として「絶対パスのユーザー識別子は出さない」という単一の方針を支える構造になる
- **誤検出時の操作性**: 編集時は warn のみで blocking しないため、プレースホルダへの書き換え途中で開発リズムを崩さない。最終 commit 時のみ確実に止める
- **既存 allowlist との統合**: gitleaks 側の allowlist は既存ブロックの paths 配列を拡張するだけで済むため、設定全体の見通しを悪化させない

### Negative

- **OS 依存性(将来の multi-OS 対応時に拡張が必要)**: 検出パターン `/Users/[a-zA-Z0-9._-]+/` は macOS の home directory 規約に依存する。Linux(`/home/<name>/`)や Windows WSL(`/mnt/c/Users/<name>/`)は形式が異なるため、`meta/TODO-for-v0.2.md` 項目 9(マシン横断のメモリ同期)等で multi-OS 展開が現実化した時点で検出パターンの拡張が必要になる。本 ADR スコープでは macOS 前提(ADR 0007 の運用前提と整合)で実装し、先回り導入は避ける
- **paths allowlist の追加が必要**: `hooks/` ディレクトリ全体を gitleaks の paths allowlist に追加することで、当該ディレクトリ内の API key / token 等の混入も同時にスキップされる。これは現実問題ではない(hook スクリプトは API key を扱わない設計)が、allowlist の射程を広げる方向の変更ではある
- **post-edit-validate.sh の責務追加**: 既存の SKILL.md / forbidden-words 検出に加えて第三の検出器を抱え込むことで、hook の単一責務性は弱まる。同 hook 内の path-skip ロジックも検出種別ごとに分岐する形になり、検出器が増えるとさらに肥大化する。将来 hook 分割の検討タイミングが来る可能性を抱える

### Neutral

- **検出パターンの厳密性**: `/Users/[a-zA-Z0-9._-]+/` は macOS username の慣習(英数字 + 一部記号)を前提とした近似で、絶対網羅ではない。例えば日本語 username(macOS 上で技術的には可能)は捕捉しない。実用範囲では十分だが「完璧な検出」ではないことを明記しておく
- **ADR 0007 との関係**: ADR 0007 が `from-claude-settings.sh` の堅牢性と責務境界を扱った Phase 10 follow-up 1、本 ADR は ADR 0006 の機械担保を扱う Phase 10 follow-up 2 という時系列の続編関係。両者の決定領域は重ならない
- **既存 hook 構成の拡張**: 本 ADR の実装は post-edit-validate.sh への追記のみで、新規 hook ファイルは作らない。settings.json.template の hook 結線も変更不要

## Update (2026-08-09): 平坦化パス形式の検出漏れを塞いだ

本 ADR の `user-identifier-path` ルールは `/Users/<name>/` というスラッシュ区切りの絶対パスだけを見ていた。しかし **Claude Code はプロジェクトパスをセッションディレクトリ名へ平坦化する際、スラッシュをすべてハイフンに置換する**(`/Users/<name>/ws/<proj>` → `-Users-<name>-ws-<proj>`)。この形式は同じ username を含みながらスラッシュを持たないため、ルールに一度もマッチしなかった。

- `meta/integration-trace.md` の 2 行にこの形式の username literal が **2026-04-29 のブートストラップから 2026-08-09 まで残存**し、その間のすべての gitleaks 実行(hooks / CI / doctor)を通過していた。ADR 0006 違反が 3 か月以上、機械検出をすり抜けていたことになる
- 発見は偶然だった。ADR 0024 の作業で push 前に `gitleaks detect --source .`(**git 履歴モード**)を回したところ 14 件が出た。従来の運用は `--no-git`(作業ツリーのみ)で、そちらは 0 件のままだった。履歴モードが拾ったのは古いコミットに残る `/Users/<name>/` 形式で、それを追う過程で作業ツリー側の平坦化形式に行き当たった
- **対処**: `user-identifier-flattened-path` ルールを新設(`-Users-[a-zA-Z0-9._]+-`)。`<user>` / `<name>` / `${USER}` のプレースホルダは rule-level allowlist で除外する。検出側・非検出側の両方を実測確認した。該当 2 行は `-Users-<user>-ws-<proj>` に置換した
- **残る事実**: 履歴に残る混入は消せない(Public リポジトリで既に公開済み)。書き換えるには公開履歴の rewrite が必要で、代償が見合わないため**現状を受容し記録に留める**
- **教訓**: 「パターンで捕まえる」防御は、**同じ情報の別表現**に弱い。ADR 0006 のような規範を機械化するときは、対象データが取りうる表現形を列挙したか自問する。username の表現形は少なくとも 3 つある(`/Users/<name>/`、`-Users-<name>-`、`~<name>/`)

### 2 層の実効スコープを明確化した(グローバル性の実測)

本 ADR は warn / block の 2 層を定めたが、**両者のスコープが違う**ことを明示していなかった。実測結果:

| 層 | 実体 | スコープ | 実態 |
|---|---|---|---|
| warn | `post-edit-validate.sh` | **全プロジェクト**(user-level hook として `~/.claude/hooks/` に symlink) | 唯一グローバルに効く層。非ブロッキング |
| block | `.gitleaks.toml` | **claude-system のみ**(リポジトリローカル) | しかも `tools/githooks` に pre-commit は無く、実質 CI 専用 |

`~/ws` の 12 リポジトリのうち `.gitleaks.toml` を持つのは 2 つだけで、残りには commit 時の検出が**存在しない**。つまり claude-system 以外のプロジェクトを守っているのは warn 層ただ 1 つであり、**その唯一の層に平坦化形式の穴が空いていた**のが今回の実害だった。

- **対処**: パターンを `hooks/_lib.sh` の `HK_USER_IDENTIFIER_PATTERNS` に**単一ソース化**し、warn 層は `hk_scan_user_identifiers` を呼ぶだけにした。`.gitleaks.toml` は shell を source できないため定義を重複して持つが、`tests/test-user-identifier-patterns.sh` が**両者の一致を機械的に検証**する(片方から 1 パターン落とすと 3 件失敗することを実測確認)。今回の乖離を生んだ「2 箇所に手書き」という構造そのものを潰した
- **不採用**: グローバル `core.hooksPath` による全リポジトリの commit フック化。**各リポジトリの `.git/hooks/` を無効化してしまう**(husky / lefthook が壊れる)副作用が大きく、代償が見合わない
- **不採用(現時点)**: `pre-bash-guard.sh` による commit 時のグローバル block。user-level hook なので副作用なくグローバル化でき、次点の候補。**採る場合は逃げ道を設けず常に deny する**方針が確認済み(2026-08-09)。今回は warn 層の穴を塞ぐことを優先し見送った

### 末尾位置の取りこぼしを塞いだ(14 ケースの実測)

上記の是正直後、**両パターンとも「末尾に区切り文字が無い username」を取りこぼす**ことが分かった。旧パターンは `/Users/<name>/` と `-Users-<name>-` のように**末尾の区切りを必須**にしていたため、以下が MISS だった:

| 入力 | 旧 flat | 旧 slash |
|---|---|---|
| `/Users/<name>`(文末) | MISS | **MISS** |
| `-Users-<name>`(文末) | **MISS** | MISS |
| `/Users/<na-me>`(文末) | MISS | **MISS** |

「ホームは `/Users/<name>`」のような**散文の書き方がそのまま穴**になる。ドキュメントを主成分とする本リポジトリでは現実的な形である。

- **修正**: 両パターンから末尾区切りの要求を外し、文字クラスを `[a-zA-Z0-9._-]` に対称化した(`/Users/[a-zA-Z0-9._-]+` / `-Users-[a-zA-Z0-9._-]+`)
- **ハイフン入り username について**: 当初「文字クラスに `-` が無いため取りこぼす」と疑ったが、**実測では誤り**だった。`-Users-<na-me>-ws-proj` は最初のハイフンでマッチするため旧パターンでも検出できていた。ただし非対称なクラスは次の読み手に誤解を与えるため揃えた
- **誤検知の確認**: 広げた結果として `the /Users directory` / `/Users/`(名前なし)/ `UsersGuide` / `$HOME/ws/proj` / プレースホルダ 2 種がいずれも MISS であることを実測。gitleaks の作業ツリー走査も引き続き 0 件
- **副産物 1**: この修正で `_lib.sh` だけ先に直したところ、`tests/test-user-identifier-patterns.sh` が**実運用で 4 件の不一致を検出**した。同期テストが合成ケースではなく実際の片側修正を捕まえたことになり、機構が意図どおり働くことが確認できた
- **副産物 2(想定外の波及)**: パターンを広げた結果、**本 Update 自身と CHANGELOG の説明文が自己検出された**。「取りこぼしていた入力例」を実名形式で書いたためである。ドキュメント側を allowlist に足すと盲点が広がるので、例をすべて `<name>` プレースホルダに書き換えた。これは Decision §3 が定めた「本 ADR や CHANGELOG では `<name>` プレースホルダで記述し、allowlist の対象に含めない」という方針が、**パターンを広げたことで初めて機械的に強制された**ということでもある。今後 username の実例を文書に書くことはできない

## Related

- [ADR 0024](./0024-observation-and-restraint-optimization.md): 本 Update の発見契機(push 前検証で履歴モードを回した)
- [ADR 0001](./0001-anonymity-policy.md): Anonymity Policy(本 ADR は本ポリシーの絶対パス側面の実装)
- [ADR 0006](./0006-no-user-identifiers-in-system.md): No User Identifiers Inside the System(本 ADR は本規範の機械担保層)
- [ADR 0007](./0007-phase10-migration-script-robustness-and-boundary.md): Phase 10 Migration Script(本 ADR の起票契機 — レビューで literal 混入が発見された)
- [`adapters/claude-code/user-level/hooks/post-edit-validate.sh`](../../adapters/claude-code/user-level/hooks/post-edit-validate.sh) — 本 ADR で warn 層を実装
- [`.gitleaks.toml`](../../.gitleaks.toml) — 本 ADR で block 層を実装
- [`meta/CHANGELOG.md`](../CHANGELOG.md) — Phase 10 follow-up 2 で本 ADR の実装を記録
- `meta/TODO-for-v0.2.md` 項目 14 — 本 ADR で消化(項目 9 multi-OS 対応時に検出パターン拡張を再判断)
