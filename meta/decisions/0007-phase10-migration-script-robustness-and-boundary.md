# ADR 0007: Phase 10 Migration Script — Robustness and Responsibility Boundary

- **Status**: Accepted
- **凍結**: 2026-09-06 以降編集しない。現行の状態は [`README.md`](./README.md)(決定索引)が表す
- **Date**: 2026-05-04
- **Decider**: プロジェクトオーナー

## Context

Phase 10(2026-05-04 実行)で `tools/migrate/from-claude-settings.sh` を走らせ、`~/.claude/` を旧 `~/ws/claude-settings/` への symlink から claude-system 配下を指す構成へ切り替えた。実行は完了したが、その過程で 2 つの観測が得られた。

1. **再実行可能性の欠落**:
   Step 4(`cp -L -R "$CLAUDE_HOME" "$BACKUP_DIR/dot-claude-resolved"`)が `~/ws/claude-settings/debug/latest` という壊れた symlink(消えた実体を指す dangling link)で `exit 1` し、移行が中断した。手動で当該 symlink を削除してリトライし復旧したが、別マシンで再実行する利用者は同じ罠を踏む。`-L` で symlink を辿るオプションと、claude-settings 側に蓄積していたランタイム由来の dangling link との相性問題で、入力に依存して落ちる脆い設計になっていた。
2. **責務境界の不整合**:
   Step 7 は「`settings.json` は manual placement」と表示するが、`tools/setup.sh:68` で正規手順として案内されている `tools/sync.sh` が `tools/sync.sh:118-134` で template → `~/.claude/settings.json` を自動 `cp` する。結果として settings.json は実際には自動配置される(移行直後の実ファイルが template と byte-perfect 一致していたのが物的証拠)。`from-claude-settings.sh` の文言だけ見ると挙動と矛盾し、後の読者が「どこで cp されたのか」を辿れない。

両者は表面的には別問題に見えるが、**Phase 10 移行スクリプト群の設計上の同じ弱点**から派生している:

- 1 はスクリプトが**自身の入力空間(壊れた symlink)に対して頑健でない**こと、つまり再実行可能性の欠落
- 2 は移行スクリプトと日次同期スクリプトの**責務境界が曖昧**で、片方の文言が他方の挙動を説明できないこと

つまり「**再実行可能性**(任意の起点からスクリプトを安全に走らせ直せること)と **責務境界**(各スクリプトが何を担い、何を担わないかが明文化されていること)」という共通テーマで束ねられる。Phase 10 の経験を 1 ADR で記録するのが、後の別マシン展開や migrate スクリプト改修時の判断材料として最大の価値を持つ。

なお Phase 10 自体は手動リトライで完了済み(2026-05-04 16:25)であり、本 ADR は「次回以降に効く」性質の判断記録である。

## Decision

### 1. 堅牢性方針(再実行可能性)

`tools/migrate/from-claude-settings.sh` を以下の 2 段構えで強化する:

**(a) preflight に dangling symlink 検出を追加**:

- 新規の Step 1.5 として `find "$src_resolved" -type l ! -exec test -e {} \; -print` を実行
- 検出時は一覧を `cs_warn` で表示し、対話環境では `cs_confirm "Delete these dangling symlinks before backup?"` で削除選択を提示
- 削除選択時は `find ... -type l ! -exec test -e {} \; -delete` で除去
- 拒否選択時 / 非対話環境(CI)では警告のみ出して続行(後段の Step 4 堅牢化が拾う)

**(b) Step 4 を `find -print0` ベースの局所関数に置換**:

- `cp -L -R` を捨て、局所関数(`from-claude-settings.sh` 内に定義)で個別判定しながらコピーする
- 振り分け: `dangling symlink` は skip + `cs_warn`、`resolvable symlink` は `cp -L`(従来挙動)、`directory` は mkdir、それ以外は `cp`
- skip 件数を末尾でサマリ表示(0 件なら表示しない)

両方を併用する理由は判断軸の節で述べる。

### 2. 責務境界(各スクリプトが担う領域の確定)

`tools/migrate/from-claude-settings.sh` と `tools/sync.sh` の責務を以下のとおり分離する:

| スクリプト | 担う責務 | 担わない責務 |
|---|---|---|
| `from-claude-settings.sh` | **1 回限りの構造変更**: `~/.claude/` の存在形態(symlink/directory/missing)を判定し、claude-system 配下を指す symlink セットへ切替。永続バックアップを作成 | machine-local 値の配置(API key プレースホルダを含む `settings.json` 等の cp-deploy) |
| `sync.sh` | **再実行可能な値配置**: template の更新を target に反映する `cp-deploy`(symlink 化できないファイル群) | symlink 切替や Phase 10 固有の構造変更 |

この分離に従い、`from-claude-settings.sh` Step 7 の表示を「manual placement」から「次に `tools/sync.sh` を実行する」へ書き換える。settings.json の実 cp は `sync.sh` 側で完結しており、文言を整合させるだけで設計と挙動は一致する。

### 副次的変更

スクリプト冒頭ヘッダコメント、Summary セクションの「Next step」表示も上記責務分離を反映して書き換える(挙動変更なし、文言の整合のみ)。

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|---|---|---|
| **12-(a) preflight のみ採用、Step 4 は `cp -L -R` のまま** | 不採用 | preflight でユーザーが「削除しない」を選んだ場合や、preflight 後に新たな dangling が紛れ込む競合状態で Step 4 が再失敗する。フォールバックなしの設計は再実行可能性を満たさない |
| **12-(b) Step 4 堅牢化のみ採用、preflight は省略** | 不採用 | dangling を黙って skip すると「実は重要な symlink だった」場合にユーザーが気付けない。preflight で人間に明示的判断を渡す層を持つほうが、ADR 0006 の「第一防衛線 = 検出して人間に判断を渡す」の精神と整合 |
| **13-Y(責務集約): `from-claude-settings.sh` 内で settings.json も cp-deploy する** | 不採用 | 移行スクリプトに sync 責務を持ち込むと密結合化する。`from-claude-settings.sh` が `sync.sh` を内部呼び出しするか、`sync.sh` の cp ロジックを複製する必要があり、いずれも将来の保守コストを上げる。`sync.sh` の正規ルートを残しつつ、移行スクリプトはそこへ誘導するだけが最小変更 |
| **13-Z(責務削減): `sync.sh` の cp ロジックを削除し、ユーザーに `cp` を打たせる** | 不採用 | 手順煩雑化、idempotent 性が失われる(初回のみ cp、2 回目以降は手動判定)。`sync.sh` の「target を最新に保つ」責務とも矛盾する |
| **12 と 13 を別 ADR(0007 / 0008)に分割** | 不採用 | 両者は「Phase 10 移行スクリプトの再実行可能性と責務境界」という共通テーマから派生しており、後の読者が「Phase 10 の教訓」を辿るときに 1 ADR にまとまっている方が読みやすい。ADR 0006 が複数の関連変更(`.gitleaks.toml` 簡素化 / `subagent-stop-audit.sh` の env-var 撤去 / プレースホルダ化)を 1 ADR で扱う作法とも一貫 |
| **本 ADR を起票せず、コードコメントだけで残す** | 不採用 | スクリプトの観測可能な挙動が変わる(Step 構成が増える、ユーザー対話が発生する場面が増える、コピー実装の根本変更)。後の読者が「なぜ Step 4 が `find -print0` ベースなのか」「なぜ Step 7 が sync.sh への誘導なのか」を辿れる根拠が必要 |

## Consequences

### Positive

- **再実行可能性の確立**: 別マシンで `from-claude-settings.sh` を再実行する利用者が、同じ dangling symlink で停止する罠を踏まなくなる
- **責務境界の明文化**: 移行スクリプトと日次 sync が何を担い何を担わないかが ADR で固定される。今後の新規スクリプト追加(rollback / re-migrate 等)でも同じ境界線を使える
- **Phase 10 教訓の一体性**: 後の別マシン展開や migrate 改修時に「Phase 10 で何が起きて何を学んだか」を 1 ADR で参照できる
- **対話環境と非対話環境の両立**: preflight が CI / 非 tty では警告のみで続行するため、自動化との互換性も維持

### Negative

- **`from-claude-settings.sh` の総行数が増える**: preflight に Step 1.5 を新設、Step 4 を局所関数化することで 30 行程度の増加。読者の認知負荷は上がるが、各 Step がコメントで意図を述べているため大きな悪化ではない
- **macOS BSD 前提の継続**: `find -print0` は POSIX、`cp -L` は BSD/GNU 共通だが、本リポジトリの「macOS BSD 前提、GNU 互換は仮定しない」方針(ルート CLAUDE.md)を維持するため移植性は広げない
- **対話依存の偏在**: preflight が `cs_confirm` を使うため、`from-claude-settings.sh` は対話前提のスクリプトとして引き続き運用する。完全自動化は別 PR / 別 ADR で扱う

### Neutral

- **Phase 10 自体は完了済み**: 2026-05-04 16:25 の実行で `~/.claude/` は既に新構成に切替済み。本 ADR の改修は次回以降に効く性質
- **`tools/sync.sh` 自体は無修正**: 責務境界の確定は文言上の整合のみで実装は変えない。`sync.sh:118-134` の cp ロジックは正規ルートとして維持
- **ADR 0005(Bootstrap Completion and Deferral)との関係**: ADR 0005 は Phase 10 を rc1 から遅延した経緯。本 ADR は Phase 10 完了後の教訓記録で、上下関係ではなく時系列上の続編

## Related

- [ADR 0005](./0005-bootstrap-completion-and-deferral.md): rc1 リリース候補化と Phase 10 への遅延判断(本 ADR は Phase 10 完了後の続編)
- [`tools/migrate/from-claude-settings.sh`](../../tools/migrate/from-claude-settings.sh) — 本 ADR で改修
- [`tools/sync.sh`](../../tools/sync.sh) — 責務境界の確定対象(無修正)
- [`tools/setup.sh`](../../tools/setup.sh) — Phase 10 後の正規手順案内(末尾)
- [`meta/CHANGELOG.md`](../CHANGELOG.md) — Phase 10 完了記録 + 本 ADR の Phase 10 follow-up 記録
- `meta/TODO-for-v0.2.md` 項目 12, 13 — 本 ADR で消化(末尾の保留判断注記は別途 rc3 仕上げ時に整理)
