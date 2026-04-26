---
name: go-style
description: Go の整形・エラー処理・インターフェース規約
recommended_model: sonnet
---

# Go Style(skeleton)

Go の作法。本リポジトリ運用者の主要スタックではないため、**本 skill は最小骨子**として配置する。
言語非依存の規約は [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)。
本 skill を実プロジェクトで本格採用する際は、各セクションを実例ベースで肉付けすること(`skill-creation` の手順に従う)。

## 目的

`gofmt` / `goimports` でスタイル議論を消し、`if err != nil { return err }` の規律でエラーを必ず処理する。インターフェースは利用側で定義し、実装側はそれを意識しない。

## いつ発動するか

- Go で新規実装するとき
- 既存コードのレビューでエラー無視・interface 定義位置の問題を見たとき
- `go.mod` を新規作成 / 改訂するとき

## 手順(骨子)

### 1. プロジェクト初期化

- `go mod init <module-path>`
- 依存追加は `go get <pkg>@<version>`(バージョン固定)
- `go.sum` は commit、ロックファイル diff を毎回確認

### 2. エラーハンドリング

- 戻り値の最後に `error` を返すのが慣例
- 呼び出し側は**必ず** `if err != nil { return ... }` で処理
- エラー無視(`_ = ...`)は**理由をコメント必須**
- ラップは `fmt.Errorf("context: %w", err)`(`%w` で wrapping)
- カスタムエラーは `errors.Is` / `errors.As` で判定可能に
- `panic` は init / 不可逆な不変条件のみ

### 3. インターフェース

- インターフェースは**利用側のパッケージで定義**(実装側で先に定義しない)
- 「accept interfaces, return concrete types」の原則
- 1 メソッドのインターフェースを優先(`io.Reader` / `io.Writer` 形式)

### 4. 命名

- パッケージ名は短く小文字(`fmt` / `http` / `bytes`)
- exported は `CapWords`、unexported は `camelCase`
- ファイル名は `snake_case.go`(慣習)、テストは `*_test.go`

### 5. 整形・静的解析

```bash
gofmt -w .            # 整形
goimports -w .        # import 整理
go vet ./...          # 静的解析
go test ./...         # テスト
```

- post-edit hook(Phase 6)で自動化
- staticcheck / golangci-lint をプロジェクトに応じて追加

### 6. その他

- `context.Context` は関数の第 1 引数(慣習)
- goroutine 起動は寿命管理を意識(`context` でキャンセル可能に)
- `defer` でリソース解放(close / unlock)
- struct embedding は継承の代替、安易に多用しない

## チェックリスト(骨子)

- [ ] `go.mod` / `go.sum` がバージョン固定
- [ ] `if err != nil` を抜けている箇所がない
- [ ] エラー無視(`_ = ...`)に理由コメント
- [ ] インターフェースが利用側パッケージで定義されている
- [ ] `gofmt -d .` / `goimports -d .` で diff なし
- [ ] `go vet ./...` がエラー 0

## アンチパターン

- エラーを `_` で無視して握りつぶす
- 巨大なインターフェースを実装側パッケージで定義し、テストで mock を作りにくくする
- `panic` でエラーを握りつぶす(`recover()` でその場凌ぎ)
- `context.Context` を後ろの引数や struct field に隠す

## 関連

- [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)
- [`adapters/claude-code/user-level/skills/skill-creation/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/skill-creation/SKILL.md) — 本 skeleton を肉付けする手順

## 状態

skeleton 配置のみ(2026-04-26 時点)。本格採用時に拡充する(本 skill 自体を `practices/coding-style-conventions.md` の言語別具体化として完成させる)。
