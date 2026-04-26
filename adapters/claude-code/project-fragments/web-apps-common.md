# Web 系プロジェクト共通指針

Web 系プロジェクト(Next.js / SvelteKit / Remix / Vue 系等)の**フレームワーク独立**な共通指針。
特定スタックの作法は別 skill / 別 fragment で扱う。

## レンダリング戦略

- **Server-side レンダリングを第一選択**(SSR / SSG / ISR)。Client-side fetch は次善
- データ取得は Server Component / loader / Server Action 等の**サーバー側 API**で行う。Client の `useEffect` での fetch は最終手段
- `'use client'` / `<script>` ブロックは**インタラクションが必要な葉**だけに付ける
- 認証必須ページは middleware / route guard でリダイレクト、Client 側のチェックだけに頼らない

## アクセシビリティ(a11y)

- セマンティック HTML を優先(`<button>` `<nav>` `<main>` `<article>` 等)、`<div onClick>` を作らない
- すべてのインタラクション要素にキーボード操作を確保(Tab 移動 / Enter/Space で発火 / Esc でモーダル閉じる)
- 画像に `alt` 属性、装飾画像は `alt=""`
- color contrast WCAG AA(4.5:1)以上、color-only での情報伝達を避ける
- フォームは `<label>` を必ず関連付け(`for` / `htmlFor`、もしくは `<label>` でラップ)
- ARIA 属性は最終手段、native semantics で表現できないときのみ使う

## Web Vitals / パフォーマンス

- LCP(Largest Contentful Paint) < 2.5s、CLS(Cumulative Layout Shift) < 0.1、INP(Interaction to Next Paint) < 200ms
- 画像は最適化フォーマット(WebP / AVIF)、`width` / `height` で intrinsic size 指定して CLS 抑制
- フォントは `font-display: swap`、preload + subset
- JS bundle は code splitting、route 単位での lazy load
- third-party script は最小限、`<script defer>` または lazy 化

## SEO / メタデータ

- 各ルートで `<title>` `<meta name="description">` `<link rel="canonical">` を必ず設定
- OGP / Twitter Card メタタグを設定(SNS 共有時の表示)
- `robots.txt` / `sitemap.xml` を本番環境で生成
- 多言語サイトは `hreflang` を正しく設定

## セキュリティ

- HTTPS 必須、HSTS ヘッダー
- CSP(Content-Security-Policy)で XSS / clickjacking を防御、`unsafe-inline` を避ける
- Cookie は `Secure; HttpOnly; SameSite=Lax`(認証 cookie は Strict)
- ユーザー入力は**境界で**検証(Zod / Valibot)、レンダリング前にエスケープ
- 詳細は `~/ws/claude-system/adapters/claude-code/user-level/skills/security-audit/SKILL.md` 参照

## 推奨 skill / subagent(Web 系で頻出)

- 実装時: `nextjs-supabase-base`(Next.js + Supabase の場合)、`typescript-strict`
- レビュー時: `code-reviewer` subagent + `security-auditor` subagent
- doc 追従: `doc-writer` subagent
- テスト: `testing-typescript` skill

## 関連

- [`principles/05-separation-of-concerns.md`](~/ws/claude-system/principles/05-separation-of-concerns.md) — 境界での検証
- [`practices/secure-coding-patterns.md`](~/ws/claude-system/practices/secure-coding-patterns.md)
- [`adapters/claude-code/user-level/skills/security-audit/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/security-audit/SKILL.md)
