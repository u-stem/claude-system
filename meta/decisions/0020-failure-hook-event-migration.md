# ADR 0020: failure 記録 hook の PostToolUseFailure 移行と観測ループの実効化

- **Status**: Accepted
- **Date**: 2026-07-11
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## Context

初回レトロ(2026-07)は「`failure-log.jsonl` がどのプロジェクトにも存在しない = 記録→検出のループは配備以来一度も発火していない」を検出し、原因候補を ①記録対象の失敗が実際に発生していない ②カテゴリ判定条件がマッチしていない、の 2 通りと整理していた。今回の切り分けで、**どちらでもない第 3 の原因**が実測で確定した:

- **Claude Code は失敗したツール呼び出しで PostToolUse を発火しない**。本セッションで意図的に exit 1 の Bash を実行し、hook に仕込んだ payload 捕獲が失敗コマンドでは一切呼ばれないことを確認した。現行 v2.1.206 には失敗専用の **PostToolUseFailure** イベントが存在する(公式 hooks doc: PostToolUse = ツール成功後 / PostToolUseFailure = ツール失敗後)
- 仮に発火しても旧実装は `.tool_result.exitCode` を参照しており、実 payload と二重に不整合だった。つまり記録段は構造的にゼロ件しか生めない設計だった(hook 個々の単体動作ではなく「イベントモデルとの接続」が壊れていた)

さらに payload スキーマが情報源ごとに **3 様に食い違う**ことも実測で確定した:

| 情報源 | 結果の場所 | exit code |
|--------|-----------|-----------|
| 公式 docs(PostToolUseFailure) | `.tool_output` | `.tool_output.exit_code` |
| 実測: PostToolUse(成功時) | `.tool_response`(stdout / stderr / interrupted 等) | **キー自体が無い** |
| 実測: PostToolUseFailure(v2.1.206) | **結果オブジェクト自体が無い**。トップレベル `.error` 文字列(先頭行 "Exit code N" + stderr 内容)と `.is_interrupt` | `.error` 先頭行のテキストのみ |

あわせて、ADR 0019 実装後に残っていた観測ループの欠落 2 点(subagent-audit ログが集計対象外 / アーカイブが生 mkdir+mv の手動頼み)も本件で同時に閉じる。

## Decision

### 1. `log-bash-failure.sh` のバインドを PostToolUseFailure(Bash) へ移行する

- `settings.json.template` の PostToolUse(Bash) エントリを削除し、PostToolUseFailure(Bash) に付け替える(live へは `tools/sync-settings.sh --apply` で反映済み)
- `adapters/claude-code/VERSION` を 2.1.197 → **2.1.206** に更新(PostToolUseFailure はこのバージョンで実測確認。前提バージョンの明示)

### 2. payload 解析は実測 3 形を防御的に多重参照する

- 結果オブジェクトは `.tool_output // .tool_response // .tool_result // {}` の優先順
- exit code は結果オブジェクトの `.exit_code // .exitCode`、取れなければ `.error` 先頭行の "Exit code N" からテキスト抽出
- 中断ゲートは結果オブジェクトの `.interrupted` とトップレベル `.is_interrupt` の両方(ユーザー中断は記録しない)
- 旧 PostToolUse で呼ばれた場合のゲート(exit≠0 のときのみ記録)は防御的に残置
- docs と実測の食い違いは hook ヘッダコメントに明記し、`tests/test-log-bash-failure.sh`(7 ケース)で 3 形すべてを固定する

### 3. 記録スキーマを additive 拡張する(cmd は redaction 後に記録)

`{ts, category, error}` に `exit_code`(数値、取れなければ null)と `cmd`(先頭 200 文字)を追加。既存読み手(`check-failure-patterns.sh` / `loop-report.sh`)は `.category` / `.error` 参照のため互換。過去レコードの遡及補正はしない(ADR 0012 の前進記録のみ方針を踏襲)。

`cmd` はコマンドラインに含まれ得る秘匿値(API キー・トークン・パスワード)を平文永続化する新規経路になる(セキュリティ監査 Medium 指摘)ため、記録前に代表的秘匿パターン(`api_key/token/password/secret/bearer` 系の値部、`sk-*` / `ghp_*` / `github_pat_*`)を `[REDACTED]` へベストエフォート置換してから書き込む。

### 4. `loop-report.sh` に subagent-audit 集計セクションを追加する

`subagent-audit.jsonl` はプロジェクト別ではなく `$CS_BACKUP_ROOT/hook-logs/` の**マシン全体 1 本の共有ログ**である(実態)。集計もこの実態に合わせ、プロジェクトループ外の独立セクション(総件数 / kind 別 / 直近 5 件、`--since` のみ適用)とする。プロジェクトスコープ化は必要が生じたら記録側(`subagent-stop-audit.sh`)の設計変更として別途判断する。

### 5. アーカイブを `tools/archive-failure-log.sh` に道具化する(自動化境界は不変)

- `--project` / `--all` / `--dry-run` / `--month YYYY-MM` / `--help`。同月アーカイブ既存時は **append**(計測の連続性を壊さない)、冪等
- ADR 0019 §5 の自動化境界は変更しない: hook は通知のみ、アーカイブの**実行は人間の明示起動**。`check-failure-patterns.sh` の促し文面を生 mkdir+mv からヘルパー案内に変更
- 定期自動実行(cron / 常駐)は導入しない(TODO-for-v0.2 項目 10 のトリガー成立前。ADR 0009 のオプトイン原則)

### 6. hook の e2e 検証様式を確立する

hook のイベント接続はユニットテストでは検証できない(今回の欠陥はまさに接続層だった)。settings 変更を伴う hook 改修時は、**入れ子の headless セッション**(捨てプロジェクト cwd で `claude -p`)で実発火を確認する。本件では失敗コマンド実行 → `failure-log.jsonl` に `{category: "test", exit_code: 1, ...}` の 1 件が記録されることを確認した。

## Alternatives Considered(見送った選択肢)

| 案 | 見送り理由 |
|----|-----------|
| docs 記載の `.tool_output` のみに合わせる | 実測 payload に存在せず、また動かない実装になる。実測を最優先し docs 形はフォールバックとして保持 |
| 実測形(`.error` / `.is_interrupt`)のみに合わせる | docs との食い違いはどちらかが将来収束する可能性が高く、片張りは再破損リスク。多重参照のコストは軽微 |
| Stop hook で transcript を走査して失敗を抽出 | 専用イベントが存在する以上、間接観測は複雑さに見合わない |
| アーカイブの自動実行(SessionStart で mv) | ADR 0019 §5 の自動化境界違反。ログ操作の副作用を hook に持たせない原則を維持 |
| audit ログのプロジェクト別分割 | 記録側の設計変更が必要で本件の範囲外。集計を実態(マシン全体 1 本)に合わせる方が嘘がない |

## Consequences

- **Positive**: 記録段が配備以来初めて実効化し、記録→検出→集計→レトロの観測ループが全段機能する。レトロ 2026-07 の未切り分け(①/②)が第 3 の原因の発見で解消。監査ログが月次レトロで消費可能になり、アーカイブの実行摩擦が下がる。exit_code / cmd の追加で再発分析の材料が厚くなる
- **Negative**: PostToolUseFailure は v2.1.206 前提で、旧バージョン環境では記録されない(VERSION で明示)。payload スキーマは docs と実測が食い違ったままで、harness 更新での再破損リスクが残る(テスト + e2e 様式で検出可能にした)。ゼロ件だった過去期間の失敗データは遡及不能。`cmd` の redaction はベストエフォートであり網羅的でない — この hook は user-level で全プロジェクトの `<project>/.claude/failure-log.jsonl` に書き込むため、`.claude/` をコミットする運用のプロジェクトでは `failure-log.jsonl` を gitignore すること(本リポの `.gitleaks.toml` は `.claude/` を allowlist しており最後の防御網が効かない点も受容済みの残余リスク)
- **Neutral**: 旧 PostToolUse ゲートは防御残置(どの環境でも害はない)。レトロ 3 ヶ月クロック(ADR 0019 §6)や principles 07 の再訪条件は本件で変更しない

## Related

- [ADR 0009](./0009-opus-48-autonomy-tuning.md) — 自動実行のオプトイン原則(§5 で維持)
- [ADR 0012](./0012-token-economy-mechanization.md) — 計測点の位置づけ、前進記録のみ方針(§3 で踏襲)。同 ADR Update と同型の「hook がハーネス仕様と接続できていなかった」事例
- [ADR 0018](./0018-harness-sync-2.1.197.md) — 前回の harness 同期(VERSION 更新の先例)
- [ADR 0019](./0019-loop-engineering-phased-adoption.md) — ループの 5 段と自動化境界(§4 / §5 の前提)。同 ADR Consequences が挙げた「アーカイブ手動頼み」リスクへの部分対処
- [`adapters/claude-code/user-level/hooks/log-bash-failure.sh`](../../adapters/claude-code/user-level/hooks/log-bash-failure.sh) — 本体
- [`tools/archive-failure-log.sh`](../../tools/archive-failure-log.sh) / [`tools/loop-report.sh`](../../tools/loop-report.sh) — 道具側
- [`tests/test-log-bash-failure.sh`](../../tests/test-log-bash-failure.sh) — 3 形 payload の固定
- [`meta/retrospectives/2026-07.md`](../retrospectives/2026-07.md) — 未切り分け問題の出所(追補済み)
