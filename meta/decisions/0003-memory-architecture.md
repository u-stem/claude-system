# ADR 0003: Memory Architecture for claude-system

- **Status**: Accepted
- **Date**: 2026-04-26
- **Decider**: プロジェクトオーナー

## Context

旧 claude-settings 期に、AI セッションの「記憶」を担う機構が **3 種類混在**していた:

1. **`auto memory`**: ハーネス側の構造化知識ストア(`MEMORY.md` + トピック別 `.md` ファイル)。ユーザー情報・設計判断・フィードバック等を明示的に保存
2. **`Memory MCP`**: 知識グラフベースの MCP サーバー(`mcp-memory` 系)。ノード・エッジ構造で長期記憶を保持
3. **`episodic-memory` プラグイン**: 過去会話を Transformers.js + SQLite + sqlite-vec でセマンティック検索する仕組み

3 機構が共存することで以下の問題が生じていた:

- **役割重複**: 「保存先がどれか」を毎回判断する必要があり、保存・参照のコストが上がる
- **`Memory MCP` の限界**:
  - セマンティック検索が無く、ノード名・タグ完全一致での参照に縛られる
  - 知識グラフは少量の関係性表現には強いが、大量の非構造化会話履歴には不向き
  - settings.json の管轄外で別途管理が必要(MCP サーバー設定 + データ実体ファイル)、可搬性が低い
- **メンテナンス負荷**: 3 機構それぞれにバックアップ・同期・移行手順が必要

旧 `~/ws/claude-settings/docs/superpowers/specs/long-term-memory-design.md`(ADR 0002 方針により本 ADR には URL を貼らない)で、`Memory MCP` を廃止し `auto memory` + `episodic-memory` の 2 層に統一する設計判断が下された。本 ADR はその判断を新システムに**新規 ADR として再採択**するものである(旧 spec は Private リソースで参照不能のため、Public な本 ADR を唯一の真実源とする)。

## Decision

claude-system では **`auto memory` + `episodic-memory` の 2 層**を記憶アーキテクチャとして採用する。
**`Memory MCP` は採用しない**。

### 各層の用途分担

| 層 | 用途 | 実体 | アクセス手段 |
|----|------|------|--------------|
| `auto memory` | 構造化知識(ユーザー情報・フィードバック・設計判断・参照先) | `MEMORY.md` + トピック別 `.md` ファイル(`~/.claude/projects/<scope>/memory/` 配下) | LLM が直接 Read / Write、毎セッションで `MEMORY.md` がコンテキストにロードされる |
| `episodic-memory` | 過去会話のセマンティック検索 | SQLite + sqlite-vec によるベクトルインデックス(プラグイン側が管理) | プラグイン提供の検索 API(`mcp__plugin_episodic-memory_episodic-memory__search` 等) |

### 振り分けルール(オペレーション)

- 「**覚えておいて**」「これは記録して」と明示要求された情報 → `auto memory` に保存
- ユーザーの役割・好み・繰り返される指示 → `auto memory`(user / feedback タイプ)
- プロジェクトの状況・進行中の意思決定 → `auto memory`(project タイプ)
- 外部システムへのポインタ → `auto memory`(reference タイプ)
- 「**前に話した X は?**」「以前どう解決した?」 → `episodic-memory` で検索
- 過去のデバッグ手順・既出のソリューション → `episodic-memory` で検索

### 実装上の取り込み

- `adapters/claude-code/user-level/settings.json.template` の `enabledPlugins` で `episodic-memory@superpowers-marketplace: true` を有効化(Phase 3 で実装済み)
- `Memory MCP` は `mcpServers` セクションに**含めない**(template に記述しない)
- ユーザーレベル CLAUDE.md(`adapters/claude-code/user-level/CLAUDE.md`)の `## 9. メモリ運用` で本 ADR への参照を保持

## Alternatives Considered

| 代替案 | 採否 | 理由 |
|--------|------|------|
| `Memory MCP` の継続採用(3 機構併存) | 不採用 | 役割重複によるコスト超過、`Memory MCP` の構造的限界(セマンティック検索不在、settings.json 外管理) |
| `auto memory` のみ(`episodic-memory` 不採用) | 不採用 | 過去会話の自由文検索ができず、「前にどう解決した?」が再現できない。`episodic-memory` の置換コストが高い |
| `episodic-memory` のみ(`auto memory` 不採用) | 不採用 | 構造化知識(ユーザー情報・設計判断)は意図的な分類保存が必要。会話インデックスから毎回再構成するのは情報損失リスクが大きい |
| 外部 SaaS(Mem0 等)に置換 | 不採用 | Public/Private 境界が曖昧化、API キー管理コスト、ローカル完結性の喪失 |
| 独自メモリ実装 | 不採用 | 既存プラグインが要件を満たすため、独自実装の保守負荷を負う合理性がない |

## Consequences

### Positive

- 役割が明確化し「どこに保存するか」「どこから参照するか」を都度判断する負荷が下がる
- すべてローカル完結(外部 API 不要)、Public/Private 境界が侵されない
- `settings.json` の `enabledPlugins` で完結し、別途のセットアップが不要
- バックアップ対象が 2 機構に絞られ、移行・診断が単純化する

### Negative

- `episodic-memory` は Transformers.js のロード時間がセッション初期に発生する(現状 Opus 4.7 期で実用範囲)
- 初回 sync(過去会話のインデックス構築)に一定のコストがかかる
- `Memory MCP` で扱っていた「明示的な関係性グラフ」の表現力は失われる(必要になれば代替を別途検討する)

### Neutral

- 旧 `Memory MCP` のデータは**移行しない**(過去データの再利用価値が低く、移行コストが上回るため捨てる判断)
- `auto memory` のディレクトリ構成はハーネス(Claude Code)側の現行運用に従う(本システム側で構造を強制しない)
- `episodic-memory` プラグインのバージョン更新は通常の plugin 更新フロー(`/update-check` 等、Phase 4 以降の `update-check` skill 参照)に従う

## Related

- [ADR 0001](./0001-anonymity-policy.md): Anonymity Policy
- [ADR 0002](./0002-public-private-boundary.md): Public/Private Boundary(本 ADR が旧 spec への直接参照を行わない理由の根拠)
- [`adapters/claude-code/user-level/settings.json.template`](../../adapters/claude-code/user-level/settings.json.template) — `enabledPlugins.episodic-memory@superpowers-marketplace`
- [`adapters/claude-code/user-level/CLAUDE.md`](../../adapters/claude-code/user-level/CLAUDE.md) — `## 9. メモリ運用` セクション
- `meta/migration-inventory.md`(Phase 0.5)— 旧 spec の取り込み判断(C 参考、転記しない)
