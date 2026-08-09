# user-level hooks

このディレクトリには Claude Code のグローバル hook 用シェルスクリプトを配置する。
Phase 7b(Guardrails 層)で実装済み。`~/.claude/hooks/` にシンボリックリンクされている。

## 配置場所と役割

- 配置先: `~/ws/claude-system/adapters/claude-code/user-level/hooks/<name>.sh`
- `~/.claude/hooks/` にシンボリックリンクされている
- 実行可能ビット(`chmod +x`)を必ず付ける
- 全スクリプトは `#!/usr/bin/env bash` + `set -euo pipefail` を必須とする(`CLAUDE.md` 絶対ルール)
- 共通ヘルパは [`_lib.sh`](./_lib.sh) を `source` する(入力読み取り `hk_read_input` / 判定出力 `hk_deny` `hk_ask` / ログ `hk_log` 等)

## 実装済み hook 一覧

結線は [`settings.json.template`](../settings.json.template) を参照。各 hook は対象外の入力で早期 `exit 0` する。

| ファイル | hook 種別 | 役割 |
|---------|-----------|------|
| `pre-bash-guard.sh` | PreToolUse(Bash) | `--no-verify` / 破壊的コマンド / `cd` を deny(`cd` は eval 形も正規表現で捕捉。通常形・複合形・subagent は settings.json `permissions.deny` の `Bash(cd)` / `Bash(cd *)` が session 全体でカバー)。加えて **subagent からの `git push` を deny**(payload の `agent_type` で判別、commit と add は許可 / ADR 0024) |
| `check-package-age.sh` | PreToolUse(Bash) | typosquatting / 侵害バージョン防御。`PACKAGE_MIN_AGE_DAYS`(既定 7)以内のパッケージを deny |
| `pre-bash-output-cap.sh` | PreToolUse(Bash) | token 経済(ADR 0012)。test/build/lint の単純コマンドの stdout を `updatedInput` で `tail -n N` にキャップ。stderr と exit code は保持。`CLAUDE_BASH_OUTPUT_CAP`(既定 200、`0` で無効) |
| `pre-edit-protect.sh` | PreToolUse(Edit\|Write) | `claude-settings/` / `*.backup-*` への書き込み阻止 + principles/practices への禁止語混入阻止 |
| `post-edit-validate.sh` | PostToolUse(Edit\|Write) | SKILL.md frontmatter / 禁止語 / ユーザー識別子パス(ADR 0008)の検証 |
| `record-rework-signal.sh` | PostToolUse(Edit\|Write) | 編集されたファイルを `.claude/rework-log.jsonl` に記録するだけ(**計測専用・何もブロックしない**)。同一ファイルの反復編集=手戻りを事後に数えるため。集計は `tools/loop-report.sh --rework` |
| `post-edit-dispatcher.sh` | PostToolUse(Edit\|Write) | プロジェクト側 `.claude/hooks/post-edit.sh` へ委譲 |
| `log-bash-failure.sh` | PostToolUseFailure(Bash) | 終了コード ≠ 0 を category(test/check-types/check)判定して `log-failure.sh` に渡す。**PostToolUse では発火しない**ことが実測で判明し ADR 0020 で移行済み |
| `log-failure.sh` | (補助) | `.claude/failure-log.jsonl` への JSONL 追記 |
| `check-failure-patterns.sh` | SessionStart | `failure-log.jsonl` から繰り返し失敗を検出して通知(自己参照ループの起点) |
| `stop-session-doctor.sh` | Stop | `doctor.sh --fast` を `ulimit -t 10` 付きでバックグラウンド実行し `last-doctor.log` に記録。**セッションを止めることはしない**(ADR 0024) |
| `notify-stop-failure.sh` | StopFailure | parse-error 等でセッションが異常終了したことを通知(ADR 0014 層 A。`StopFailure` の出力はハーネスに無視されるため副作用のみ) |
| `post-stop-dispatcher.sh` | Stop | プロジェクト側 `.claude/hooks/post-stop.sh` へ委譲 |
| `subagent-stop-record.sh` | SubagentStop | `subagent-log.jsonl` への基本記録(委譲量の計測点、ADR 0012) |
| `subagent-stop-audit.sh` | SubagentStop | ADR 0001/0002 サニタイゼーション + tools 越権検知(log-only) |

### post-edit / post-stop dispatcher パターン

- グローバル hook は `if [ -x .claude/hooks/post-edit.sh ]; then .claude/hooks/post-edit.sh; fi` の形式で**プロジェクト側スクリプトに委譲**する
- 言語固有処理(biome / tsc / ruff / mypy / cargo clippy / go vet 等)は `adapters/claude-code/project-templates/` に配置

## 設計指針

- deny / ask は `_lib.sh` の `hk_deny` / `hk_ask`(JSON を stdout に出して `exit 0`)、警告は stderr
- 出力を加工する場合は PreToolUse の `updatedInput`(Claude Code v2.0.10+)を使う。PostToolUse は実行済みの結果を変更できない
- 失敗ログは `${CLAUDE_PROJECT_DIR:-.}/.claude/failure-log.jsonl` に集約しプロジェクト内に閉じる
- macOS BSD コマンド前提(GNU 互換不要、ただし bash は Homebrew 5.x を許容)
- 冪等であること(同じ入力で何度呼んでも同じ結果)
- 緊急停止は [`tools/disable-guardrails.sh`](../../../../tools/disable-guardrails.sh)

## 関連

- [`adapters/claude-code/user-level/settings.json.template`](../settings.json.template) — hook の結線箇所
- [`meta/decisions/0012-token-economy-mechanization.md`](../../../../meta/decisions/0012-token-economy-mechanization.md) — output-cap / 計測の根拠
- [`adapters/claude-code/README.md`](../../README.md)
