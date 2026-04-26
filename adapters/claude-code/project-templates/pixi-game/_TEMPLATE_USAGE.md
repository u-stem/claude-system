# テンプレート利用ガイド: pixi-game(skeleton)

このテンプレートは**最小骨子**(skeleton)の状態。
本格採用時に `nextjs-supabase` テンプレートと同等のファイルセット(`README.md.template` / `docs/adr/` / `.pre-commit-config.yaml` 等)を肉付けする。

## 含まれるファイル(現状)

| ファイル | 配置先 | 役割 |
|---------|--------|------|
| `CLAUDE.md.template` | `<project>/CLAUDE.md` | プロジェクト固有の Claude 向け指示。`games-common.md` を `@参照` |
| `.gitignore` | `<project>/.gitignore` | Node + Bun + 中間アセット + Claude Code ランタイム生成物 |
| `.gitleaks.toml` | `<project>/.gitleaks.toml` | 機密検出(最小 allowlist) |

## プレースホルダ一覧

| プレースホルダ | 例 |
|--------------|-----|
| `{{PROJECT_NAME}}` | プロジェクト名 |
| `{{PROJECT_PURPOSE}}` | 1〜2 文の目的記述 |
| `{{GAME_GENRE}}` | `パズル` / `アクション` / `RPG` 等 |
| `{{TARGET_PLATFORM}}` | `Web` / `iOS` / `Android` / `native` 等 |
| `{{GAME_ENGINE}}` | `PixiJS` / `Three.js` / `Phaser` / `Bevy` 等 |
| `{{PROJECT_STATUS}}` | `prototype` / `production` 等 |
| `{{PIXI_VERSION}}` | 例: `8.x` |

## 手動コピー手順

```bash
mkdir -p ~/ws/<project-name>
cd ~/ws/<project-name>
cp -r ~/ws/claude-system/adapters/claude-code/project-templates/pixi-game/. ./
mv CLAUDE.md.template CLAUDE.md
rm _TEMPLATE_USAGE.md
sed -i '' 's/{{PROJECT_NAME}}/<your-project-name>/g' CLAUDE.md
# ... 他のプレースホルダも同様
git init
```

## 肉付け候補(本格採用時に追加)

- [ ] `README.md.template`(プロジェクト概要 / Quick Start / Scripts)
- [ ] `docs/adr/README.md` および `docs/adr/0001-architecture-overview.md.template`
- [ ] `.pre-commit-config.yaml`(`fragments/pre-commit-config.template.yaml` をベースに games 系の lint / typecheck)
- [ ] `tsconfig.json` テンプレート(`typescript-strict` skill 準拠の strict + `noUncheckedIndexedAccess` 等)
- [ ] アセットパイプラインの設計(別 ADR or `docs/architecture/assets.md`)

肉付け時は `~/ws/claude-system/adapters/claude-code/user-level/skills/skill-creation/SKILL.md` の段階的開示の考え方を準用。

## 関連

- 共通 fragment: `~/ws/claude-system/adapters/claude-code/project-fragments/games-common.md`
- 全テンプレート索引: `~/ws/claude-system/adapters/claude-code/project-templates/_README.md`
- 状態: skeleton(2026-04-26 時点)
