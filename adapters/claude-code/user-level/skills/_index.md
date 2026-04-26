# user-level skills 索引(プレースホルダ)

このディレクトリには Claude Code の **user-level skills** を配置する。
本体定義は **Phase 4** で作成される。本ファイルは Phase 3 時点のプレースホルダ。

## 配置場所と役割

- 配置先: `~/ws/claude-system/adapters/claude-code/user-level/skills/<skill-name>/SKILL.md`
- Phase 10 で `~/.claude/skills/` にシンボリックリンクされる
- skill は段階的開示で読み込まれる「能力単位」(`principles/03-skill-composition.md` 参照)

## Phase 4 で作成予定の skill

詳細は [`PHASE-3-4-5-adapter-skills-subagents.md`](../../../../meta/) の Phase 4 セクションおよび旧資産棚卸し([`meta/migration-inventory.md`](../../../../meta/migration-inventory.md))の `skills/` 行を参照。

### Tier 1(必ず作成)

- `tdd/` — t-wada 思想の TDD ワークフロー(Red/Green/Refactor、One-assertion、AAA)
- `debugging/` — 体系的デバッグ 5 ステップ(症状 → 仮説 → 調査 → 検証 → 修正)
- `pr-review/` — PR レビュー観点(機能 / AI ハルシネーション / 誤魔化し / 品質 / セキュリティ / テスト)
- `quality-gate/` — 完了前の必須チェックリスト

### Tier 2 / 3(余裕があれば)

- `refactor/`, `investigate/`, `session-handoff/`, `changelog/`
- `commit-conventional/`, `adr-writing/`, `pr-description/`
- `typescript-strict/`, `nextjs-supabase-base/`, `security-audit/`
- `dependency-review/`, `skill-creation/`, `japanese-tech-writing/`

## frontmatter 形式

```markdown
---
name: <skill-name>          # ディレクトリ名と一致させる
description: <50 字以内、改行禁止、起動条件を 1 行で>
recommended_model: opus | sonnet | haiku
---
```

詳細仕様は [`practices/skill-design-guide.md`](../../../../practices/skill-design-guide.md) を参照。

## 自己検証スクリプト(Phase 4 で使用)

frontmatter とディレクトリ名一致のチェックは Phase 4 完了条件に含まれる。詳細は Phase 4 指示を参照。

## 関連

- [`principles/03-skill-composition.md`](../../../../principles/03-skill-composition.md)
- [`principles/04-progressive-disclosure.md`](../../../../principles/04-progressive-disclosure.md)
- [`practices/skill-design-guide.md`](../../../../practices/skill-design-guide.md)
- [`adapters/claude-code/README.md`](../../README.md)
