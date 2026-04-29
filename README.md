# claude-system

Mikiya 個人の AI 協働開発メタリポジトリ。
全プロジェクト(Web app / ボードゲーム / ライブラリ等)に対して統一的かつ高パフォーマンスな開発体験を提供する。

> このリポジトリは「汎用テンプレート」ではない。Mikiya 個人の作業環境(macOS + zsh + bun/uv + Claude Code)を前提に最適化されている。Public 公開しているのは透明性とロールバック容易性のためで、外部利用は想定していない。

---

## 設計思想

| 思想 | 意味 |
|------|------|
| **層構造** | principles(不変) → practices(抽象) → adapters(ツール固有) → projects(個別) |
| **抽象と具体の分離** | ツールが変わっても principles 層は不変 |
| **段階的開示** | 必要なときに必要な情報だけロード(コンテキスト経済) |
| **既存資産の保護** | 既存プロジェクトの暗黙知を破壊しない(取り込みは案 Y ベース) |
| **機械的防御の優先** | 自制に頼らず機械で防げるものは機械で防ぐ(permissions / hooks / CI) |
| **冪等性** | スクリプトは何度実行しても安全 |
| **可観測性** | 何をやったか必ず記録する(CHANGELOG / ADR / 失敗ログ) |

---

## ディレクトリ構成

| パス | 役割 | 詳細 |
|------|------|------|
| [`principles/`](./principles/README.md) | 不変の根本原則(ツール非依存) | 7 ファイル / 5 年後も成立する原則のみ |
| [`practices/`](./practices/README.md) | 抽象的な実践パターン | 14 ファイル / トリガー・手順・判断基準を整理 |
| [`adapters/claude-code/`](./adapters/claude-code/README.md) | Claude Code 固有の翻訳層 | skills / subagents / hooks / commands / fragments / templates |
| [`adapters/codex/`](./adapters/codex/) | OpenAI Codex CLI 用の枠(将来) | 現状プレースホルダ |
| `projects/` | プロジェクト個別の統合情報 | gitignore 対象、中身は Private |
| [`tools/`](./tools/README.md) | セットアップ・同期・診断スクリプト | 全スクリプト bash + `set -euo pipefail` + 冪等 |
| [`tests/`](./tests/README.md) | システム自体の自動テスト | 禁止語検出 / frontmatter 検証 / 循環参照検出 |
| [`meta/`](./meta/README.md) | 変更履歴・ADR・用語集・運用マニュアル | CHANGELOG / decisions / retrospectives |
| `.github/workflows/` | CI(`doctor` / `secrets-scan` / `shellcheck`) | push 毎に直近 3 ワークフロー実行 |

---

## クイックスタート

新マシン上での初回セットアップ手順。

### 前提

- macOS(Apple Silicon または Intel)
- Homebrew(`bash` 5.x / `gh` / `gitleaks` / `shellcheck` / `jq` / `tree` 推奨)
- `~/ws/` ディレクトリ
- Claude Code 本体は別途インストール済み

### 手順

```bash
# 1. リポジトリを clone
mkdir -p ~/ws
cd ~/ws
git clone https://github.com/u-stem/claude-system.git

# 2. セットアップスクリプト実行
~/ws/claude-system/tools/setup.sh

# 3. 整合性確認
~/ws/claude-system/tools/doctor.sh

# 4. (Phase 10 完了後)~/.claude/ に symlink を張る
~/ws/claude-system/tools/migrate/from-claude-settings.sh   # 旧設定から切り替え
# または新規インストールなら ~/.claude/ を直接構築
```

詳細は [`meta/multi-device-setup.md`](./meta/multi-device-setup.md) を参照。

---

## 日常運用フロー

```
朝
  └─ doctor.sh で整合性確認(任意)
  └─ プロジェクトディレクトリで claude を起動

開発中
  └─ permissions.deny / hooks が機械的に守る
  └─ post-edit-validate / log-bash-failure が失敗を集約
  └─ stop-session-doctor が未解決 lint/type error を Stop で阻止

週次
  └─ cleanup-backups.sh(30 日経過バックアップ削除、自動化推奨)
  └─ failure-log.jsonl に蓄積した失敗パターンを眺める

月次
  └─ meta/retrospectives/_template.md に書き起こす
  └─ 廃止 skill の整理 / principles 改訂判断 / forbidden-words.txt 追加判断
```

詳細は [`meta/daily-routine.md`](./meta/daily-routine.md) と [`meta/operating-manual.md`](./meta/operating-manual.md) を参照。

---

## 新規プロジェクト作成

```bash
~/ws/claude-system/tools/new-project.sh
# 対話モードで以下を聞かれる:
#   - プロジェクト名
#   - 技術スタック(nextjs-supabase / pixi-game / board-game-doc / scratch)
#   - 共通 fragment(web-apps-common / games-common / board-game-design-common)
# 出力:
#   - ~/ws/<project>/ ディレクトリ作成
#   - CLAUDE.md / .gitignore / .gitleaks.toml の配置
#   - 該当 fragment への @参照
```

引数モードもある(`--name foo --template nextjs-supabase --fragment web-apps-common`)。
ゼロから始めたい場合は `--template scratch` を指定。

---

## 既存プロジェクト取り込み

既存の `~/ws/<project>/CLAUDE.md` を破壊せず、claude-system の共通基盤を @参照経由で接続する。

```bash
~/ws/claude-system/tools/adopt-project.sh ~/ws/<project>
# 1. ~/ws/<project>/CLAUDE.md をバックアップ(~/.claude-system-backups/<project>-CLAUDE.md.<timestamp>)
# 2. 冒頭に @~/ws/claude-system/adapters/claude-code/project-fragments/<fragment>.md を追加
# 3. doctor.sh で整合性確認
```

撤回したい場合は `unadopt-project.sh <project>` または `restore-project.sh <project>` でバックアップから復元。

取り込み済み(2026-04-29 時点): `kairous`, `sugara`。
取り込み履歴は [`meta/CHANGELOG.md`](./meta/CHANGELOG.md) を参照。

---

## シンボリックリンク切り替え(Phase 10 への誘導)

`~/.claude/` を旧 claude-settings から claude-system へ切り替える操作は **Phase 10** で行う。
本リポジトリの `v0.1.0-rc1` 時点では切り替え未実施で、旧設定が `~/.claude/` 配下に展開されている。

### 切り替え手順(Phase 10 で実行)

```bash
~/ws/claude-system/tools/migrate/from-claude-settings.sh
# 1. 既存 ~/.claude/ を ~/.claude-system-backups/migration-<TIMESTAMP>/ に退避
# 2. ~/.claude/ ディレクトリを再作成
# 3. CLAUDE.md / skills / hooks / commands / agents の symlink を張る
# 4. settings.json は手動で template から cp + 編集
# 5. doctor.sh で整合性確認
```

### ロールバック

```bash
~/ws/claude-system/tools/migrate/rollback-from-claude-system.sh
# ~/.claude-system-backups/migration-<TIMESTAMP>/ 最新を確認 → 復元
```

詳細は [`meta/decisions/0005-bootstrap-completion-and-deferral.md`](./meta/decisions/0005-bootstrap-completion-and-deferral.md) を参照。

---

## ガードレールの仕組み(多層防御)

| 層 | 機構 | 役割 | 配置 |
|----|------|------|------|
| 1 | `permissions.deny` | LLM の自制に頼らない物理ブロック | `settings.json.template` |
| 2 | PreToolUse hooks | `--no-verify` / `git push --force` / typosquatting / 保護パスへの書き込みを実行前に阻止 | `user-level/hooks/pre-*.sh` |
| 3 | PostToolUse hooks | 失敗を `failure-log.jsonl` に集約、繰り返し失敗を SessionStart で通知 | `user-level/hooks/log-*.sh`, `check-failure-patterns.sh` |
| 4 | Stop hooks | 失敗未解決での Stop を阻止 | `stop-session-doctor.sh` |
| 5 | CI(GitHub Actions) | push 毎に doctor.sh + gitleaks + shellcheck | `.github/workflows/*.yml` |

### 機械検出される禁止語

`meta/forbidden-words.txt` を唯一の真実源として、以下を `principles/` / `practices/` から検出する:

- `claude` / `claude code` / `claude.md`
- `skill.md` / `subagent` / `mcp`
- `~/.claude/` / `settings.json`
- `slash command`

これにより不変層(principles)に Claude Code 固有用語が逆流するのを防ぐ。

---

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `doctor.sh` が `forbidden word` を報告 | 該当ファイルから禁止語を取り除く。もし正当な使用なら `forbidden-words.txt` 自体を見直す(MAJOR バージョン相当) |
| `~/.claude/` の hook が暴発 | `tools/disable-guardrails.sh` で一時無効化 → `enable-guardrails.sh` で復帰 |
| `cleanup-claude-code-runtime.sh` で消したくないものまで消えそう | 手動実行のみで自動化していない。実行前に `--dry-run` 相当のオプションを追加する設計判断は将来検討 |
| Phase 10 切り替えで何かが壊れた | `tools/migrate/rollback-from-claude-system.sh` で旧設定に戻す |
| `gitleaks` が偽陽性 | `.gitleaks.toml` の `allowlist.regexes` か `paths` に追加 |
| 既存プロジェクト取り込み後に挙動が変 | `tools/unadopt-project.sh <project>` で撤回 → バックアップから復元 |

詳細は [`meta/operating-manual.md`](./meta/operating-manual.md) の「ガードレールが誤検知したときの対処」を参照。

---

## バージョニング

SemVer に従う。

| バンプ種別 | 条件 |
|-----------|------|
| MAJOR | principles 層の破壊的変更、forbidden-words.txt の語追加(取り込み済みの語が新たに禁止になる) |
| MINOR | skill / subagent / practice / fragment / template の追加 |
| PATCH | 修正、文言調整 |

| バージョン | リリース日 | 内容 |
|------------|-----------|------|
| `v0.1.0-rc1` | 2026-04-29 | Phase 9 完了、Phase 10 切り替え前のリリース候補 |
| `v0.1.0` | (Phase 10 完了時) | `~/.claude/` を claude-system へ切り替え |

---

## ライセンス

MIT — [LICENSE](./LICENSE)

---

## 関連

- [`CLAUDE.md`](./CLAUDE.md) — claude-system 自身を編集するときの指示(編集者向け)
- [`adapters/claude-code/user-level/CLAUDE.md`](./adapters/claude-code/user-level/CLAUDE.md) — 全プロジェクト共通の利用者向け指示(Phase 10 で `~/.claude/CLAUDE.md` にリンクされる)
- [`meta/CHANGELOG.md`](./meta/CHANGELOG.md) — 全 Phase 完了履歴
- [`meta/decisions/`](./meta/decisions/) — ADR(設計判断記録)
- [`meta/glossary.md`](./meta/glossary.md) — 用語集
