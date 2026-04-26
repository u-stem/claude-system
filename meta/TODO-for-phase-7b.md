# Phase 7b への申し送り TODO

このファイルは Phase 0.5 の棚卸しで判明した「Phase 7b(Guardrails 層: hooks / CI / secrets)実装時に必ず取り込むべき高価値資産」を記録する場所。

旧 claude-settings はオーナーから「雑に作った」と表現されていたが、棚卸しの結果、以下 3 件は v3 マスタープランに **欠けていた発想** であり、新システムでも必ず採用する。

## 必ず取り込む 3 件の高価値資産

### 1. typosquatting / 侵害バージョン攻撃の能動的防御

旧ファイル: `~/ws/claude-settings/hooks/check-package-age.sh`(117 行)

- npm / PyPI / crates 各レジストリから対象パッケージの **初回公開日** を取得
- 公開から `PACKAGE_MIN_AGE_DAYS`(デフォルト 7 日)以内の若いパッケージは **deny**
- macOS BSD `date -jf` と GNU `date -d` の両方に fallback、レジストリ lookup 失敗時も deny(誤って install させない)
- ecosystem 判定 → パッケージ名抽出 → バージョン specifier 剥離 → 公開日 lookup → 閾値比較、の流れがクリーン

新システムでの取り込み:

- **配置**: `adapters/claude-code/user-level/hooks/check-package-age.sh`(機能はそのまま、絶対パス参照を `${HOME}` 経由に置換)
- **settings.json への結線**: `PreToolUse` matcher `Bash` の `command` として登録
- **環境変数**: `PACKAGE_MIN_AGE_DAYS`(デフォルト 7、プロジェクト個別 override 可能)
- **根拠資料**: 旧 `docs/superpowers/specs/2026-04-01-supply-chain-defense-design.md`(Public 化はしないが、設計意図は本 TODO に転記済み)

### 2. 失敗フィードバックループ(自己参照ハーネス)

旧ファイル群:
- `~/ws/claude-settings/hooks/log-failure.sh`(25 行)
- `~/ws/claude-settings/hooks/log-bash-failure.sh`(29 行)
- `~/ws/claude-settings/hooks/check-failure-patterns.sh`(36 行)

設計の核:

```
[失敗発生] PostToolUse Bash hook → 終了コード ≠ 0 を検知
   ↓ category 判定 (test / check-types / check)
[蓄積] log-failure.sh → .claude/failure-log.jsonl に JSONL 追記
   ↓
[再発検出] SessionStart hook → check-failure-patterns.sh が
           同 category で 3 回以上失敗していれば Claude に通知
   ↓
[ルール化を促す] エージェントが .claude/rules/ や .claude/skills/ を更新
   ↓
[クリア] rm .claude/failure-log.jsonl
```

これは **ハーネス自身が自身の改善を促す自己参照ループ**であり、v3 マスタープランには明示されていない発想。

新システムでの取り込み:

- **配置**: `adapters/claude-code/user-level/hooks/{log-failure,log-bash-failure,check-failure-patterns}.sh`
- **settings.json への結線**:
  - `SessionStart` で `check-failure-patterns.sh` を呼ぶ
  - `PostToolUse` matcher `Bash` で `log-bash-failure.sh` を呼ぶ
- **失敗ログのパス**: `${CLAUDE_PROJECT_DIR:-.}/.claude/failure-log.jsonl`(プロジェクト内に閉じる)
- **`practices/feedback-loop.md`**(Phase 2 で作成)から本仕様を参照する形にし、原則と具体実装を分離

### 3. post-edit / post-stop ディスパッチャパターン

旧設計:

- グローバル `settings.json` の `PostToolUse` (Edit|Write) hook と `Stop` hook は **dispatcher** に徹する
  - `if [ -x .claude/hooks/post-edit.sh ]; then .claude/hooks/post-edit.sh; fi`
  - `if [ -x .claude/hooks/post-stop.sh ]; then .claude/hooks/post-stop.sh; fi`
- 言語固有の処理(biome / tsc / ruff / mypy / cargo clippy / go vet 等)は **プロジェクト側** で実装
- `hooks/examples/` に各言語向けのリファレンス実装を提供(Phase 6 で project-templates として配布)

これにより:

- グローバルハーネスは **言語非依存** を維持
- プロジェクト側は **autonomy** を持ち、言語切替・monorepo 構成変更に追随できる
- 失敗時のメッセージはプロジェクト側で組み立てるので Claude が修正しやすい

新システムでの取り込み:

- **settings.json テンプレート**: 上記 dispatcher hook をそのまま記述
- **project-templates**: `adapters/claude-code/project-templates/post-edit/{typescript,python,rust,go,monorepo-bun}.sh`(Phase 6)
- **project-templates**: `adapters/claude-code/project-templates/post-stop/{auto-detect,monorepo-bun}.sh`(Phase 6)
- monorepo 用は `{{PROJECT_NAME}}` プレースホルダ化(`meta/migration-inventory.md` の hooks/examples 行参照)

## 取り込みのチェックリスト(Phase 7b 完了時)

- [ ] `check-package-age.sh` が adapter/user-level/hooks に配置され、settings.json テンプレートから結線されている
- [ ] `log-failure.sh` / `log-bash-failure.sh` / `check-failure-patterns.sh` が adapter/user-level/hooks に配置され、SessionStart と PostToolUse(Bash) から結線されている
- [ ] グローバル `settings.json` テンプレートに post-edit / post-stop dispatcher hook が記述されている
- [ ] `practices/feedback-loop.md`(Phase 2)で自己参照ループの原則が抽象化されている
- [ ] `practices/supply-chain.md`(Phase 2)で typosquatting 防御の原則が抽象化されている
- [ ] このファイル `meta/TODO-for-phase-7b.md` 自体を削除する(Phase 7b 終了時)
