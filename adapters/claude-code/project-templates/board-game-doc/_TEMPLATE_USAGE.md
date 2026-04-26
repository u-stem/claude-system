# テンプレート利用ガイド: board-game-doc

板ゲー(ボードゲーム / カードゲーム / TRPG)設計プロジェクトの初期構成テンプレート。
ルールブック執筆 / バランステスト / プレイテストログの三本柱で運用する。

## 含まれるファイル

| ファイル / ディレクトリ | 配置先 | 役割 |
|------------------------|--------|------|
| `CLAUDE.md.template` | `<project>/CLAUDE.md` | プロジェクト固有の Claude 向け指示。`board-game-design-common.md` を `@参照` |
| `.gitignore` | `<project>/.gitignore` | 中間ファイル(.psd / .blend) + Claude Code ランタイム生成物 |
| `.gitleaks.toml` | `<project>/.gitleaks.toml` | 機密検出(最小骨子) |
| `docs/rulebook/.gitkeep` | `<project>/docs/rulebook/` | ルールブック原稿用ディレクトリ(空) |
| `docs/balance-tests/.gitkeep` | `<project>/docs/balance-tests/` | バランス計算 spreadsheet 用ディレクトリ(空) |
| `docs/playtest-logs/.gitkeep` | `<project>/docs/playtest-logs/` | プレイテストログ用ディレクトリ(空) |

`.gitkeep` は git で空ディレクトリを管理するためのプレースホルダ。テンプレートが意図する**ディレクトリ構造を伝達する**ことが目的。利用時に削除しても問題ない(中身ファイルが入った時点で `.gitkeep` 自体を削除する慣習)。

## プレースホルダ一覧

| プレースホルダ | 例 |
|--------------|-----|
| `{{PROJECT_NAME}}` | プロジェクト名(リポジトリ名と一致) |
| `{{GAME_TITLE}}` | ゲームタイトル(プロジェクト名と異なる場合) |
| `{{CORE_MECHANIC}}` | 1 文でコアメカニクスを表現 |
| `{{PLAYER_COUNT}}` | 例: `2-4 人` |
| `{{PLAY_TIME}}` | 例: `30-60 分` |
| `{{TARGET_AUDIENCE}}` | `コア` / `カジュアル` / `子ども` / `ファミリー` 等 |
| `{{GAME_FORMAT}}` | `物理` / `デジタル` / `両用` |
| `{{VERSION}}` | 例: `0.3.0`(プロトタイプ初期) |
| `{{PROJECT_STATUS}}` | `設計初期` / `プレイテスト中` / `出版準備` / `完成` |

## 手動コピー手順

```bash
mkdir -p ~/ws/<project-name>
cd ~/ws/<project-name>
cp -r ~/ws/claude-system/adapters/claude-code/project-templates/board-game-doc/. ./
mv CLAUDE.md.template CLAUDE.md
rm _TEMPLATE_USAGE.md
sed -i '' 's/{{PROJECT_NAME}}/<your-project-name>/g' CLAUDE.md
sed -i '' 's/{{GAME_TITLE}}/<your-title>/g' CLAUDE.md
# ... 他のプレースホルダも同様
git init
git add .
git commit -m "chore: initial commit from claude-system board-game-doc template"
```

## 利用後のチェックリスト

- [ ] 全プレースホルダが置換済み
- [ ] `_TEMPLATE_USAGE.md` を削除した
- [ ] `docs/rulebook/` `docs/balance-tests/` `docs/playtest-logs/` の各ディレクトリが存在する
- [ ] 初回プレイテスト前に**用語集**(`docs/rulebook/glossary.md` 等)を作成した
- [ ] プレイテストログを匿名化(参加者を A / B / C 等のラベル化、ADR 0001)で書く運用を周知した
- [ ] バランス変更時に ADR を起票するルールを `CLAUDE.md` に明記した(本テンプレートでは既に明記済み)

## 推奨 skill

- `japanese-tech-writing` — ルールブック / プレイテストログ執筆
- `adr-writing` — バランス変更・ルール変更の ADR 化

## 関連

- 共通 fragment: `~/ws/claude-system/adapters/claude-code/project-fragments/board-game-design-common.md`
- 全テンプレート索引: `~/ws/claude-system/adapters/claude-code/project-templates/_README.md`
