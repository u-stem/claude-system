---
name: nextjs-supabase-base
description: Next.js + Supabase の基本作法に従って実装する
recommended_model: sonnet
---

# Next.js + Supabase 基本作法

主要スタック(Next.js App Router + Supabase + Vercel + TypeScript)で**新規実装・既存改修**を行うときの基本作法。
RLS の詳細は別 skill `nextjs-supabase-rls` を参照。

## 目的

Next.js + Supabase の組み合わせで、よくある事故(クライアント / サーバー混線、Service Role の漏洩、未型付け、useEffect での fetch、`'use client'` の濫用)を回避する。

## いつ発動するか

- Next.js + Supabase 構成のプロジェクトで実装するとき
- ルート(page / layout / route handler / server action)を追加するとき
- Supabase クライアントを作成・使用するとき
- データ取得・更新ロジックを書くとき

## 手順

### 1. クライアント分離

Supabase クライアントは**用途別に明確に分離**して作成する:

| 種別 | 配置 | 用途 | 鍵 |
|------|------|------|----|
| Browser client | `lib/supabase/client.ts` | Client Component(`'use client'`) | `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
| Server client(cookies 連携) | `lib/supabase/server.ts` | Server Component / Server Action / Route Handler | `NEXT_PUBLIC_SUPABASE_ANON_KEY` + cookies |
| Admin client | `lib/supabase/admin.ts` | サーバー側の特権操作のみ | `SUPABASE_SERVICE_ROLE_KEY`(**Client / Edge に絶対漏らさない**) |

`@supabase/ssr` の `createServerClient` / `createBrowserClient` を使用する(`@supabase/supabase-js` の直接使用は最小限)。

### 2. データ取得の優先順

1. **Server Component で fetch** が第一選択(`async function Page()` 内で `await supabase.from(...)`)
2. Server Action でミューテーション(`use server` ディレクティブ)
3. Client Component の `useEffect` で fetch は**避ける**(SWR / React Query を使うか、Server Component に持ち上げる)
4. Realtime / 双方向同期が必要な場合のみ Browser client + subscribe

### 3. `'use client'` の境界

- デフォルトは Server Component(`'use client'` を書かない)
- インタラクション・useState・useEffect が必要な「葉」コンポーネントだけに `'use client'` を付ける
- `'use client'` のコンポーネントから子に Server Component を渡したい場合は children prop で受ける

### 4. 型生成

```bash
bunx supabase gen types typescript --linked > lib/database.types.ts
```

- `Database` 型を `createClient<Database>(...)` に渡し、`from('<table>')` の補完を有効化する
- 型を更新したら `bunx tsc --noEmit` で型エラーを確認

### 5. RLS の前提

- 全テーブルで RLS を **enabled**(`alter table ... enable row level security;`)
- Anon key で実行されるクエリは RLS によって防御される前提で設計する
- Service Role を使うのはマイグレーション・cron・webhook など限定された場面のみ
- 詳細は `nextjs-supabase-rls` skill を参照

### 6. 環境変数の取り扱い

- `NEXT_PUBLIC_*` は**バンドルに焼き込まれる**前提(クライアントから読める)
- `SUPABASE_SERVICE_ROLE_KEY` は `NEXT_PUBLIC_` を絶対付けない
- `.env.local` はコミットしない(settings.json で `Edit/Write(./.env*)` deny 済み)
- Vercel デプロイ時は Project Settings → Environment Variables に登録、`vercel env pull` でローカル同期

### 7. エラーハンドリング

- `const { data, error } = await supabase.from(...).select(...)` の `error` を必ず分岐
- error を握りつぶさず、ユーザー向けには汎用メッセージ、ログには `error.code` / `error.message` / `error.details` を出力
- 認証失敗(`PGRST301` 等)とビジネスロジック失敗を区別する

## チェックリスト

- [ ] Browser / Server / Admin の 3 種クライアントが正しく分離されている
- [ ] `SUPABASE_SERVICE_ROLE_KEY` が Client Component / Edge Runtime / `NEXT_PUBLIC_*` に漏れていない(grep で確認)
- [ ] データ取得は Server Component / Server Action を優先している
- [ ] `'use client'` が必要な葉だけに付いている
- [ ] `Database` 型で型補完が効いている
- [ ] RLS が全テーブルで有効化されている(`select ... from pg_tables where rowsecurity = false;` で漏れチェック)
- [ ] Supabase クエリの `error` を握りつぶしていない
- [ ] `.env.local` がコミット差分に含まれていない

## アンチパターン

- 1 つのクライアントで Browser / Server / Admin を兼ねる(Service Role 漏洩リスク)
- Client Component の `useEffect` で Supabase fetch(SSR の利点を捨てる)
- 全コンポーネントに `'use client'` を付ける(Server Component の意義を失う)
- RLS を無効化したまま運用する
- Supabase の error を `_` で破棄する
- Service Role を Edge Function に渡す(最小権限違反)

## 関連

- [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md) — 境界での検証、許可リスト方針
- [`practices/secrets-handling.md`](~/ws/claude-system/practices/secrets-handling.md) — 環境変数の取り扱い
- [`adapters/claude-code/user-level/skills/nextjs-supabase-rls/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/nextjs-supabase-rls/SKILL.md) — RLS 詳細(Tier 2)
- [`adapters/claude-code/user-level/skills/typescript-strict/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/typescript-strict/SKILL.md) — 型運用
