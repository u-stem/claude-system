---
name: testing-typescript
description: TypeScript のテスト戦略(Vitest / Bun test / Jest)
recommended_model: sonnet
---

# TypeScript Testing

TypeScript のテストフレームワーク選定・実行・モック作法。
抽象戦略は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md)、TDD の原則は [`principles/`](~/ws/claude-system/principles/) を参照。

## 目的

`bun test` を第一選択にしつつ、プロジェクト構成に応じた選定基準を持ち、TDD サイクル(Red/Green/Refactor)を回す。

## いつ発動するか

- TypeScript で新機能を実装するとき(テストから書く)
- バグ修正時(再現テストから書く)
- リファクタリング時(緑のテストを前提に構造を変える)
- 新規プロジェクトでテストフレームワークを選定するとき

## 手順

### 1. フレームワーク選定

| ランナー | 適用 | 補足 |
|----------|------|------|
| `bun test` | bun ベースの新規プロジェクト | 速い、Jest 互換 API、組み込み |
| Vitest | Vite / Next.js プロジェクト | Vite と統合、ESM ネイティブ、watch が高速 |
| Jest | レガシー Jest 資産が多い場合 | Babel/SWC 経由の TS、設定の重さに注意 |
| Playwright | E2E | 別軸、本 skill の対象外(別 e2e skill 候補) |

迷ったら `bun test` → Vitest の順。

### 2. ファイル配置

- ソースの隣に置く: `foo.ts` + `foo.test.ts`(`__tests__/` ディレクトリは使わない)
- E2E のみ `e2e/` 配下にまとめる
- フィクスチャは `<scope>.fixtures.ts` の隣接配置

### 3. 命名

```ts
describe('parseUser', () => {
  it('returns User when input has valid id and email', () => { /* ... */ });
  it('throws ValidationError when id is missing', () => { /* ... */ });
});
```

- `describe` は対象、`it` は「対象が条件下でどう動くか」を英語で記述
- 実装関数名で命名しない、振る舞いベースで

### 4. Arrange-Act-Assert

```ts
it('returns 0 when items is empty', () => {
  // Arrange
  const items: Item[] = [];

  // Act
  const total = sumPrices(items);

  // Assert
  expect(total).toBe(0);
});
```

- 1 テスト 1 アサーション(`expect()` を 1 回)
- テスト内に if / for を書かない(分岐は別テストに)

### 5. モック方針

- 純粋ロジックはモックなし(unit)
- 外部 I/O(DB / HTTP / file)を含む処理は**統合テストでは実物**を使う(`practices/testing-strategy.md` 「境界ではモックしない」)
- 外部 SaaS への呼び出しのみモック(MSW / nock)
- Supabase は `@supabase/supabase-js` をモックせず、ローカル Supabase(`supabase start`)で実行
- Date / Random はテスト時に固定可能な依存注入で書く(`vi.useFakeTimers()` 等は最終手段)

### 6. 実行コマンド

```bash
# bun
bun test                       # 全実行
bun test src/foo.test.ts       # 単体
bun test --watch               # watch
bun test --coverage            # カバレッジ

# Vitest
bunx vitest run                # 1 回実行
bunx vitest                    # watch
bunx vitest --coverage

# Jest
bunx jest --runInBand          # CI で安定させたい場合
```

### 7. CI / hook 連携

- post-edit hook(Phase 6)で affected ファイルのテストのみ実行(monorepo は filter)
- post-stop hook(Phase 6)で `git status` から変更パッケージのテストを実行
- `failure-log.jsonl` に失敗を記録(Phase 7b の `log-failure.sh`)
- `tail -150` でテスト出力を切り詰める(Phase 7b の `filter-test-output.sh`)

### 8. 型と整合

- テストファイルも `tsconfig` の strict 配下(別 tsconfig で緩めない)
- `expect(x).toBe(y)` の型不一致をコンパイラが拾う(`@ts-ignore` でテストをすり抜けさせない)
- `vi.mocked(fn)` / `jest.mocked(fn)` で型安全な mock 操作

## チェックリスト

- [ ] テストはソースの隣に配置(`foo.ts` + `foo.test.ts`)
- [ ] 命名が振る舞いベース(実装関数名で命名していない)
- [ ] 1 テスト 1 アサーション、Arrange-Act-Assert
- [ ] 統合テストで境界をモックしていない(実物使用)
- [ ] `skip` / `xit` で逃げているテストがない
- [ ] テスト内に if / for を書いていない
- [ ] `bun test` / `vitest run` / `jest` が緑
- [ ] tsconfig の strict 配下でテストも型エラー 0

## アンチパターン

- 失敗するテストを書かずに実装から始める(Red を踏まないと Green の意味が薄れる)
- 1 テストで複数の振る舞いを検証(壊れたとき原因特定不能)
- 実装関数名でテスト命名(リファクタで一斉に壊れる)
- 統合テストで DB / HTTP をモック(境界の挙動が検証されない)
- `skip` / `xit` で失敗テストを残す(直すか削除する)
- `expect(true).toBe(true)` 等のトートロジー
- カバレッジ %% を目標化して意味のないテストを濫造する

## 関連

- [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) — 抽象戦略(TDD サイクル / 境界 / 命名)
- [`adapters/claude-code/user-level/skills/typescript-strict/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/typescript-strict/SKILL.md) — 型運用との整合
- [`adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md) — Supabase テストでローカル CLI を使う方針
