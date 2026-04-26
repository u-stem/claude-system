---
name: typescript-strict
description: TypeScript strict モード作法と型安全な実装パターン
recommended_model: sonnet
---

# TypeScript Strict 作法

TypeScript の strict モードを前提に、型安全と表現力を両立する作法。
言語非依存の規約は [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)、関心の分離原則は [`principles/05-separation-of-concerns.md`](~/ws/claude-system/principles/05-separation-of-concerns.md)。

## 目的

不正な状態を型で表現不可能にする(Parse, don't validate)。`as` / `any` / `@ts-ignore` を最終手段に押し下げ、ランタイムエラーを設計時にコンパイラへ移送する。

## いつ発動するか

- TypeScript で新規実装するとき
- 既存コードのレビューで `any` / `as` / `@ts-ignore` を見たとき
- 型定義の設計判断が必要なとき(union vs interface、branded type 採用判断 等)
- `tsconfig.json` を新規作成 / 改訂するとき

## 手順

### 1. tsconfig 必須設定

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "exactOptionalPropertyTypes": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,
    "moduleResolution": "bundler",
    "module": "ESNext",
    "target": "ES2022"
  }
}
```

`strict: true` だけでは不足(暗黙の `undefined` / 配列アクセス / overload 不整合等が残る)。上記 7 つを追加で有効化する。

### 2. `as` / `any` / `@ts-ignore` の取り扱い

- `as` 禁止(型ガード関数の中・JSON.parse 直後の Zod / Valibot 検証経由を除く)
- `any` 禁止(代わりに `unknown` を使い分岐で絞る)
- `@ts-ignore` 禁止、必要なら `@ts-expect-error` + 理由コメント(`// @ts-expect-error: <reason>`)。`@ts-expect-error` ならエラーが消えたときにコンパイラが教えてくれる
- 抑制を入れたら**理由をコメント必須**

### 3. 型ガードと表明(Parse, don't validate)

- 文字列・JSON・外部 I/O は**境界で 1 度だけ検証**して以降は型を信頼する
- 検証ライブラリ: `zod` / `valibot` / `arktype` のいずれか(プロジェクト統一)
- パターン:

```ts
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
});
type User = z.infer<typeof UserSchema>;

function parseUser(input: unknown): User {
  return UserSchema.parse(input);  // throws on invalid
}
```

### 4. ブランド型(Branded Types)

意味の異なる文字列・数値を型で区別する:

```ts
type UserId = string & { readonly __brand: 'UserId' };
type OrderId = string & { readonly __brand: 'OrderId' };

const id: UserId = 'usr_123' as UserId;  // 境界のみ as 許容
function findOrder(id: OrderId) { /* ... */ }

findOrder(id);  // ✗ コンパイルエラー(UserId と OrderId は非互換)
```

最小コストで「ID の取り違え」を防ぐ。

### 5. Discriminated Union で「不正状態を表現不可能」に

```ts
// 良くない: status と error/data の整合がコンパイラで保証されない
type Result = { status: 'ok' | 'error'; data?: T; error?: E };

// 良い: discriminated union
type Result<T, E> =
  | { status: 'ok'; data: T }
  | { status: 'error'; error: E };

function handle(r: Result<User, string>) {
  if (r.status === 'ok') {
    r.data.email;  // ✓ data あり
    // r.error;    // ✗ コンパイルエラー
  } else {
    r.error;       // ✓ error あり
  }
}
```

### 6. 全ケース網羅(default に頼らない)

```ts
type Status = 'pending' | 'success' | 'error';

function label(s: Status): string {
  switch (s) {
    case 'pending': return '...';
    case 'success': return 'OK';
    case 'error':   return 'NG';
    // default を書かない: Status に case 追加するとコンパイルエラーで気付ける
  }
}

// 網羅性を明示したい場合: never チェック
function exhaustive(s: Status): string {
  switch (s) {
    case 'pending': return '...';
    case 'success': return 'OK';
    case 'error':   return 'NG';
    default: { const _: never = s; throw new Error(`unreachable: ${_}`); }
  }
}
```

### 7. `import type` / `export type`(verbatimModuleSyntax)

- 型のみの import / export は `import type { Foo }` / `export type { Foo }` と書く
- `verbatimModuleSyntax` を有効化していると強制される

### 8. ES Modules + named export 優先

- `import { x } from '...'` の named export を優先(default export は最後の手段)
- ファイル冒頭の import は標準 → 外部 → 内部 → 相対の順でグルーピング(行間 1 行で区切る)

## チェックリスト

- [ ] `tsconfig.json` に strict + 上記 6 オプションが入っている
- [ ] `bunx tsc --noEmit` がエラー 0 で通る
- [ ] `as` / `any` / `@ts-ignore` の検索結果がレビューで承認された箇所のみ
- [ ] 抑制(`@ts-expect-error` 等)に理由コメントがある
- [ ] 境界(API レスポンス・Form input・JSON.parse 直後)で型検証が入っている
- [ ] 状態を表す型は discriminated union で「不正状態を表現不可能」になっている
- [ ] switch / if-else に `default` を頼らず網羅性をコンパイラに任せている
- [ ] 型のみの import / export は `import type` / `export type`

## アンチパターン

- `as Type` で警告を握りつぶす(後でランタイムエラーに化ける)
- `any` を「とりあえず」使う(型推論の連鎖が崩れる)
- ステータスフラグを複数の独立した boolean / optional で持つ(整合がコンパイラで保証されない)
- `default:` で全分岐を吸収し、union に case を追加してもコンパイラが警告しない
- `@ts-ignore` を理由なく散らす(エラーが消えたかも気付けない)
- 型と値で同名のシンボルを `import` し `verbatimModuleSyntax` で衝突させる

## 関連

- [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md) — 言語非依存のスタイル(命名・1 ファイル 1 概念・エラー本文)
- [`principles/05-separation-of-concerns.md`](~/ws/claude-system/principles/05-separation-of-concerns.md) — 不正な状態を型で表現不可能にする
- [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md) — 境界での検証
- [`adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md) — `Database` 型生成と `<Database>` への渡し方
- [`adapters/claude-code/user-level/skills/testing-typescript/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/testing-typescript/SKILL.md) — テスト戦略との整合
