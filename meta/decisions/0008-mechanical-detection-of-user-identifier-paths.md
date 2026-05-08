# ADR 0008: Mechanical Detection of User-Identifier Paths

- **Status**: Accepted
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

## Related

- [ADR 0001](./0001-anonymity-policy.md): Anonymity Policy(本 ADR は本ポリシーの絶対パス側面の実装)
- [ADR 0006](./0006-no-user-identifiers-in-system.md): No User Identifiers Inside the System(本 ADR は本規範の機械担保層)
- [ADR 0007](./0007-phase10-migration-script-robustness-and-boundary.md): Phase 10 Migration Script(本 ADR の起票契機 — レビューで literal 混入が発見された)
- [`adapters/claude-code/user-level/hooks/post-edit-validate.sh`](../../adapters/claude-code/user-level/hooks/post-edit-validate.sh) — 本 ADR で warn 層を実装
- [`.gitleaks.toml`](../../.gitleaks.toml) — 本 ADR で block 層を実装
- [`meta/CHANGELOG.md`](../CHANGELOG.md) — Phase 10 follow-up 2 で本 ADR の実装を記録
- `meta/TODO-for-v0.2.md` 項目 14 — 本 ADR で消化(項目 9 multi-OS 対応時に検出パターン拡張を再判断)
