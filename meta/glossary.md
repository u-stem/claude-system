# 用語集

claude-system で用いる用語の定義。

層構造を意識して記述する: 「層」「抽象構成要素(principles / practices で使う層非依存の語)」「Claude Code 関連(adapters/claude-code/ 配下のみ)」「運用」「ガードレール」「メモリ」「バージョニング」。

---

## 層

| 用語 | 定義 |
|------|------|
| **principles**(不変層) | ツール非依存の根本原則。最も抽象度が高い。5 年後の自分が読んでも成立する内容のみ |
| **practice**(抽象実践層) | principles を踏まえた抽象的な実践パターン。トリガー・手順・判断基準を整理する |
| **adapter**(適応層) | 特定 AI 開発ツール向けに principles / practices を具体化したもの。固有用語が登場するのはここから下のみ |
| **fragment** | 既存プロジェクトの設定ファイルに `@<file>` 参照で追記される断片(`adapters/claude-code/project-fragments/`) |
| **template** | 新規プロジェクト用のひな形(`adapters/claude-code/project-templates/`)。成熟度は `完成 / 暫定 / skeleton` で区別 |
| **設定階層 / 不変層 / 適応層** | 上記の層構造を運用文脈で呼ぶ別名 |

---

## 抽象構成要素(principles / practices で使う層非依存の語)

| 用語 | 定義 | 適応層での実体 |
|------|------|----------------|
| **能力単位** | 特定タスクを支援する単一責務の抽象単位 | Claude Code では `skill` |
| **補助エージェント** | 専門タスクを担う独立コンテキストの実行単位 | Claude Code では `subagent` |
| **意思決定記録** | 後から経緯を辿りたくなる判断の保存 | `meta/decisions/<NNNN>-*.md`(ADR) |
| **段階的開示** | 必要なときに必要な情報だけロードする原則 | `@<file>` 参照、`SKILL.md` の本体ファイル分離 |
| **コンテキスト経済** | 限られたコンテキスト窓を有効に使う原則 | autocompact 閾値、subagent 委譲、`@` 参照 |

---

## Claude Code 関連(adapters/claude-code/ 配下でのみ使用)

| 用語 | 定義 |
|------|------|
| **skill** | 段階的開示で読み込まれる、特定タスクを支援する定義(能力単位の実体)。`adapters/claude-code/user-level/skills/<name>/SKILL.md` |
| **subagent** | 専門タスクを担う独立コンテキストのエージェント(補助エージェントの実体)。`adapters/claude-code/subagents/<name>.md` |
| **hook** | ツール実行前後やイベント発生時に呼ばれるシェルスクリプト。SessionStart / PreToolUse / PostToolUse / Stop / SubagentStop / SessionEnd 等のイベントで発火 |
| **slash command** | `/` プレフィックスで起動するコマンド。`adapters/claude-code/user-level/commands/<name>.md` |
| **MCP**(Model Context Protocol) | 外部ツールを Claude Code に接続するプロトコル。`settings.json` の `mcpServers` で宣言 |
| **`@<file>` 参照** | Markdown 内で別ファイルを取り込むための claude-code 構文。絶対パス(`@~/ws/claude-system/...`)推奨 |
| **シンボリックリンク** | `~/.claude/CLAUDE.md` 等を `claude-system/adapters/claude-code/user-level/CLAUDE.md` へリンクする運用。Phase 10 で切り替える |
| **`enabledPlugins`** | プラグインの有効化設定(`settings.json` 内)。superpowers / elements-of-style / episodic-memory 等 |
| **CLAUDE.md** | Claude Code がセッション起動時に読む共通指示ファイル。user-level(`~/.claude/CLAUDE.md`)とプロジェクトレベル(`<project>/CLAUDE.md`)が階層的に読まれる |
| **settings.json** | Claude Code の全体設定ファイル。permissions / hooks / env / mcpServers / enabledPlugins を宣言 |

---

## 運用

| 用語 | 定義 |
|------|------|
| **bootstrap** | 新環境にこのシステムを展開する初期化処理。`tools/setup.sh` で実行 |
| **adopt** | 既存プロジェクトを claude-system に取り込むこと。`tools/adopt-project.sh` で実行 |
| **unadopt** | 取り込みを撤回すること。`tools/unadopt-project.sh` で実行 |
| **fragment 配信** | プロジェクト側の `CLAUDE.md` から共通 fragment を `@` 参照で取り込むこと |
| **idempotent(冪等)** | 同じ操作を何度実行しても結果が同じであること。全スクリプトの必須要件 |
| **derivation-records**(継承記録) | principles / practices の各ファイルにある「旧資産からの継承」セクション。旧 claude-settings から抽象化された経緯を残す(整理判断は v0.2) |

---

## ガードレール

| 用語 | 定義 |
|------|------|
| **guardrail** | hooks / CI / permissions による機械的防御の総称 |
| **permissions.deny** | LLM の自制に頼らない物理ブロック。`settings.json` で宣言 |
| **permissions.allow** | 良性で頻出するコマンドの permission prompt 抑制リスト |
| **forbidden-words** | `meta/forbidden-words.txt`。principles / practices に混入してはならない語のリスト。CI / hooks の唯一の真実源 |
| **failure-log** | `${CLAUDE_PROJECT_DIR}/.claude/failure-log.jsonl`。hooks が記録する失敗ログ。SessionStart で繰り返しパターンを通知 |
| **dispatcher パターン** | グローバル hook がプロジェクト側スクリプト(`<project>/.claude/hooks/post-edit.sh` 等)に委譲する設計 |
| **disable-guardrails / enable-guardrails** | hooks を一時無効化 / 復帰するスクリプト(`tools/disable-guardrails.sh` / `tools/enable-guardrails.sh`) |

---

## メモリ

| 用語 | 定義 |
|------|------|
| **auto memory** | 構造化知識ストア(`MEMORY.md` + トピック別 `.md` ファイル)。ユーザー情報・設計判断・フィードバック等を明示的に保存 |
| **episodic-memory** | 過去会話のセマンティック検索プラグイン(Transformers.js + SQLite + sqlite-vec)。「前にどう解決したか」を検索 |
| **Memory MCP** | 採用しない。詳細は ADR 0003 |

---

## Claude 運用習熟度(Phase 8 で発見された概念)

プロジェクトごとに「Claude 協働開発を方法論として書き起こしている段階」の差を表す概念。

| レベル | 状態 | 例 |
|---|---|---|
| **未到達** | Claude を使ってはいるが方法論として書き起こされていない | 取り込み前の sugara |
| **言語化中** | 一部のルールが `CLAUDE.md` に記述されているが未整理 | 多くの個人プロジェクト初期 |
| **整理済み** | rules / practices として体系化されている | kairous |
| **共通基盤化** | 自プロジェクトの方法論を他プロジェクトへ transplant できる | claude-system 取り込み済み |

「2 プロジェクト両方で同じ運用がある = 共通化対象」ではなく、「両方の実態(現状の運用 + 将来の必要性)に適用可能か」で共通化判断する根拠となる概念。

詳細は [`TODO-for-v0.2.md`](./TODO-for-v0.2.md) の「Phase 8 で発見された観察 A/B/C」を参照。

---

## バージョニング

SemVer に従う。

| 用語 | 定義 |
|---|---|
| **MAJOR** | principles 層の破壊的変更、forbidden-words.txt の語追加(取り込み済みの語が新たに禁止になる) |
| **MINOR** | skill / subagent / practice / fragment / template の追加 |
| **PATCH** | 修正、文言調整 |

---

## ADR(Architecture Decision Records)

| 用語 | 定義 |
|---|---|
| **ADR** | `meta/decisions/<NNNN>-<kebab-title>.md`。後から経緯を辿りたくなる判断の永続記録 |
| **Status: Accepted** | 採択済み、現に運用されている |
| **Status: Proposed** | 提案中、まだ採択されていない |
| **Status: Rejected** | 提案されたが採択されなかった(本文は議論記録として残す) |
| **Status: Withdrawn** | 一度採択されたが、後継 ADR で置き換えられたわけでもなく単に取り下げた |
| **Status: Deprecated** | 採択時の前提が崩れたため非推奨。後継 ADR への参照を Related に書く |
| **Status: Superseded by NNNN** | 後続の ADR で置き換えられた |

---

## Phase / レトロ

| 用語 | 定義 |
|---|---|
| **Phase** | bootstrap 期(Phase 0〜10)の作業単位。各 Phase は別セッションで実行 |
| **retrospective**(レトロ) | 月次・四半期の振り返り。`meta/retrospectives/<YYYY-MM>.md` |
| **共通プロトコル** | Phase 完了報告のフォーマット(マスタープラン定義)。検証コマンド出力を必ず添付 |

---

## 関連

- [`forbidden-words.txt`](./forbidden-words.txt) — 機械検出される禁止語の唯一の真実源
- [`decisions/README.md`](./decisions/README.md) — ADR の運用規約
- [`operating-manual.md`](./operating-manual.md) — 月次・四半期・バージョンアップ手順
