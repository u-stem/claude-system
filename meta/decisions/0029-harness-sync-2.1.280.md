# ADR 0029: ハーネス同期 2.1.280(Opus 5.5 と claude.ai 同期のオプトアウト)

- **Status**: Accepted
- **Date**: 2026-09-23
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)

## 決定

1. `fallbackModel` を `["claude-opus-5-5[1m]", "claude-opus-5[1m]"]` の 2 段にする。先頭は 2.1.280 で既定 Opus になった 5.5、後段は 1 世代前の既知良品(過負荷時は既定 Opus も同時に混みうる)
2. claude.ai アカウントの skill / plugin 同期を `syncClaudeAiSkills: false` / `syncClaudeAiPlugins: false` で無効化し、残骸置き場 `skills/synced/` と `skills/.trash/` を `.gitignore` で隔離する。供給網ガードレールの新設と読む
3. 同時に行った索引の執行(ADR の決定ではない): pin 2.1.280、effort pin を `modelSettings.<model>.effortLevel: xhigh` へ(値は不変)、episodic-memory 1.6.0、0 回 skill 5 本の削除判定を 2026-12 へ

## 根拠

- `/skill-doctor` で claude.ai 同期 skill 8 本が全て 0 回・約 1,750 tokens/turn、同期先 `~/.claude/skills/synced/` が symlink 越しに repo へ 350 エントリ落ちた(`meta/CHANGELOG.md` 2026-09-23)
- `/effort` は per-model に保存し top-level `effortLevel` は Opus 5.5 以降に効かない、`opus` alias は 5.5 に解決(https://code.claude.com/docs/en/model-config)
- `false` で同期停止・既同期分は `.trash` 退避、真実源は claude.ai 側で可逆(https://code.claude.com/docs/en/plugins-reference)

## 再評価トリガー

fallback 先頭の 5.5 が縮退先として不達を繰り返したとき(先頭と後段を入れ替える)/ claude.ai 側で有効化した skill を端末で使いたくなったとき(flag を戻し、`auditedPluginVersions` 相当の棚卸しを同期物にも課す)/ 次世代 Opus の公開

## 不採用と理由

- fallback を Opus 5.5 単独: 過負荷時に既定 Opus も混む
- top-level `effortLevel` の削除: fallback 後段の Opus 5 に効く唯一の経路
- `omitClaudeMd`: user / project / local を一括で外し実装役・文書追従役が層別編集ルールと出力衛生の指示層を失う。検出層(`subagent-stop-audit.sh`)は transcript grep で残る
- `bashEditDiffEnabled`: Bash 経由の編集は implementer のみ、rework は PostToolUse で観測
- `maxEffortLevel`: 個人運用に上限不要
- AGENTS.md モード変更: 既定 `claude-md-or-agents-md` で CLAUDE.md 優先
- `EPISODIC_MEMORY_*` 等の新 env: env 3 つの決定を守る
- superpowers 6.4.1 即時更新: 公開 4 日、7 日ルール
- 0 回 skill 5 本の即時削除: 判定窓 17 日

## 覆す決定

ADR 0027 決定 1 の `fallbackModel: ["claude-opus-5[1m]"]`(索引「委譲とモデル」の主モデル行)。旧 ADR は編集しない。

## 影響ファイル

`adapters/claude-code/{VERSION,README.md}`、`user-level/settings.json.template`、`user-level/commands/update-check.md`、`subagents/_index.md`、`.gitignore`、`meta/{decisions/README.md,claude-version-log.md,TODO-for-v0.2.md,CHANGELOG.md}`
