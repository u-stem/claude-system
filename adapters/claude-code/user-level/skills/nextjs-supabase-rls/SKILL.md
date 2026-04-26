---
name: nextjs-supabase-rls
description: Supabase RLS ポリシーを設計・レビューする
recommended_model: opus
---

# Supabase RLS 設計

Row Level Security ポリシーの設計・レビュー専用 skill。
Next.js + Supabase の基本作法は別 skill `nextjs-supabase-base` を参照。
**RLS は原子性とセキュリティの両方が問われるため `recommended_model: opus`**(`practices/model-selection.md` 準拠)。

## 目的

Anon key 経由の全クエリが正しい行のみアクセス・変更できることを RLS で保証し、Service Role への依存を最小化する。

## いつ発動するか

- 新テーブルを作成するとき
- 既存テーブルにポリシーを追加 / 変更するとき
- 「Service Role を使えば動いた」コードを見たとき(RLS 設計漏れの兆候)
- 認証 / マルチテナンシー / 共有リソース系の機能を実装するとき

## 手順

### 1. 設計順序(必ずこの順)

1. **テーブル定義**(`create table ...`)
2. **RLS 有効化**(`alter table <t> enable row level security;`)を**必ず**直後に書く
3. **ポリシー作成**(`create policy ... on <t> for <op> ...`)
4. **ポリシーが無いと全行不可視**であることを認識(deny by default)

### 2. ポリシーの 4 操作で考える

| op | 想定パターン |
|----|--------------|
| `select` | 自分の行だけ見える / 共有招待がある行も見える |
| `insert` | `auth.uid() = user_id` を `with check` で強制 |
| `update` | `using` で対象行を絞り、`with check` で更新後行も絞る(両方必要) |
| `delete` | `using` で対象行を絞る |

`for all` で 4 つを 1 ポリシーに統合する選択肢もあるが、**変更頻度が異なる場合は分けたほうが安全**。

### 3. `auth.uid()` の使い方

```sql
create policy "select_own"
  on profiles
  for select
  to authenticated
  using (auth.uid() = user_id);
```

- `to authenticated` を必ず明示(`anon` を含めると未ログインからもアクセスされる)
- `auth.uid()` は `null` を返しうる(未ログイン時)。`= user_id` が `null = ...` となり常に false になる前提を理解する

### 4. マルチテナンシーは `tenants` / `memberships` テーブルで分離

```sql
create policy "select_org_data"
  on documents
  for select
  to authenticated
  using (
    org_id in (
      select org_id from memberships
      where user_id = auth.uid()
    )
  );
```

- サブクエリの中身は別途 RLS で守られている前提を**書面で**確認する(`memberships` テーブルにも RLS を設定)
- 再帰的なポリシー参照に注意(`memberships` ポリシーが `documents` を参照すると無限ループ)

### 5. テスト戦略

- ポリシーは Supabase の Studio で目視レビューでは不十分。**プログラマブルなテスト**を書く
- `pgTAP` または Supabase CLI の `supabase test db` で
  - User A としてログインして own row が見えること / 他人の row が見えないこと
  - User A が他人の row を update できないこと
  - 未ログインで何も見えないこと
- 各ポリシー追加 / 変更でテストを更新する(TDD)

### 6. Service Role の使用条件

**Service Role を使ってよい場面は限定的**:

- DB マイグレーション(Supabase CLI)
- cron / scheduled function でのバックグラウンド処理(ユーザーセッション無し)
- webhook 受信のサーバー側ハンドラ(外部から検証可能な署名で正当性を確認したうえ)

NG:

- API ルートでの「とりあえず Service Role で全部できるようにしておく」
- Client Component / Edge Runtime での Service Role 露出
- ユーザー操作の代理で「都合上」Service Role を使う(RLS 設計の負債)

### 7. レビュー観点

- 全テーブルで `rowsecurity = true` か確認:
  ```sql
  select schemaname, tablename, rowsecurity
    from pg_tables
   where schemaname = 'public' and rowsecurity = false;
  ```
- ポリシー無し + RLS 有効 = **全行不可視**(意図して空ポリシーにしているか確認)
- `to public` のポリシーが意図通りか(`anon` も含む)
- `using` と `with check` の両方が `update` に書かれているか

## チェックリスト

- [ ] 新テーブル作成と同時に `enable row level security` を書いた
- [ ] `select` / `insert` / `update` / `delete` の必要な op それぞれにポリシーがある
- [ ] `to authenticated` / `to anon` / `to public` を明示している
- [ ] `update` ポリシーに `using` と `with check` の両方がある
- [ ] マルチテナンシーは `memberships` テーブル経由で表現し、再帰参照を作っていない
- [ ] `pgTAP` または `supabase test db` でポリシーテストが書かれている
- [ ] Service Role の使用箇所が限定された場面のみで、Client / Edge には漏れていない
- [ ] `select ... rowsecurity = false` のクエリで漏れているテーブルがない

## アンチパターン

- テーブル作成して RLS を有効化し忘れる(全行誰でも読める)
- RLS を有効化したがポリシー未作成のまま運用(全行不可視で「動かない」原因に)
- `update` で `using` だけ書き `with check` を忘れる(更新後の行が他テナントに移動できる)
- `to public` を無自覚に使う(`anon` も含むため意図しないアクセス)
- Service Role で「全 RLS をバイパスして API を作る」(RLS 設計を放棄)
- ポリシーテストを書かず Studio の目視確認だけで済ます

## 関連

- [`adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/nextjs-supabase-base/SKILL.md) — クライアント分離 / Service Role 制限
- [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md) — 境界での検証、許可リスト方針
- [`practices/model-selection.md`](~/ws/claude-system/practices/model-selection.md) — RLS は原子性 / セキュリティ系で上位モデル推奨
