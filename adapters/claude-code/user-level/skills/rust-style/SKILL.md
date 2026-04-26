---
name: rust-style
description: Rust の所有権・エラー・clippy 規約
recommended_model: sonnet
---

# Rust Style(skeleton)

Rust の作法。本リポジトリ運用者の主要スタックではないため、**本 skill は最小骨子**として配置する。
言語非依存の規約は [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)。
本 skill を実プロジェクトで本格採用する際は、各セクションを実例ベースで肉付けすること(`skill-creation` の手順に従う)。

## 目的

`unwrap()` / `expect()` を最終手段に押し下げ、`Result` / `Option` で失敗ケースを型に乗せる。`clippy` の警告ゼロをデフォルトにする。

## いつ発動するか

- Rust で新規実装するとき
- 既存 Rust コードのレビューで `unwrap()` / `expect()` の濫用を見たとき
- `Cargo.toml` を新規作成 / 改訂するとき

## 手順(骨子)

### 1. プロジェクト初期化

- `cargo new --lib <name>` または `cargo new <name>`
- `Cargo.toml` の `[dependencies]` はバージョン固定(`foo = "1.2.3"`、`"1"` のような floating は避ける)
- workspace 化が必要なら `[workspace]` で複数クレート管理

### 2. エラーハンドリング

- 関数戻り値は `Result<T, E>` を基本に
- アプリケーション境界では `anyhow::Error`、ライブラリ境界では `thiserror` で固有 enum
- `?` 演算子で伝播
- `unwrap()` / `expect()` は**テスト・初期化定数・絶対に到達しない不変条件**のみ
- panic は本当に「これ以上続けるとデータが壊れる」状況だけ

### 3. 所有権 / 借用

- 関数引数は不要なら `&T`(借用)、所有権を渡す必要があるときだけ `T`
- ライフタイム明示は必要最小限(コンパイラの推論を信じる)
- `clone()` は最終手段、まず借用で済まないか検討

### 4. 静的解析・整形

```bash
cargo fmt          # 整形
cargo clippy --all-targets --all-features -- -D warnings  # 警告 = エラー扱い
cargo test         # テスト
```

- post-edit hook(Phase 6)で自動化

### 5. その他

- `unsafe` ブロックは**理由を必ずコメント**(`// SAFETY: ...`)
- macro_rules / proc_macro は Why が明確なときのみ
- 構造体は `#[derive(Debug, Clone, ...)]` を意識的に選ぶ(自動付与の累積を避ける)

## チェックリスト(骨子)

- [ ] `Cargo.toml` の依存はバージョン固定
- [ ] `unwrap()` / `expect()` の使用箇所がレビューで承認された範囲
- [ ] `cargo fmt` / `cargo clippy -- -D warnings` がエラー 0
- [ ] `unsafe` ブロックに `// SAFETY:` コメントがある

## アンチパターン

- `unwrap()` を「とりあえず」散らす(panic で本番停止)
- 全関数引数を `T`(所有権)で受け取り、呼び出し側に `clone()` を強要
- `clippy` の警告を `#[allow(...)]` で個別抑制(理由なし)

## 関連

- [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)
- [`adapters/claude-code/user-level/skills/skill-creation/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/skill-creation/SKILL.md) — 本 skeleton を肉付けする手順

## 状態

skeleton 配置のみ(2026-04-26 時点)。本格採用時に拡充する(本 skill 自体を `practices/coding-style-conventions.md` の言語別具体化として完成させる)。
