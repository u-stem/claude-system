# tests

claude-system 自体の自動テストと lint。テストフレームワークは使わず、すべて bash スクリプトで書く。

各スクリプトは単体で実行でき、成功時 exit 0 / 失敗時 非 0 を返す。

```bash
bash tests/test-pre-bash-guard.sh     # 単体で実行
bash tools/doctor.sh                  # full: lint + 委譲テストを一括実行
```

## 何を守っているか

ガードレールは 6 層ある(ルート [`README.md`](../README.md) の「ガードレールの仕組み」)。各テストがどの層を守るかを示す。

### lint(構造・規約の検証)

| script | 守る対象 |
|--------|----------|
| [`lint-skills.sh`](./lint-skills.sh) | skill の構造(frontmatter / 必須セクション / dir 名と `name` の一致 / description 50 字 / 本文 200 行) |
| [`lint-principles-language.sh`](./lint-principles-language.sh) | 不変層の純粋性。`meta/forbidden-words.txt` の特定ツール用語が `principles/` `practices/` に逆流していないか |
| [`validate-frontmatter.sh`](./validate-frontmatter.sh) | skill / subagent / command の YAML frontmatter 構文 |
| [`check-circular-refs.sh`](./check-circular-refs.sh) | `@<file>` 参照の循環 |
| [`check-doc-parity.sh`](./check-doc-parity.sh) | **ドキュメントと実体の乖離**。スクリプトが索引 README に載っているか / 失効した Phase 表記 / ADR Status の語彙と相互参照 |

### 振る舞いテスト(hooks とツールの実挙動)

| script | 守る対象 | 備考 |
|--------|----------|------|
| [`test-pre-bash-guard.sh`](./test-pre-bash-guard.sh) | 層 2。`--no-verify` / `git push --force` / subagent からの push の deny(ADR 0024) | 35 ケース。実測 2.13s のため fast 層には入れず `githooks/pre-push` で実行 |
| [`test-user-identifier-patterns.sh`](./test-user-identifier-patterns.sh) | 個人識別子パターンの単一ソース性(ADR 0008)。`_lib.sh` と `.gitleaks.toml` の同期 | 0.13s。**唯一 fast 層(毎ターン)で走る** |
| [`test-hooks-lib.sh`](./test-hooks-lib.sh) | hooks 共通ライブラリ `_lib.sh` の出力契約 |  |
| [`test-log-bash-failure.sh`](./test-log-bash-failure.sh) | 層 3。失敗の `failure-log.jsonl` への記録(ADR 0020) |  |
| [`test-check-failure-patterns.sh`](./test-check-failure-patterns.sh) | 層 3。再発検出と SessionStart 通知 |  |
| [`test-subagent-stop-record.sh`](./test-subagent-stop-record.sh) | `subagent-log.jsonl` の記録(ADR 0012 の計測点) |  |
| [`test-subagent-stop-audit.sh`](./test-subagent-stop-audit.sh) | subagent 出力の監査 |  |
| [`test-sync-settings.sh`](./test-sync-settings.sh) | `settings.json` の決定論的レンダリングと overrides のマージ(ADR 0017) | throwaway HOME |
| [`test-guardrails-dry-run.sh`](./test-guardrails-dry-run.sh) | 緊急停止経路(`disable-guardrails.sh` / `enable-guardrails.sh`)の `--dry-run` が副作用を持たないこと | throwaway HOME |
| [`test-doc-parity.sh`](./test-doc-parity.sh) | `check-doc-parity.sh` 自身。**偽陽性がないこと**を最重要ケースとして検証 |  |

## 実行経路

同じテストでも、どこから呼ばれるかで層が違う。

| 経路 | 実行対象 | 定義 |
|------|----------|------|
| Stop hook(毎ターン) | `test-user-identifier-patterns.sh` のみ | `doctor.sh --fast` の `FAST_TESTS` |
| `tools/doctor.sh`(full) | lint 全 5 本 + 振る舞いテスト | `doctor.sh` の委譲リスト |
| `git push` | `test-pre-bash-guard.sh` + `test-user-identifier-patterns.sh` | [`tools/githooks/pre-push`](../tools/githooks/pre-push)(`CS_ALLOW_PUSH=1` 時に先行実行) |
| CI | `doctor.sh` + lint | [`.github/workflows/doctor.yml`](../.github/workflows/doctor.yml) |

fast / full の層分けは [ADR 0024](../meta/decisions/0024-observation-and-restraint-optimization.md) の実測(full 6.73s → fast 0.80s)に基づく。fast に残すのは**実機のドリフト検出**、full に置くのは**コミット前の関心事**という分担。

## 書き方の規約

- `#!/usr/bin/env bash` + `set -euo pipefail`
- テストフレームワークを導入しない。`PASS` / `FAIL` カウンタと `check()` ヘルパで足りる
- 最後に `test-<name>: pass=N fail=M` を出力し、`[[ "$FAIL" -eq 0 ]]` で終える
- **実環境を汚さない**。`~/.claude/` や `~/.claude-system-backups/` を触るテストは `mktemp -d` した throwaway HOME に対して実行する
- `CS_BACKUP_ROOT` は **unset する**(`env -u CS_BACKUP_ROOT HOME="$TMP"`)。`tools/_lib.sh` がこれを export するため、`doctor.sh` 経由で呼ばれると親の実 HOME 由来の値が漏れ込む
- hook のテストは payload JSON を stdin に流し、出力を assert する(`test-check-failure-patterns.sh` が様式のモデル)
- 意図的に失敗させる negative test では `CS_EXPECTED_FAILURE=1` を立て、観測ログを汚さない

## 新しいテストを足したら

`check-doc-parity.sh` が本 README への記載を要求する。加えて `tools/doctor.sh` の委譲リストと `.github/workflows/doctor.yml` の両方に登録すること — `test-pre-bash-guard.sh` は CI に載っておらず、GitHub 側で回帰を検出できない期間が長く続いた。
