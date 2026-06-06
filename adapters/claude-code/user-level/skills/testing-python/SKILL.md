---
name: testing-python
description: Python のテスト戦略(pytest)
recommended_model: sonnet
---

# Python Testing

Python のテストフレームワーク(pytest 中心)・実行・モック作法。
抽象戦略は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md)、Python の構文規約は別 skill `python-style`。

## 目的

`pytest` ベースで TDD サイクル(Red/Green/Refactor)を回す。`uv run pytest` で再現可能な実行を保つ。

## いつ発動するか

- Python で新機能を実装するとき(テストから書く)
- バグ修正時(再現テストから書く)
- リファクタリング時(緑のテストを前提に構造を変える)

## 手順

### 1. フレームワーク選定

- 第一選択: `pytest`(エコシステム・プラグイン群が成熟)
- `unittest` は標準ライブラリ依存縛りがある場合のみ
- 非同期: `pytest-asyncio` または `anyio` プラグイン
- HTTP モック: `respx`(httpx 用)/ `responses`(requests 用)
- DB: 実 PostgreSQL / SQLite を docker / fixture で立てる

### 2. 命名と基本構造

```python
def test_returns_user_when_input_has_valid_id_and_email():
    ...

def test_raises_validation_error_when_id_is_missing():
    ...
```

```python
def test_returns_zero_when_items_is_empty():
    # Arrange
    items: list[Item] = []

    # Act
    total = sum_prices(items)

    # Assert
    assert total == 0
```

振る舞いベースの命名と Arrange-Act-Assert は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) を参照。Python では `assert` 1 回。

### 3. fixture とパラメタライズ

```python
import pytest

@pytest.fixture
def sample_user() -> User:
    return User(id="usr_123", email="x@example.com")

@pytest.mark.parametrize("price,expected", [(0, 0), (100, 100), (-1, 0)])
def test_normalize_price(price, expected):
    assert normalize_price(price) == expected
```

- 重複データはパラメタライズで列挙(各ケースが独立した 1 アサーション)

### 4. モック方針

一般戦略は [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) を参照。Python 固有：

- 真に外部な API 呼び出しのみ `respx` / `responses` でモック
- Date / Random は依存注入で固定可能に設計(`freezegun` は最終手段)

### 5. 実行コマンド

```bash
uv run pytest                       # 全実行
uv run pytest tests/test_foo.py     # 単体
uv run pytest -k "name"             # 名前フィルタ
uv run pytest -x                    # 最初の失敗で停止
uv run pytest --cov=<pkg>           # カバレッジ
uv run pytest -n auto               # pytest-xdist で並列
```

### 6. 型 / 静的解析との整合

- テストコードも `mypy --strict`(または `pyright`)を通す
- `Any` を散らさない
- `# type: ignore` には理由コメント

### 7. CI / hook 連携

- post-edit hook(Phase 6)で affected ファイルのテストのみ実行
- post-stop hook(Phase 6)で `git status` から変更モジュールのテストを実行
- `failure-log.jsonl` に失敗を記録(Phase 7b の `log-failure.sh`)

## チェックリスト

- [ ] テストファイル名が `test_*.py` または `*_test.py`
- [ ] 命名が振る舞いベース(実装関数名で命名していない)
- [ ] 1 テスト 1 アサーション、AAA 順序
- [ ] 統合テストで DB / HTTP をモックしていない(実物使用)
- [ ] `pytest.mark.skip` / `xfail` で逃げているテストがない
- [ ] `uv run pytest` が緑
- [ ] `mypy --strict`(または `pyright`)がエラー 0

## アンチパターン(Python 固有)

一般的なアンチパターンは [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) を参照。Python 特有の陥りやすい例：

- fixture のスコープ(`function` / `module` / `session`)を意識せず副作用がテスト間で漏れる(DB トランザクション、グローバル状態)
- パラメタライズした複数ケースで 1 つが失敗すると、その行だけスキップされ、失敗テストが残る(`xfail` 無しで放置しない)

## 関連

- [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) — 抽象戦略
- [`adapters/claude-code/user-level/skills/python-style/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/python-style/SKILL.md) — Python 構文 / 静的解析
