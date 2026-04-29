# Integration Trace(Phase 9 シミュレーション)

このドキュメントは Phase 9 検証時点での「セッション起動時に何がロードされるか」を整理した観測ノート。
実プロジェクト 2 件(`kairous`, `sugara`)取り込み完了状態 + Phase 10 切り替え前の前提で記述する。

実機で `claude` を起動して挙動を確認する作業は別途手動で行う。本ファイルは設計上の予測と確認手順を提示する。

---

## 共通前提

- 現状(Phase 0-9): `~/.claude/` は通常のディレクトリ(symlink ではない)で、旧 claude-settings の中身がそのまま展開されている
- 切り替え後(Phase 10): `~/.claude/` 配下の `CLAUDE.md` / `skills` / `hooks` / `commands` / `agents` が claude-system 配下を指す symlink になる(`settings.json` は cp 配置)
- `tools/sync.sh --dry-run` 出力(本ファイル添付の証跡)で計画リンク内容を確認済み

---

## シナリオ A: ホームから `claude` を起動(Phase 0-9 現状)

### 想定挙動

| 読み込まれる対象 | パス(現状) | 役割 |
|---|---|---|
| ユーザーレベル CLAUDE.md | `~/.claude/CLAUDE.md`(旧 claude-settings 由来の 6.5KB 版) | 共通指示 |
| skills | `~/.claude/skills/` 配下(旧資産) | グローバル能力単位 |
| subagents | `~/.claude/agents/` 配下(旧資産) | グローバル補助エージェント |
| hooks | `~/.claude/hooks/` 配下(旧資産) | グローバル hook |
| settings.json | `~/.claude/settings.json`(旧資産) | permissions / env / hooks 結線 |
| auto memory | `~/.claude/projects/<scope>/memory/MEMORY.md` | 構造化知識 |
| episodic-memory | プラグイン管理 | 過去会話セマンティック検索 |

### claude-system からのロード

- なし(まだ symlink が張られていないため、claude-system 配下のファイルは Claude Code から見えない)
- ただし `~/ws/claude-system/CLAUDE.md` 自体は claude-system ディレクトリでセッションを起動した場合のみ読まれる

### 確認方法

```bash
ls -la ~/.claude/
cat ~/.claude/CLAUDE.md | head -5
```

---

## シナリオ B: `~/ws/sugara` で `claude` を起動

### 想定挙動

シナリオ A の項目 + 以下:

| 読み込まれる対象 | パス | 役割 |
|---|---|---|
| プロジェクト CLAUDE.md | `~/ws/sugara/CLAUDE.md` | sugara 固有指示 |
| 共通 fragment(@参照) | `~/ws/claude-system/adapters/claude-code/project-fragments/web-apps-common.md` | Web app 共通指示 |
| ローカル skills | `~/ws/sugara/.claude/skills/` 配下 | sugara 固有 skill(feature-update 等) |
| ローカル hooks | `~/ws/sugara/.claude/hooks/post-edit.sh` 等 | sugara 固有 hook(monorepo + turbo + bun 構成向け) |
| ローカル subagents | `~/ws/sugara/.claude/agents/` 配下(あれば) | sugara 固有 subagent |
| プロジェクト memory | `~/.claude/projects/-Users-mikiya-ws-sugara/memory/` | プロジェクトスコープ auto memory |

### @参照解決の確認

`@~/ws/claude-system/adapters/claude-code/project-fragments/web-apps-common.md` は絶対パス参照。
fragment ファイル自体は claude-system 配下に存在するため、~/.claude/ の symlink 状態に依存しない。Phase 10 切り替え前後で挙動は変わらない。

### 確認方法

```bash
cd ~/ws/sugara
head -3 CLAUDE.md
ls .claude/
test -f ~/ws/claude-system/adapters/claude-code/project-fragments/web-apps-common.md && echo "@参照ターゲット存在 OK"
```

---

## シナリオ C: `~/ws/kairous` で `claude` を起動

### 想定挙動

シナリオ A + 以下:

| 読み込まれる対象 | パス | 役割 |
|---|---|---|
| プロジェクト CLAUDE.md | `~/ws/kairous/CLAUDE.md`(冒頭で fragment を @参照) | kairous 固有指示 |
| 共通 fragment(@参照) | `~/ws/claude-system/adapters/claude-code/project-fragments/web-apps-common.md` | Web app 共通指示 |
| AGENTS.md | `~/ws/kairous/AGENTS.md` | Codex CLI 互換役割定義(Claude Code が直接読むかは不確定、TODO-for-v0.2.md 参照) |
| rules/*.md | `~/ws/kairous/.claude/rules/` 配下 4 ファイル(code-quality / security / testing / workflow) | kairous 固有 rule(共通基盤との重複は意図的に保留中) |
| ローカル skills | `~/ws/kairous/.claude/skills/` 配下(あれば) | kairous 固有 skill |
| プロジェクト memory | `~/.claude/projects/-Users-mikiya-ws-kairous/memory/` | プロジェクトスコープ auto memory |

### kairous 固有の補足

- Phase 8 取り込みは案 Y(`@web-apps-common.md` 追加のみ、`rules/` は無編集)で実施
- `rules/*.md` の重複削除(案 X)は v0.2 検討材料(TODO-for-v0.2.md 参照)
- `AGENTS.md` の扱いも v0.2 で再検討

### 確認方法

```bash
cd ~/ws/kairous
head -3 CLAUDE.md
ls .claude/rules/
test -f AGENTS.md && wc -l AGENTS.md
```

---

## シナリオ D: Phase 10 切り替え後の予測

`tools/migrate/from-claude-settings.sh` 実行後を想定。

### 何が変わるか

| 項目 | 切り替え前(現状) | 切り替え後 |
|---|---|---|
| `~/.claude/CLAUDE.md` | 旧資産の実体ファイル(6.5KB) | claude-system のファイルへの symlink |
| `~/.claude/skills/` | 旧資産の実体ディレクトリ | `claude-system/adapters/claude-code/user-level/skills/` への symlink |
| `~/.claude/hooks/` | 旧資産の実体 | `claude-system/adapters/claude-code/user-level/hooks/` への symlink |
| `~/.claude/commands/` | 旧資産の実体 | `claude-system/adapters/claude-code/user-level/commands/` への symlink |
| `~/.claude/agents/` | 旧資産の実体 | `claude-system/adapters/claude-code/subagents/` への symlink |
| `~/.claude/settings.json` | 旧資産の実体 | 新 settings.json(`settings.json.template` を `cp` 配置 + 手動編集) |
| 旧資産の他ディレクトリ | (`backups/`, `paste-cache/`, `history.jsonl` 等の Claude Code ランタイム生成物が同居) | 切り替え時にバックアップへ退避 → ランタイムは新規生成 |

### 新たに発火する hooks

`settings.json.template` の hooks 結線(claude-system 側)で、以下が初めて Claude Code から呼ばれるようになる:

| hook 種別 | スクリプト | 役割 |
|---|---|---|
| PreToolUse(Bash) | `pre-bash-guard.sh` | `--no-verify` / `git push --force` / `rm -rf ~/.claude` 等の二重防御 |
| PreToolUse(Bash) | `check-package-age.sh` | typosquatting / 侵害バージョン防御(`PACKAGE_MIN_AGE_DAYS=7`) |
| PreToolUse(Edit/Write) | `pre-edit-protect.sh` | `~/ws/claude-settings/` / `*.backup-*` / `.env*` の物理ブロック |
| PostToolUse(Bash) | `log-bash-failure.sh` → `log-failure.sh` | 失敗 JSONL 集計 |
| PostToolUse(Edit/Write) | `post-edit-dispatcher.sh` → `post-edit-validate.sh` | プロジェクト側 `.claude/hooks/post-edit.sh` への委譲 |
| Stop | `post-stop-dispatcher.sh` → `stop-session-doctor.sh` | 失敗ログ未解決時の Stop ブロック |
| SessionStart | `check-failure-patterns.sh` | `failure-log.jsonl` 繰り返し失敗パターン通知 |
| SubagentStop | `subagent-stop-record.sh` / `subagent-stop-audit.sh` | subagent セッション履歴の集計 |

### 何が変わらないか

- principles / practices / adapters のファイル内容(claude-system 側にあり、symlink の有無で変化しない)
- @参照解決(絶対パス参照のため symlink 状態に非依存)
- プロジェクトレベル `.claude/` 配下(プロジェクト内に閉じている)
- auto memory / episodic-memory の場所(ハーネス側で `~/.claude/projects/` に保持)

### Phase 10 切り替え時の手動確認項目

- [ ] `readlink ~/.claude/CLAUDE.md` が claude-system を指す
- [ ] `readlink ~/.claude/skills` が claude-system を指す
- [ ] `readlink ~/.claude/hooks` が claude-system を指す
- [ ] `readlink ~/.claude/commands` が claude-system を指す
- [ ] `readlink ~/.claude/agents` が claude-system を指す
- [ ] `~/.claude/settings.json` が新 template ベース(旧 settings.json はバックアップに退避済み)
- [ ] `tools/doctor.sh` が clean
- [ ] 試しに `git commit --no-verify` を Bash で叩く → permissions.deny で阻止される
- [ ] `~/ws/sugara` で `claude` を起動 → 共通 fragment が読まれる(`@参照` 解決)
- [ ] `~/ws/kairous` で `claude` を起動 → 共通 fragment が読まれる(`@参照` 解決)
- [ ] バックアップ `~/.claude-system-backups/migration-<TIMESTAMP>/` が永続保管されている

---

## sync.sh --dry-run 出力(2026-04-29)

```
==> sync.sh plan (DRY-RUN)
[INFO] CLAUDE_HOME = /Users/mikiya/.claude
[INFO] CS_ROOT     = /Users/mikiya/ws/claude-system
[WARN] Existing /Users/mikiya/.claude/CLAUDE.md will be moved to /Users/mikiya/.claude-system-backups/CLAUDE.md.backup-20260429-170257
[WARN] Existing /Users/mikiya/.claude/skills will be moved to /Users/mikiya/.claude-system-backups/skills.backup-20260429-170257
[WARN] Existing /Users/mikiya/.claude/hooks will be moved to /Users/mikiya/.claude-system-backups/hooks.backup-20260429-170257
[WARN] Existing /Users/mikiya/.claude/commands will be moved to /Users/mikiya/.claude-system-backups/commands.backup-20260429-170257
[WARN] Existing /Users/mikiya/.claude/agents will be moved to /Users/mikiya/.claude-system-backups/agents.backup-20260429-170257

==> settings.json deployment plan
[INFO] settings.json already exists at /Users/mikiya/.claude/settings.json; manual diff/merge required.
[INFO] Phase 10 procedure: review, then cp or merge from /Users/mikiya/ws/claude-system/adapters/claude-code/user-level/settings.json.template

==> Dry-run complete. No changes applied.
```

`migrate/from-claude-settings.sh` はこれと同等の動きを行うが、バックアップは `migration-<TIMESTAMP>/` 配下に集約する点が異なる(永続保管前提)。

---

## doctor.sh 結果(2026-04-29)

```
checks : 38
ok     : 38
warn   : 0
error  : 0
[OK] doctor.sh: clean (warnings: 0)
```

---

## 関連

- [`tools/migrate/from-claude-settings.sh`](../tools/migrate/from-claude-settings.sh)(Phase 9 で配置、Phase 10 で実行)
- [`tools/migrate/rollback-from-claude-system.sh`](../tools/migrate/rollback-from-claude-system.sh)(Phase 9 で配置、緊急時用)
- [`meta/decisions/0005-bootstrap-completion-and-deferral.md`](./decisions/0005-bootstrap-completion-and-deferral.md)
