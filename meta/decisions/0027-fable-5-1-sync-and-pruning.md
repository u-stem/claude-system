# ADR 0027: Fable 5.1 同期と使用実績に基づく剪定

- **Status**: Accepted
- **Date**: 2026-09-06
- **Decider**: リポジトリオーナー(ADR 0001 の識別子規約に従う)
- **形式**: 決定索引方式の 1 本目(`practices/adr-workflow.md`)。経緯は `meta/CHANGELOG.md` の同日エントリ

## 決定

1. ハーネス pin を 2.1.263、主モデルを `claude-fable-5-1[1m]`、`fallbackModel` を `["claude-opus-5[1m]"]` にする。`effortLevel` は `xhigh` 据え置き
2. 反証役(`devil-advocate`)と最終ゲート(`security-auditor`)の subagent を `model: fable` にする。他は alias 据え置き
3. 180 日間 0 回の自前 skill / command、実機に届かない宣言系統、ハーネスが代替する機構を削除する: MCP 宣言(`mcp/servers.template.json` / `tools/setup-mcp.sh` / `mcpServers` inline)、command 4 本(`review` `check` `test` `_index`)、skill 6 本(`go-style` `rust-style` `python-style` `testing-python` `skill-creation` `security-audit`)、`explorer` subagent(組み込み `Explore` へ)、`pre-bash-output-cap.sh`(native `bashOutputMaxChars` へ)、非仕様 frontmatter `recommended_model`、no-op の `ENABLE_PROMPT_CACHING_1H`、空の hook 結線
4. user-level CLAUDE.md を 10,021 → 6,224 bytes に縮約する。機械強制済みの散文、世代・版の履歴、ハーネスがネイティブに行う指示を落とし、規則本体だけ残す
5. 秘密検出のローカル層を Betterleaks 1.8.1 に置き換える(`.gitleaks.toml` をそのまま読む)。CI は gitleaks-action のまま
6. 記録方式を決定索引方式に改める。旧 ADR は凍結し、現行状態は `meta/decisions/README.md` が表す
7. superpowers を 6.3.0 に更新する(公開 2026-08-12、持ち込み能力は skills 14 / hooks 1 event で不変)

## 根拠

- `/skill-doctor` の実測で自前 13 件が 0 回、superpowers 5 skill が現役。`claude mcp list` と現行セッションの tool 一覧で MCP 宣言が一度も実機に届いていないことを確認
- 公式 docs で `mcpServers` は settings の無効キー、`skillOverrides` は plugin 対象外、subagent は既定で背景実行かつ CLAUDE.md 階層を毎回ロード、`model: fable` が有効と確認
- Betterleaks は既存設定と自前ルール(`user-identifier-path`)で gitleaks と同一の検出結果(陽性対照 2 種、履歴 16 件、作業木 0 件)

## 再評価トリガー

- 次世代モデルの公開(`practices/model-selection.md` 手順 8)、`subagent-log.jsonl` で fable 化した 2 役の品質信号が出たとき
- `/skill-doctor` で残した skill(`nextjs-supabase-*` / `project-tech-stack-decision` / `review-loop` / `team`)が次回も 0 回なら削除
- Betterleaks の保守された CI Action を確認できたとき(CI 置換)。gitleaks のセキュリティ修正が止まったとき

## 不採用と理由

- `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`: 自前 subagent の `tools` に `Agent` が無く単層は成立済み。組み込み `/code-review` の内部 fan-out を壊す(ADR 0022 と同判断)
- `Skill(name)` deny で superpowers 7 skill を無効化: 5 本が現役、description は listing に残る
- `outputStyle: Concise`: §1 報告フォーマットと競合しうる / `promptCacheTtl`: サブスクリプションでは no-op
- subagent `memory:`: ADR 0003 の 2 層構成を崩す(再評価: レビュー指摘の再発観測)
- `timeFormat` `timeZone` `spellcheck` / `PreModelSwitch` `PostModelSwitch` hook / `CLAUDE_CODE_ENABLE_TODO_TOOLS`: 用途なし
- 組み込みエージェント向けの越権 allowlist: ハーネスの tool 強制と重複
- `sandbox.network.strictAllowlist` / `crossSessionInbound`: 据え置き継続(索引参照)

## 覆す決定

ADR 0012(出力 cap hook)、ADR 0016 / 0022(model pin と subagent tier の据え置き)、ADR 0024 §4(per-skill 無効化の待機)、ADR 0026 §4(MCP 宣言系統の検査設計)。旧 ADR は編集しない。

## 代償と範囲外

- 組み込み `Explore` は Bash を持ち、`subagent-stop-audit.sh` の越権監査は定義ファイルの無い組み込みエージェントに効かない。防衛は `pre-bash-guard.sh` とハーネスの tool 制限
- `principles/` 4 ファイルの字数超過、TODO 項目 18(v0.1.0 タグ)は運用者判断待ち、n8n 導入は別計画

## 影響ファイル

`adapters/claude-code/{VERSION,README.md}`、`user-level/{CLAUDE.md,settings.json.template}`、`user-level/commands/`、`user-level/skills/`、`user-level/hooks/`、`subagents/`、`tools/{setup.sh,doctor.sh,new-adr.sh,new-skill.sh}`、`tests/`、`practices/{adr-workflow,model-selection,supply-chain-hygiene,delegation-orchestration}.md`、`meta/{decisions/README.md,claude-version-log.md,TODO-for-v0.2.md,CHANGELOG.md}`
