---
name: security-audit
description: 実装変更や依存追加に対するセキュリティ観点のレビュー
recommended_model: opus
---

# Security Audit

実装変更・依存追加・PR レビュー時のセキュリティ観点チェック skill。
抽象は [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md) と [`practices/supply-chain-hygiene.md`](~/ws/claude-system/practices/supply-chain-hygiene.md)。
詳細レビューは subagent `security-auditor`(Phase 5)に委譲する選択肢もある。

## 目的

入力検証 / 認証認可 / 機密情報 / 依存関係の 4 軸でリスクを洗い出し、Critical 問題を実装段階で潰す。

## いつ発動するか

- 外部入力を受ける箇所(API ルート / Server Action / form / webhook 受信)を実装するとき
- 認証・認可ロジックを書くとき
- 環境変数・設定ファイルを追加 / 変更するとき
- パッケージを追加 / バージョン更新するとき
- 既存実装をセキュリティ観点でレビューするとき

## 手順

### 1. 入力検証(境界での検証)

- システム境界(ユーザー入力 / API リクエスト / ファイル読み込み)で型検証(Zod / Valibot)を実施
- 拒否リスト(blacklist)より許可リスト(whitelist)を選ぶ
- 出力先に応じたサニタイズ:
  - HTML レンダリング → フレームワークの組み込みエスケープ(React は default で安全、`dangerouslySetInnerHTML` は許可リスト経由)
  - SQL → parameterized query(Supabase / Prisma の標準 API、生 SQL は `sql.identifier()` 経由)
  - シェルコマンド → 配列形式で渡す(`shell: true` 禁止)
  - ファイルパス → `path.resolve()` で正規化し、期待ディレクトリ内に収まることを確認

### 2. 認証・認可

- Supabase 系: RLS で防御(別 skill `nextjs-supabase-rls`)
- Server Action / Route Handler の冒頭で**毎回 `auth.getUser()` で検証**(セッション cookie だけ信用しない)
- Anonymous なエンドポイントとそうでないものを意図的に分離(`/api/public/*` など命名で明示)

### 3. 機密情報の取り扱い

- ハードコード禁止(`grep -r "sk-" "$pwd" --include='*.ts' --include='*.tsx'` 等で確認)
- `.env*` はコミット禁止(settings.json で deny 済み)
- `NEXT_PUBLIC_*` は**バンドルに焼き込まれる**ため Service Role / DB 接続文字列に絶対付けない
- ログに API キー / セッション cookie / パスワードを出力しない
- 誤って公開した場合は**ローテーション**(削除しても git 履歴に残るため)

### 4. 依存関係

- パッケージ追加時はバージョンを固定:
  - `bun add foo@1.2.3`(`bun add foo` の floating range は使わない)
  - 例外: dev tooling で固定が運用負荷を上回る場合のみ
- 新規追加前に確認:
  - パッケージ名のスペル(typosquatting 対策)
  - npm / PyPI のダウンロード数(週間 1000 以上が目安)
  - メンテナンス状況(最終リリース、open issue 数)
  - 既知の脆弱性(`bun audit` / `npm audit` / `pip-audit`)
- 公開から `PACKAGE_MIN_AGE_DAYS`(既定 7 日)以内のパッケージは Phase 7b の hook でブロックされる
- ロックファイル(`bun.lockb` / `pnpm-lock.yaml` / `package-lock.json` / `uv.lock` / `Cargo.lock` / `go.sum`)が**意図せず**変わったらコミット前に調査
- MCP サーバーのバージョン固定(template の `mcpServers.*.args`)、更新は `/update-check` で意図的に
- `npx` / `bunx` / `uvx` はバージョン未指定で本番コンテキスト実行禁止

### 5. セキュリティ機能の「一時的」無効化禁止

- linter / type checker / test の skip / `eslint-disable` / `@ts-ignore` での回避は最終手段
- 必要なら理由をコメント、Issue 化して期日を決める
- 「あとで直す」TODO は禁止([`principles/02-decision-recording.md`](~/ws/claude-system/principles/02-decision-recording.md))

## チェックリスト

- [ ] 外部入力箇所で Zod / Valibot 等の型検証が走っている
- [ ] SQL は parameterized、シェルは配列形式、HTML はエスケープ経由
- [ ] Server Action / Route Handler で `auth.getUser()` を冒頭で確認している
- [ ] `NEXT_PUBLIC_*` に Service Role / DB 接続文字列が混入していない
- [ ] `git diff --cached` で `.env*` / API キー literal が含まれていない
- [ ] 新規依存はバージョン固定 + ダウンロード数 / メンテ状況確認済み
- [ ] `bun audit` / `npm audit` で High 以上の指摘なし
- [ ] ロックファイル変更が意図したものになっている
- [ ] linter / type checker の抑制に理由コメントがある(`@ts-expect-error: <reason>`)

## 委譲判断

- レビュー対象が**変更行 200 行超 or 5 ファイル超**なら subagent `security-auditor`(Phase 5)に委譲してメインコンテキストを保護(`principles/01-context-economy.md`)
- 委譲時は「対象 PR 番号 / 変更ファイル / 重点観点」を明示

## 関連

- [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md) — 境界検証、許可リスト
- [`practices/supply-chain-hygiene.md`](~/ws/claude-system/practices/supply-chain-hygiene.md) — 依存関係、typosquatting 防御
- [`practices/secrets-handling.md`](~/ws/claude-system/practices/secrets-handling.md) — 機密の取り扱い
- [`adapters/claude-code/user-level/skills/dependency-review/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/dependency-review/SKILL.md) — 依存追加時の専用フロー(Tier 3)
