---
name: python-style
description: Python の構文・整形・型ヒント運用
recommended_model: sonnet
---

# Python Style

Python の構文・整形・型ヒント運用の作法。
言語非依存の規約は [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md)、テスト戦略は別 skill `testing-python`。

## 目的

`uv` ベースのプロジェクトで型ヒント + 静的解析を効かせ、ランタイムエラーを設計時にコンパイラ(mypy / pyright)へ移送する。

## いつ発動するか

- Python(3.11+)で新規実装するとき
- `pyproject.toml` を新規作成 / 改訂するとき
- 既存コードに型ヒントを追加するとき

## 手順

### 1. パッケージ管理(uv 必須)

- `uv add foo==1.2.3`(バージョン固定、`uv add foo` の floating range は避ける)
- 仮想環境は `uv venv` または `uv sync` 任せ
- 実行は `uv run` 経由(`python` を直接呼ばない)
- `requirements.txt` ではなく `pyproject.toml` + `uv.lock` を使う

### 2. 型ヒント

- 関数引数・戻り値・モジュールレベル変数に型注釈を必ず付ける
- `Optional[T]` よりも `T | None`(Python 3.10+ の union syntax)
- `List[T]` / `Dict[K, V]` ではなく `list[T]` / `dict[K, V]`(Python 3.9+ の組み込み generics)
- `from __future__ import annotations` は新規ファイルで標準化(forward reference を有効化)
- 複雑な構造は `TypedDict` / `NamedTuple` / `dataclass(slots=True, frozen=True)` で型化
- ランタイム検証が必要なら `pydantic` v2 を境界で使う

### 3. 静的解析・整形

```toml
# pyproject.toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "UP", "SIM", "N", "RET", "ARG"]
ignore = []

[tool.mypy]
strict = true
python_version = "3.11"
```

- 整形 + lint: `ruff check --fix` + `ruff format`
- 型検査: `mypy <pkg>` または `pyright`(プロジェクト統一)
- pre-commit / post-edit hook で自動化(Phase 6 の project-templates)

### 4. 命名(PEP 8 準拠)

- モジュール / 関数 / 変数: `snake_case`
- クラス: `CapWords`
- 定数: `UPPER_SNAKE_CASE`
- プライベート: `_leading_underscore`(public API でないことを示す慣習)
- ダンダー(`__init__` 等)は意図的にのみ

### 5. f-string / リスト内包表記

- 文字列フォーマットは f-string(`f"value: {x}"`)、`%` / `.format()` は使わない
- リスト内包表記は**1 行に収まる場合のみ**(複雑なら `for` ループに展開)
- ジェネレータ式は遅延評価が必要なときだけ(可読性を優先)

### 6. エラーハンドリング

- `except Exception:` で広く受けない(具体例外を catch、想定外は伝播)
- 空の except 禁止
- カスタム例外はモジュール内で定義、`RuntimeError` の継承は最終手段
- エラー本文に「何が・何を期待し・何を受け取ったか」を含める

### 7. 標準ライブラリと外部依存の優先順

- `pathlib` / `dataclasses` / `enum` / `typing` 等の標準を優先
- 外部依存は「最小限 + 固定バージョン + メンテ確認」(別 skill `dependency-review`)

## チェックリスト

- [ ] `uv` ベースで `pyproject.toml` + `uv.lock` 構成
- [ ] 関数引数・戻り値に型注釈がある
- [ ] `T | None` / `list[T]` / `dict[K, V]` の新表記を使っている
- [ ] `ruff check` / `ruff format` がエラー 0
- [ ] `mypy --strict`(または pyright)がエラー 0
- [ ] f-string で統一(`%` / `.format()` を新規追加しない)
- [ ] `except Exception:` で広く受けていない
- [ ] エラー本文に「何が・何を期待し・何を受け取ったか」を含む

## アンチパターン

- 型注釈なしで Public 関数を公開
- `Optional[T]` と `T | None` を混在
- `List` / `Dict`(typing 由来)と `list` / `dict`(組み込み)を混在
- リスト内包表記に複雑な条件分岐を詰め込む
- 例外を `pass` で握りつぶす
- `pip install` で固定なし、`requirements.txt` 直編集

## 関連

- [`practices/coding-style-conventions.md`](~/ws/claude-system/practices/coding-style-conventions.md) — 言語非依存の規約
- [`adapters/claude-code/user-level/skills/testing-python/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/testing-python/SKILL.md) — テスト
- [`adapters/claude-code/user-level/skills/dependency-review/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/dependency-review/SKILL.md) — 依存追加
