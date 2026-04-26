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

## 言語別コーディングスタイルの能力単位化

Phase 2 の `practices/coding-style-conventions.md` は「言語非依存の抽象部分」のみを記述した(命名、ファイル粒度、エラー本文の 3 要素、Why コメント、過剰装飾の禁止、デッドコード削除、抑制の最終手段化)。
旧資産にあった**特定言語の構文ガイド**は適応層の能力単位として Phase 4 で整備する。

### 対象

- **TypeScript**
  - ES Modules、分割代入、型注釈、`async/await` の使い分け
  - default export より named export 優先
  - `any` 型の乱用禁止、型抑制の最終手段化
  - 整形・静的解析・型検査の標準コマンド(言語固有の具体ツール)
- **Python**
  - 型ヒント、f-string、リスト内包表記
  - 整形・静的解析・型検査の標準コマンド
- **Rust**
  - 静的解析準拠、`Result`/`Option` の使い分け、`unwrap()` 禁止
  - 整形・静的解析の標準コマンド
- **Go**
  - 整形ツール準拠、エラーハンドリング必須、インターフェースは使用側で定義
  - 整形・静的解析の標準コマンド

### 取り込み方針

- 言語別に独立した能力単位として配置
- 各能力単位は段階的開示の入口(短い説明)と詳細(具体規則・コマンド)を分ける
- 共通する抽象規則(命名、ファイル粒度、エラー本文、Why コメント等)は `practices/coding-style-conventions.md` に既出のため重複を作らない。能力単位側はそれを参照する
- 各能力単位から `practices/coding-style-conventions.md` へのリンクを貼る

### チェックリスト

- [ ] TypeScript 用の能力単位を作成
- [ ] Python 用の能力単位を作成
- [ ] Rust 用の能力単位を作成
- [ ] Go 用の能力単位を作成
- [ ] 各能力単位から `practices/coding-style-conventions.md` への参照を貼る

## テスト戦略の言語別具体化

Phase 2 の `practices/testing-strategy.md` は TDD サイクル + 振る舞いベース命名 + 1 アサーション 1 テスト + Arrange-Act-Assert + 境界選択(unit/integration/e2e) + テストデータ規約 + 禁止パターンを抽象化した。
特定言語のテストフレームワーク選定・実行コマンド・モック手法は Phase 4 の能力単位として扱う。

### 対象

- 各言語のテストフレームワーク選定基準
- テストランナー実行コマンドの統一インタフェース(言語自動判別)
- モック・スタブ・フィクスチャの言語別書き方

### チェックリスト

- [ ] テスト実行能力単位の設計(言語自動判別)
- [ ] 各言語向けの能力単位を整備
- [ ] 各能力単位から `practices/testing-strategy.md` への参照を貼る
