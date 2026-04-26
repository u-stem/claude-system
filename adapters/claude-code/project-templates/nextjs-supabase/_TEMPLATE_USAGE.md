# テンプレート利用ガイド: nextjs-supabase

このテンプレートは Next.js + Supabase プロジェクトの初期構成を提供する。
Phase 7a で `tools/new-project.sh <project-name> nextjs-supabase` 経由で展開される予定。
手動展開時は本ファイルの「手動コピー手順」を参照。

## 含まれるファイル

| ファイル | 配置先 | 役割 |
|---------|--------|------|
| `CLAUDE.md.template` | `<project>/CLAUDE.md` | プロジェクト固有の Claude 向け指示。共通 fragment(`web-apps-common.md`)を `@参照` |
| `README.md.template` | `<project>/README.md` | プロジェクト README |
| `.gitignore` | `<project>/.gitignore` | Node + Next.js + Vercel + Supabase + Claude Code ランタイム生成物 |
| `.gitleaks.toml` | `<project>/.gitleaks.toml` | 機密検出(allowlist + ダミー値 regex) |
| `.pre-commit-config.yaml` | `<project>/.pre-commit-config.yaml` | gitleaks + tsc + lint の pre-commit hook |
| `docs/adr/README.md` | `<project>/docs/adr/README.md` | ADR 運用説明 |
| `docs/adr/0001-architecture-overview.md.template` | `<project>/docs/adr/0001-architecture-overview.md` | 初期 ADR 雛形 |

## プレースホルダ一覧

`{{PLACEHOLDER}}` 形式で以下が含まれる。展開時に置換する:

| プレースホルダ | 例 |
|--------------|-----|
| `{{PROJECT_NAME}}` | プロジェクト名(ディレクトリ名と一致推奨) |
| `{{PROJECT_PURPOSE}}` | 1〜2 文の目的記述 |
| `{{PROJECT_KEY_FEATURES}}` | 主要機能の箇条書き |
| `{{PROJECT_STATUS}}` | `prototype` / `production` / `archived` 等 |
| `{{PROJECT_VISIBILITY}}` | `private` / `public` / `members-only` 等 |
| `{{NODE_VERSION}}` | 例: `22.x` |
| `{{BUN_VERSION}}` | 例: `1.2.x` |
| `{{NEXTJS_VERSION}}` | 例: `15.5.x` |
| `{{ADR_DATE}}` | ADR 採択日 `YYYY-MM-DD` |
| `{{DECIDER}}` | 意思決定者(本名禁止、`プロジェクトオーナー` 等の抽象表現または `u-stem` 等の handle、ADR 0001) |
| `{{ADDITIONAL_ENV_VARS}}` | プロジェクト固有の追加環境変数 |
| `{{LICENSE}}` | `MIT` / `proprietary` 等 |

## 手動コピー手順(`new-project.sh` を待たずに使う場合)

```bash
# 1. プロジェクトディレクトリ作成
mkdir -p ~/ws/<project-name>
cd ~/ws/<project-name>

# 2. テンプレートをコピー(隠しファイル含む)
cp -r ~/ws/claude-system/adapters/claude-code/project-templates/nextjs-supabase/. ./

# 3. .template suffix を外す
mv CLAUDE.md.template CLAUDE.md
mv README.md.template README.md
mv docs/adr/0001-architecture-overview.md.template docs/adr/0001-architecture-overview.md
rm _TEMPLATE_USAGE.md   # 利用後は不要

# 4. プレースホルダ置換(GNU sed と BSD sed の差異に注意)
#    macOS BSD sed の例:
sed -i '' 's/{{PROJECT_NAME}}/<your-project-name>/g' CLAUDE.md README.md docs/adr/*.md
sed -i '' 's/{{PROJECT_PURPOSE}}/<your purpose>/g' CLAUDE.md README.md
# ... 他のプレースホルダも同様

# 5. 初期化
git init
bun install
pre-commit install

# 6. 初回 commit
git add .
git commit -m "chore: initial commit from claude-system nextjs-supabase template"
```

## 利用後のチェックリスト

- [ ] 全プレースホルダが置換済み(`grep -rE '\{\{[A-Z_]+\}\}' .` で 0 件)
- [ ] `_TEMPLATE_USAGE.md` を削除した
- [ ] `.env.example` を作成し、必要な変数を列挙した
- [ ] `.env.local` を作成し本物の値を入れた(コミットしない、`.gitignore` で除外済み)
- [ ] `bun run typecheck` が pass
- [ ] `pre-commit run --all-files` が pass
- [ ] 初期 ADR(0001)に実プロジェクトの判断理由を反映した
- [ ] `~/ws/claude-system/projects/<project-name>/` も作成して fragment / 補助ノートを置く(gitignore 対象)

## 関連

- 共通 fragment: `~/ws/claude-system/adapters/claude-code/project-fragments/web-apps-common.md`
- skill: `nextjs-supabase-base` / `nextjs-supabase-rls` / `typescript-strict` / `security-audit`
- subagent: `code-reviewer` / `security-auditor` / `doc-writer`
- 全テンプレート索引: `~/ws/claude-system/adapters/claude-code/project-templates/_README.md`
