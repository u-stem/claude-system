# ADR 0004: System Architecture Summary

- **Status**: Accepted
- **Date**: 2026-04-29
- **Decider**: プロジェクトオーナー

## Context

claude-system は Opus 4.7 期に旧 `claude-settings`(Opus 4.6 時代のフラット構造)を完全置換するメタリポジトリとして構築された。Phase 0-9 を通じて以下の設計判断が積み重なったが、それぞれは個別 ADR(0001-0003)や Phase ごとの CHANGELOG に分散しており、claude-system 全体の **アーキテクチャ意思決定の俯瞰**が一箇所に存在しない状態だった。

Phase 9 完了時点で、以下を一貫した方針として明文化し、後続(v0.2 以降)での参照軸とする必要が生じた:

- 4 層構造(principles / practices / adapters / projects)の採用根拠
- `meta/forbidden-words.txt` を唯一の真実源とする禁止語管理
- 絶対パス参照規約(skills / subagents から他層への参照)
- 機械的ガードレール 5 層(permissions.deny / PreToolUse hooks / PostToolUse hooks / Stop hooks / CI)
- Public リポジトリ運用と機密情報の自動排除

それぞれの判断は ADR 0001-0003 や個別 Phase の README で根拠が示されているが、相互関係と運用上の総体は未文書化だった。本 ADR はそれを補う「総括 ADR」として位置づける。

## Decision

claude-system は以下の 5 つの主要アーキテクチャ判断の組み合わせとして運用する。

### 1. 4 層構造

```
principles  (不変層、ツール非依存)
    ↓ 翻訳
practices   (抽象実践層、トリガー・手順・判断基準)
    ↓ 具体化
adapters    (適応層、ツール固有: claude-code / codex)
    ↓ 適用
projects    (個別プロジェクト、gitignore 対象)
```

- 各層は上位層への依存を持たない(下位層は上位層を参照する)
- 各層に共通フォーマット(必須セクション)を定義し、編集規約を機械検出する
- 層境界の越境(特定ツール用語の上位層への混入)は `meta/forbidden-words.txt` で機械検出

### 2. forbidden-words による禁止語管理

- `meta/forbidden-words.txt` を唯一の真実源として、以下を機械検出する:
  - `principles/` / `practices/` への特定ツール用語の混入
  - CI(`.github/workflows/doctor.yml` 内の禁止語チェック)
  - hooks(post-edit-validate / stop-session-doctor のチェーン)
  - `tools/doctor.sh`(ローカル検証)
- 禁止語の追加は MAJOR バージョンアップ相当の判断とし、追加前に既出の語が混入していないか再点検する
- `principles/` 自身を grep する際の自己言及検出を避けるため、本ファイルは `meta/` 配下に置く

### 3. 絶対パス参照規約

`adapters/claude-code/user-level/skills/<name>/SKILL.md` は 4 階層深い位置にあり、`Phase 10` で `~/.claude/skills/` から symlink される。symlink の physical 解決と lexical 解決の差で相対パスの解決先が変わるため、以下を規約とする:

| 参照元 | 参照先 | 推奨パス形式 |
|---|---|---|
| `principles/<file>.md` | 同層 / `practices/` | 相対 |
| `practices/<file>.md` | `principles/` | 相対 |
| `adapters/claude-code/user-level/skills/<name>/SKILL.md` | `principles/` / `practices/` / `meta/` | **絶対**(`~/ws/claude-system/<layer>/<file>`) |
| `adapters/claude-code/subagents/<name>.md` | 同上 | **絶対** |
| `adapters/claude-code/user-level/CLAUDE.md` | 他層 | 相対(深さ 4 階層程度に収まる) |

claude-system は設計上 `~/ws/claude-system/` に固定配置される。別パスへの配置は許容しない。

### 4. 機械的ガードレール 5 層

「LLM の自制に頼らず、機械で防げるものは機械で防ぐ」原則のもと、以下 5 層で多層防御する:

| 層 | 機構 | 実体 | 配置 |
|---|---|---|---|
| 1 | `permissions.deny` | settings.json の deny ルール | `adapters/claude-code/user-level/settings.json.template` |
| 2 | PreToolUse hooks | `pre-bash-guard.sh` / `pre-edit-protect.sh` / `check-package-age.sh` | `adapters/claude-code/user-level/hooks/` |
| 3 | PostToolUse hooks | `log-bash-failure.sh` / `log-failure.sh` / `post-edit-dispatcher.sh` / `post-edit-validate.sh` | 同上 |
| 4 | Stop / SubagentStop hooks | `post-stop-dispatcher.sh` / `stop-session-doctor.sh` / `subagent-stop-record.sh` / `subagent-stop-audit.sh` / `check-failure-patterns.sh` | 同上 |
| 5 | CI(GitHub Actions) | `doctor.yml` / `secrets-scan.yml` / `shellcheck.yml` | `.github/workflows/` |

`disable-guardrails.sh` / `enable-guardrails.sh` で hooks の一時無効化が可能。誤検知時の運用エスケープ。

### 5. Public リポジトリ運用 + 機密情報の自動排除

- claude-system は **Public** として公開する(透明性、ロールバック容易性)
- 機密情報の混入を以下で自動排除:
  - `.gitignore` で `projects/` 配下、ランタイム生成物を除外
  - `.gitleaks.toml` で API キー類のパターンを検出、`allowlist` で template 等の意図的なプレースホルダを除外
  - CI(`.github/workflows/secrets-scan.yml`)で push 毎に gitleaks 実行
  - ADR 0001(個人特定情報)/ ADR 0002(Public/Private 境界)で語彙レベルの規約
- 第三者向けの汎用テンプレートではなく、Mikiya 個人の作業環境を前提に最適化されている旨を README に明示

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|---|---|---|
| **モノリシック CLAUDE.md**(全指示を 1 ファイルに集約) | 不採用 | 段階的開示が効かず、コンテキスト経済が悪化。プロジェクトごとの差分管理も困難 |
| **単一フラットなディレクトリ**(層構造なし) | 不採用 | principles と adapters が同居すると、ツール固有の用語が原則に逆流するリスクが高い。実際に旧 claude-settings はこの問題を抱えていた(取り込み時の整理で大量の判断コストが発生) |
| **層は 2 段(principles / adapters)** | 不採用 | principles と adapters の間に「抽象実践パターン」を挟まないと、原則を実装に落とし込む際のジャンプが大きく、判断軸が不足する。practices 層が緩衝として機能している |
| **Private リポジトリ運用** | 不採用 | 透明性が下がり、claude-system 自体の改善履歴が外部から見えなくなる。将来別マシンへの展開時に clone できない不便さ。Public 化のリスクは機械的ガードレール 5 層 + ADR 0001/0002 で抑える方針を採用 |
| **forbidden-words を hooks 内にハードコード** | 不採用 | 禁止語の追加・削除のたびにスクリプト修正が必要になり、ADR 起票プロセスとの整合が取りにくい。データファイル化で MAJOR バージョン判断を独立させる |
| **絶対パスを環境変数(`${CLAUDE_SYSTEM_ROOT}`)化** | 不採用 | Markdown レンダラ・ツールが展開しないため可読性が下がる。`~/ws/claude-system/` 固定配置を規約として明示する方が明快 |
| **全 hooks を `permissions.deny` に統合** | 不採用 | hooks は条件分岐・ロギング・カテゴリ判定など複雑な処理を持つ。permissions は単純パターンマッチに留め、複雑な防御は hooks に委譲する責務分離が機能している |
| **claude-system 自身を Issue 駆動運用**(GitHub Issues / Projects / Discussions) | 保留 | 個人プロジェクトのため Issue 駆動はオーバーヘッドが大きい可能性。v0.2 検討材料として `meta/TODO-for-v0.2.md` に記録 |

## Consequences

### Positive

- **判断基準が一箇所に集約**: 後続の判断(skill 追加、guardrail 追加、refactor)で「この決定はどの ADR の何項に従うか」を辿れる
- **層境界の機械的保証**: forbidden-words による検出で、人間の注意力に依らず層構造が維持される
- **多層防御の冗長性**: 1 層が抜けても他層で防げる。例: permissions.deny を回避する Bash パターンを LLM が編み出しても、PreToolUse hook と CI で検出される
- **Public 運用と機密保護の両立**: `.gitignore` + `.gitleaks.toml` + CI で人間の確認に依存しない仕組み
- **ロールバック容易**: 各 Phase で 1 コミット以上残し、`git revert` で個別 Phase を巻き戻せる(Phase 7b の hooks 有効化以降は `disable-guardrails.sh` で一時無効化も可能)

### Negative

- **学習コスト**: 4 層構造 + 5 つのガードレール層 + 絶対パス規約 + ADR 運用は、claude-system に初めて触れる場合の学習コストが高い。本人専用前提なので外部利用者は想定しないが、未来の自分(数ヶ月のブランクを経た後)が再学習するコストはある
- **書き換えの腰の重さ**: principles 改訂が MAJOR バージョン相当扱いになるため、「ちょっと改善したい」が滞る可能性。四半期見直しの定例([`operating-manual.md`](../operating-manual.md))で逆に動かす運用
- **Phase 10 への依存**: claude-system が「実際に効く」のは Phase 10 の symlink 切り替え後。それまでは旧 claude-settings の挙動が継続するため、機械的ガードレールの実効性は Phase 10 完了後に初めて検証できる(本 ADR 採択時点では検証未了)

### Neutral

- **ツール置き換え時の挙動**: codex / 別の AI コーディングツールに乗り換える場合、`adapters/claude-code/` を `adapters/codex/` に置き換える形で principles / practices は再利用できる(設計上)。実際に乗り換えた際に検証する
- **絶対パス規約の Linux 拡張**: 別マシン展開を `~/ws/claude-system/` 固定としているため、macOS と Linux で同じパス構造を取る。Windows は対象外

## Related

- [ADR 0001](./0001-anonymity-policy.md) — 個人特定情報の取り扱い(本 ADR の Public 運用前提)
- [ADR 0002](./0002-public-private-boundary.md) — Public/Private 境界(本 ADR の Public 運用前提)
- [ADR 0003](./0003-memory-architecture.md) — 記憶アーキテクチャ(本 ADR の構成要素のひとつ、`adapters/claude-code/user-level/CLAUDE.md` 経由で接続)
- [ADR 0005](./0005-bootstrap-completion-and-deferral.md) — Phase 9 完了 + Phase 10 への遅延判断
- [`README.md`](../../README.md) — システム概要(本 ADR の人間向け要約)
- [`principles/00-meta.md`](../../principles/00-meta.md) — 不変層の編集規約(本 ADR の層構造の起点)
- [`adapters/claude-code/README.md`](../../adapters/claude-code/README.md) — クロスレイヤー参照のパス規約(本 ADR の絶対パス規約の詳細)
- [`meta/forbidden-words.txt`](../forbidden-words.txt) — 機械検出される禁止語の唯一の真実源
- [`meta/glossary.md`](../glossary.md) — 用語集
