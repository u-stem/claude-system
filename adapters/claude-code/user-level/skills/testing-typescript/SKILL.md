---
name: testing-typescript
description: TypeScript のテスト戦略(Vitest / Bun test / Jest)
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

### 2. 命名と基本構造

```ts
describe('parseUser', () => {
  it('returns User when input has valid id and email', () => { /* ... */ });
  it('throws ValidationError when id is missing', () => { /* ... */ });
});
```

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

- `describe` は対象、`it` は振る舞いを英語で記述(抽象戦略は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md))
- 1 テスト 1 アサーション(`expect()` を 1 回)

### 3. モック方針

一般戦略は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) を参照。TypeScript 固有：

- 外部 SaaS への呼び出しのみモック(MSW / nock)
- Supabase は `@supabase/supabase-js` をモックせず、ローカル Supabase(`supabase start`)で実行
- Date / Random は依存注入で固定可能に設計する(`vi.useFakeTimers()` 等は最終手段)

### 4. 実行コマンド

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

### 5. CI / hook 連携

- post-edit hook(Phase 6)で affected ファイルのテストのみ実行(monorepo は filter)
- post-stop hook(Phase 6)で `git status` から変更パッケージのテストを実行
- `failure-log.jsonl` に失敗を記録(Phase 7b の `log-failure.sh`)
- `tail -150` でテスト出力を切り詰める(Phase 7b の `filter-test-output.sh`)

### 6. 型と整合

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

## アンチパターン(TypeScript 固有)

一般的なアンチパターンは [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) を参照。TypeScript 特有の陥りやすい例：

- 型エラーを無視して `@ts-ignore` を散らす。テスト本体も strict tsconfig の対象に置く
- モック内で型ガードが甘いため、モックが実装と別の引数型を受けている(テストが通ってもランタイムで失敗)

## 関連

- [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) — 抽象戦略(TDD サイクル / 境界 / 命名)
- [`adapters/claude-code/user-level/skills/typescript-strict/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/typescript-strict/SKILL.md) — 型運用との整合
- [`adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md) — Supabase テストでローカル CLI を使う方針
