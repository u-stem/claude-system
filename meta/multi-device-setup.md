# 別マシンセットアップ

claude-system を別の macOS マシン(2 台目以降)に展開する手順。

> 現状は **macOS のみ前提**。Linux サーバー対応は将来検討(設計上は移植可能だが、シェル組み込み・MCP・hooks の挙動を再検証する必要あり)。

---

## 前提

- macOS(Apple Silicon または Intel)
- Homebrew インストール済み
- GitHub アカウント連携済み(SSH キー or `gh` 認証)
- Claude Code 本体インストール済み(npm or Anthropic 公式インストーラ)

---

## 手順 A: chezmoi なし(最小構成)

### 1. 必須ツール

```bash
brew install bash gh gitleaks shellcheck jq tree
brew install bun         # JS/TS パッケージマネージャ
brew install uv          # Python パッケージマネージャ(astral-sh/uv)
```

### 2. claude-system を clone

```bash
mkdir -p ~/ws
cd ~/ws
git clone https://github.com/u-stem/claude-system.git
```

### 3. セットアップ

```bash
~/ws/claude-system/tools/setup.sh
# - 前提ツール検出(brew で何が入っているか)
# - ~/.claude-system-backups/ 作成
# - tools/doctor.sh 実行
```

### 4. ~/.claude/ への接続

新規マシンでは `~/.claude/` がほぼ空(Claude Code 初回起動で作られる)。

```bash
# 既存マシンの設定を引き継がない場合(新環境)
mkdir -p ~/.claude
ln -s ~/ws/claude-system/adapters/claude-code/user-level/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/ws/claude-system/adapters/claude-code/user-level/skills    ~/.claude/skills
ln -s ~/ws/claude-system/adapters/claude-code/user-level/hooks     ~/.claude/hooks
ln -s ~/ws/claude-system/adapters/claude-code/user-level/commands  ~/.claude/commands
ln -s ~/ws/claude-system/adapters/claude-code/subagents            ~/.claude/agents

# settings.json は cp で配置(マシン固有値の差し込みのため)
cp ~/ws/claude-system/adapters/claude-code/user-level/settings.json.template ~/.claude/settings.json
$EDITOR ~/.claude/settings.json   # TODO コメント箇所を編集
```

### 5. 動作確認

```bash
~/ws/claude-system/tools/doctor.sh
~/ws/claude-system/tools/check-claude-version.sh   # Claude Code 本体と adapter VERSION の差分
```

問題なければ任意のプロジェクトで `claude` を起動して挙動確認。

---

## 手順 B: chezmoi 連携

dotfiles 管理に chezmoi を使う場合。`.zshrc` や `.gitconfig` 等の汎用 dotfiles と一緒に管理する。

### 設計方針

claude-system 本体は `git clone` で直接管理(chezmoi の管轄外)。
chezmoi は以下のみ受け持つ:

- 汎用 dotfiles(`.zshrc` / `.gitconfig` / `.vimrc` 等)
- `~/.claude/settings.json` の生成(マシン固有値の差し込み)
- `claude-system` セットアップの自動化(初回 `chezmoi apply` で `tools/setup.sh` 実行)

### chezmoi 設定例

```yaml
# ~/.config/chezmoi/chezmoi.yaml
data:
  email: "{{ .githubEmail | default \"tanaka128821@gmail.com\" }}"
  ws_dir: "{{ .chezmoi.homeDir }}/ws"
```

```bash
# .chezmoiscripts/run_once_after_clone-claude-system.sh
#!/usr/bin/env bash
set -euo pipefail
WS_DIR="{{ .ws_dir }}"
if [ ! -d "$WS_DIR/claude-system" ]; then
  mkdir -p "$WS_DIR"
  git clone https://github.com/u-stem/claude-system.git "$WS_DIR/claude-system"
fi
"$WS_DIR/claude-system/tools/setup.sh"
```

```yaml
# .chezmoiexternal.yaml(代替案: chezmoi に管理させる)
"~/ws/claude-system":
  type: git-repo
  url: "https://github.com/u-stem/claude-system.git"
  refreshPeriod: 168h
```

### settings.json をテンプレート化

```bash
# .chezmoiscripts/run_after_setup-claude-settings.sh.tmpl
#!/usr/bin/env bash
set -euo pipefail
TEMPLATE=~/ws/claude-system/adapters/claude-code/user-level/settings.json.template
TARGET=~/.claude/settings.json
if [ ! -f "$TARGET" ]; then
  cp "$TEMPLATE" "$TARGET"
fi
```

`settings.json` 自体を chezmoi のテンプレート(`.tmpl`)にして `{{ .machineHostname }}` 等を埋め込む案もあるが、現状は cp + 手動編集で十分(複雑度を上げない判断)。

---

## マシン固有設定の管理方針

### Symlink できるもの

- `~/.claude/CLAUDE.md`
- `~/.claude/skills/`
- `~/.claude/hooks/`
- `~/.claude/commands/`
- `~/.claude/agents/`

これらはマシン非依存。

### Symlink できない / すべきでないもの

| ファイル | 理由 | 対処 |
|---|---|---|
| `~/.claude/settings.json` | マシン固有値(API キー / hook の絶対パス / ローカル MCP server の port 等) | template から `cp` 配置 → 手動編集 |
| `~/.claude/projects/<scope>/memory/` | プロジェクトスコープの auto memory(マシン横断同期は別途検討) | 同期は当面しない |
| `~/.claude/cache/`, `~/.claude/file-history/`, `~/.claude/sessions/` 等 | ランタイム生成物 | gitignore + 同期しない |

### マシン横断のメモリ同期

現状は同期しない方針(複雑度を上げない判断)。
必要になったら以下を検討:

- `episodic-memory` の SQLite DB を rsync / iCloud Drive 同期
- `auto memory` の Markdown ファイルを git 管理(ただし Public 化リスクに注意)

これは v0.2 以降の検討事項([`TODO-for-v0.2.md`](./TODO-for-v0.2.md))。

---

## トラブルシューティング

### `tools/doctor.sh` が `~/.claude/<sub> still points at claude-settings` を warn

→ 想定どおり(Phase 0-9 では旧設定への symlink を維持)。
Phase 10 切り替え後に消える。

### `gitleaks` がインストール済みなのに `tools/doctor.sh` が `gitleaks not installed` と言う

→ `brew install gitleaks` 後に PATH に乗っているか確認。
`which gitleaks` が空なら `brew unlink gitleaks && brew link gitleaks`。

### Claude Code 本体のバージョンと `adapters/claude-code/VERSION` がずれる

→ `tools/check-claude-version.sh` で diff を表示。
[`operating-manual.md`](./operating-manual.md) の「Claude Code バージョンアップ手順」に従う。

### `tools/setup.sh` が新マシンで失敗する

→ `set -x` でデバッグ。たいていは前提ツール(jq / shellcheck)が無い、または PATH が通っていない。

---

## 関連

- [`README.md`](../README.md) — クイックスタート
- [`operating-manual.md`](./operating-manual.md) — Claude Code バージョンアップ手順
- [`tools/setup.sh`](../tools/setup.sh)
