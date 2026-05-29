# subagents 索引

このディレクトリには Claude Code の **subagent**(補助エージェント)定義を配置する。
Phase 10 で `~/.claude/agents/` にシンボリックリンクされる。

subagent は独立コンテキストを持つ専門タスク実行単位(根拠は [`principles/01-context-economy.md`](~/ws/claude-system/principles/01-context-economy.md) の委譲基準と [`practices/session-handoff.md`](~/ws/claude-system/practices/session-handoff.md))。

## 委譲プロトコル(メイン=オーケストレータ)

[`practices/delegation-orchestration.md`](~/ws/claude-system/practices/delegation-orchestration.md) と [ADR 0011](~/ws/claude-system/meta/decisions/0011-delegation-orchestration-protocol.md) を Claude Code の語彙へ落とす。メインは指示出しと統合に徹し、実作業と大量の中間出力を subagent に閉じ込める。

### 役割分離

| 主体 | 担うこと | 担わないこと |
|------|----------|--------------|
| メイン Claude | タスク分解、subagent の選定、結論の統合、不可逆操作の判断、ユーザーとの対話 | 広範な探索の実走、大量の中間出力の保持 |
| subagent | スコープ内の実作業、中間出力の生成と消化 | 役割境界を越えた判断、ユーザーへの直接応答(最終テキストはメインへの戻り値) |

### 委譲トリガー(定量基準)

- 広範な探索: 5 クエリ超 / 10 ファイル以上の横断 → `explorer`(内部)/ `research-summarizer`(外部)
- 大量出力の予測: ログ走査・全文読解・一括変換 → 専門 subagent
- 独立並列タスク: 相互依存なし → 1 メッセージで複数の Agent 呼び出し(並列ファンアウト)
- 既知の 1 点参照・軽微な確認 → メイン直接実行(委譲しない)

### 渡す情報 / 返す情報

- **渡す**: スコープを絞ったタスク + 返却フォーマット指定。生のコンテキストを丸投げしない。
- **返す**: 構造化された結論のみ(重大度別件数 + 指摘リスト、`file_path:line` 参照と要約)。subagent の `description` 本文に返却フォーマットを明記する(後述「v3 で追加した規約」)。ファイルダンプ・探索ログをメインに戻さない。

### 段階(単発 → 並列ファンアウト → Workflow)

| 段階 | 場面 | 制約 |
|------|------|------|
| 単発 subagent(Agent ツール) | 1 つの独立した重いタスク | 既定 |
| 並列ファンアウト | 独立な複数タスク | 1 メッセージで複数ツール呼び出し |
| Workflow(決定論的オーケストレーション) | 多段・多数エージェント | **ユーザー明示オプトイン時のみ**([ADR 0009](~/ws/claude-system/meta/decisions/0009-opus-48-autonomy-tuning.md) §3) |

## 全 subagent 一覧

(直近の更新は `git log` を参照)

| name | description | tools | model | 旧 agents/ との対応 |
|------|-------------|-------|-------|---------------------|
| [`code-reviewer`](./code-reviewer.md) | コードレビューを独立コンテキストで深掘りする | Read, Grep, Glob, Bash | sonnet | 旧 `code-reviewer.md` を簡素化(7 観点維持、出力フォーマット強化) |
| [`security-auditor`](./security-auditor.md) | セキュリティ観点でコード・依存・設定を独立に監査する | Read, Grep, Glob, Bash | opus | 旧 `security-reviewer.md` を改名 + 監査範囲拡張(supply-chain 含む) |
| [`doc-writer`](./doc-writer.md) | コード変更に伴うドキュメント更新を提案・適用する | Read, Write, Edit, Grep, Glob | haiku | 旧 `doc-writer.md` を継承 + apply モード追加 |
| [`refactor-planner`](./refactor-planner.md) | リファクタリング計画を立案する(実装はしない) | Read, Grep, Glob | opus | 旧 `refactor-planner.md` を継承 + 出力フォーマット強化 |
| [`explorer`](./explorer.md) | コードベースを独立コンテキストで探索し要約を返す | Read, Grep, Glob | haiku | 旧 `explorer.md` を継承 + 起動判断基準を明示 |
| [`research-summarizer`](./research-summarizer.md) | 外部資料を WebSearch / WebFetch で調査し要約を返す | WebSearch, WebFetch, Read | sonnet | **新規**(v3 マスタープラン由来。`explorer` と内外で対比) |

### Phase 3 予告 / v3 マスタープラン / 旧 agents との差分整理

| 候補 | Phase 3 予告 | v3 マスタープラン | 旧 agents | 採否 | 理由 |
|------|--------------|--------------------|-----------|------|------|
| `code-reviewer` | ◯ | ◯ | ◯ | **採用** | 全予告で一致 |
| `doc-writer` | ◯ | ◯ | ◯ | **採用** | 全予告で一致 |
| `refactor-planner` | ◯ | ◯ | ◯ | **採用** | 全予告で一致 |
| `security-reviewer` / `security-auditor` | ◯ | ◯(改名) | ◯ | **採用(改名)** | `security-audit` skill と命名整合(audit ↔ auditor) |
| `explorer` | ◯ | — | ◯ | **採用** | 内部探索は委譲頻度が高い、`research-summarizer` と相補 |
| `research-summarizer` | — | ◯ | — | **採用** | 外部調査専門、原典 URL 付き要約 |
| `test-runner` | ◯ | — | ◯ | **不採用** | Phase 7b の post-edit / post-stop hook が自動テストを担うため subagent 化の優位性が薄い。必要時に `skill-creation` 手順で追加可能 |
| `adr-drafter` | — | ◯ | — | **不採用** | Phase 4 `adr-writing` skill で著者ワークフローを支援できる。on-demand のドラフト生成は一回性が高く subagent の常設価値が低い |

## subagent と skill の責務分離マトリクス

| 領域 | subagent | skill | 違い |
|------|----------|-------|------|
| コードレビュー | `code-reviewer` | (なし、`/review` slash command と連動予定) | subagent = 独立コンテキストで深掘り、重大度別出力。tools 最小権限で書き換え不能 |
| セキュリティ | `security-auditor` | `security-audit` | skill = 著者向けセルフチェック / subagent = レビューア向け、別コンテキストで Critical/High/Medium 分類 |
| 依存関係 | (`security-auditor` 内で対応) | `dependency-review` | skill = 依存追加時の著者作業 / subagent = 既存依存の総点検と `bun audit` 実行 |
| ドキュメント追従 | `doc-writer` | `japanese-tech-writing` | skill = 文章作法、subagent = コード差分追従の提案 / 適用。出力文も skill の作法に従う |
| リファクタ | `refactor-planner` | (なし、将来 `refactor` skill 追加余地) | subagent = 計画専門、実装しない。段階的ステップ + テスト戦略まで出力 |
| コードベース探索 | `explorer` | (なし、将来 `investigate` skill 追加余地) | subagent = 大量探索を別コンテキストで実行、要約のみ親に返す |
| 外部調査 | `research-summarizer` | (なし) | subagent = WebSearch / WebFetch 主体、原典 URL 付き要約。本人手の Web 検索を圧縮 |
| ADR 起票 | (なし、Phase 4 で吸収) | `adr-writing` | skill のみで完結 |
| テスト実行 | (なし、hook 化) | `testing-typescript` / `testing-python` | skill = TDD 設計、Phase 7b の post-edit / post-stop hook が自動実行 |
| PR 説明 | (なし) | `pr-description` | skill のみ。subagent 化の必要性なし |
| commit | (なし) | `commit-conventional` | skill のみ。コミットは判断単位で人間 / メイン Claude が切る |

## frontmatter 規約

```markdown
  ---
  name        : <subagent-name>            # ファイル名(拡張子除く)と一致
  description : <50 字以内、改行禁止>       # いつこの subagent を呼ぶべきか
  tools       : [<必要最小限のツールのみ列挙>]  # YAML 配列形式
  model       : opus | sonnet | haiku       # practices/model-selection.md の判断基準
  ---
```

(上は例示のためインデント、実 subagent ファイルは行頭空白なし)

## v3 で追加した規約

- `tools` フィールドの**最小権限原則**を徹底(編集権限がない subagent は Edit/Write を含めない)
- 親エージェントへの**返却フォーマット**を本文に明記(レビュー結果の重大度別件数 + 指摘リスト等)
- 関連 **skill との違い**セクションを必須化(責務重複の防止)
- クロスレイヤー参照は**絶対パス** `~/ws/claude-system/<layer>/<file>` 形式([`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md))
- 1 ファイル 200 行以内

## tools の最小権限設計

| subagent | tools | 除外したもの | 理由 |
|----------|-------|--------------|------|
| `code-reviewer` | Read, Grep, Glob, Bash | Edit, Write | レビュー専門、コード書き換えはしない |
| `security-auditor` | Read, Grep, Glob, Bash | Edit, Write | 監査専門、修正はしない |
| `doc-writer` | Read, Write, Edit, Grep, Glob | Bash | doc に集中、shell 副作用は不要 |
| `refactor-planner` | Read, Grep, Glob | Edit, Write, Bash | 計画専門、実装はしない |
| `explorer` | Read, Grep, Glob | Edit, Write, Bash | 探索専門、編集も shell も不要 |
| `research-summarizer` | WebSearch, WebFetch, Read | Edit, Write, Grep, Glob, Bash | 外部 Web 専門、ローカルへの書き込み禁止 |

## 自己検証

新規 subagent 追加時、以下を通すこと:

```bash
# frontmatter 必須フィールド
for agent in adapters/claude-code/subagents/*.md; do
  base=$(basename "$agent")
  [ "$base" = "_index.md" ] && continue
  for field in name description tools model; do
    head -10 "$agent" | grep -q "^$field:" || echo "MISSING $field: $agent"
  done
done

# description 50 字以内
for agent in adapters/claude-code/subagents/*.md; do
  base=$(basename "$agent")
  [ "$base" = "_index.md" ] && continue
  desc=$(head -10 "$agent" | grep "^description:" | sed 's/^description: //')
  chars=$(echo -n "$desc" | wc -m)
  [ "$chars" -gt 50 ] && echo "OVER ($chars): $agent"
done

# 行数 200 以内
for agent in adapters/claude-code/subagents/*.md; do
  base=$(basename "$agent")
  [ "$base" = "_index.md" ] && continue
  lines=$(wc -l < "$agent")
  [ "$lines" -gt 200 ] && echo "WARN $agent is $lines lines"
done

# tools 目視
for agent in adapters/claude-code/subagents/*.md; do
  base=$(basename "$agent")
  [ "$base" = "_index.md" ] && continue
  echo "--- $base ---"
  head -10 "$agent" | grep "^tools:"
done
```

## 関連

- [`principles/01-context-economy.md`](~/ws/claude-system/principles/01-context-economy.md) — 委譲の選択基準
- [`principles/05-separation-of-concerns.md`](~/ws/claude-system/principles/05-separation-of-concerns.md) — 最小権限と境界
- [`practices/session-handoff.md`](~/ws/claude-system/practices/session-handoff.md) — 引き継ぎ / 委譲時の入出力
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — 各 subagent の `model` 選択
- [`adapters/claude-code/README.md`](~/ws/claude-system/adapters/claude-code/README.md) — Adapter 全体、クロスレイヤー参照のパス規約
- [`adapters/claude-code/user-level/skills/_index.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/_index.md) — skill 索引(重複防止のため対照)
