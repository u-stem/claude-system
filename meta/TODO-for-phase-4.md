# Phase 4 への申し送り TODO

このファイルは Phase 0.5 の棚卸しで判明した「Phase 4(共通 Skills)実装時に必ず対応すべき項目」を記録する場所。

## メモリアーキテクチャの ADR 化

旧 claude-settings には `docs/superpowers/specs/2026-04-01-long-term-memory-design.md` という設計記録があり、そこで以下が決定された:

- Memory MCP(知識グラフベース)は廃止
- `auto memory` + `episodic-memory` の 2 層構成に統一
  - **構造化知識**(ユーザー情報、フィードバック、設計判断): `auto memory` 経由で `MEMORY.md` + トピック別 `.md`
  - **会話検索**(過去セッションのセマンティック検索): `episodic-memory` プラグイン (Transformers.js + SQLite + sqlite-vec)

新 claude-system でもこの方針を継承するが、ADR 0002 方針(Public→Private リンク禁止)により、旧 spec を直接参照することはできない。代わりに **Phase 4 のタイミングで以下の ADR を新規作成する**:

### 作成対象

- **ファイル**: `meta/decisions/00NN-memory-architecture.md`(連番は採番時に確定。現状 ADR 0002 まで採番済みなので 0003 想定)
- **必須セクション**: `meta/decisions/README.md` の規約に従う
- **内容**:
  - **Status**: Accepted
  - **Date**: ADR 採択日
  - **Decider**: プロジェクトオーナー
  - **Context**: 旧 claude-settings で 3 つのメモリ機構(auto memory / Memory MCP / episodic-memory)が混在していた経緯。役割重複の解消が必要だった点。Memory MCP の限界(セマンティック検索なし、知識グラフは大量非構造化データに不向き、settings.json 外で管理される)
  - **Decision**: Memory MCP を採用せず、`auto memory` + `episodic-memory` の 2 層に統一する。各層の用途分担を表で明示する
  - **Alternatives Considered**: Memory MCP の継続採用、独自メモリ実装、外部サービス(例: Mem0 等)の採用
  - **Consequences**:
    - Positive: 役割が明確化、ローカル完結(外部 API 不要)、settings.json で完結する
    - Negative: episodic-memory は Transformers.js のロード時間あり、初回 sync コスト
    - Neutral: 旧 Memory MCP からのデータ移行は行わない(過去データの価値が低いため捨てる判断、ADR で明示)
  - **Related**: ADR 0001(anonymity-policy)、ADR 0002(public-private-boundary)、`meta/migration-inventory.md`

### 取り込みのチェックリスト

- [ ] ADR `00NN-memory-architecture.md` を作成
- [ ] `meta/decisions/README.md` の既存 ADR テーブルに新行を追加
- [ ] `adapters/claude-code/user-level/CLAUDE.md`(Phase 3 で作成)のメモリセクションから新 ADR へリンクを張る
- [ ] `adapters/claude-code/user-level/settings.json` テンプレートで `enabledPlugins` に `episodic-memory@superpowers-marketplace` が含まれていることを確認
- [ ] このファイル `meta/TODO-for-phase-4.md` 自体を削除する(Phase 4 終了時)
