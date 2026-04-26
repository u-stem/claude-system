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
- DB: 実 PostgreSQL / SQLite を docker / fixture で立てる(モック禁止、`practices/testing-strategy.md`)

### 2. ファイル配置

- ソースの隣 or `tests/` ディレクトリ(プロジェクトで統一)
- 命名: `test_<module>.py` または `<module>_test.py`(pytest が自動収集)
- フィクスチャは `conftest.py` で共有

### 3. 命名

```python
def test_returns_user_when_input_has_valid_id_and_email():
    ...

def test_raises_validation_error_when_id_is_missing():
    ...
```

- 振る舞いベース、実装関数名を含めない
- 1 関数 1 アサーション

### 4. Arrange-Act-Assert

```python
def test_returns_zero_when_items_is_empty():
    # Arrange
    items: list[Item] = []

    # Act
    total = sum_prices(items)

    # Assert
    assert total == 0
```

- `assert` は 1 回
- テスト内に分岐・繰り返しを書かない

### 5. fixture とパラメタライズ

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

### 6. モック方針

- 純粋ロジックはモックなし
- 外部 I/O は統合テストで実物(SQLite / 実 PostgreSQL / ローカル HTTP サーバー)
- 真に外部な API 呼び出しのみ `respx` / `responses` でモック
- Date / Random は依存注入(`freezegun` は最終手段)

### 7. 実行コマンド

```bash
uv run pytest                       # 全実行
uv run pytest tests/test_foo.py     # 単体
uv run pytest -k "name"             # 名前フィルタ
uv run pytest -x                    # 最初の失敗で停止
uv run pytest --cov=<pkg>           # カバレッジ
uv run pytest -n auto               # pytest-xdist で並列
```

### 8. 型 / 静的解析との整合

- テストコードも `mypy --strict`(または `pyright`)を通す
- `Any` を散らさない
- `# type: ignore` には理由コメント

### 9. CI / hook 連携

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

## アンチパターン

- Red を踏まずに実装から始める
- 1 関数で複数の振る舞いを検証
- 統合テストで DB をモック(境界の挙動が見えない)
- `skip` / `xfail` で失敗を放置
- fixture のスコープ(`function` / `module` / `session`)を意識せず副作用が漏れる
- カバレッジ %% を目標化して意味のないテストを濫造

## 関連

- [`practices/testing-strategy.md`](~/ws/claude-system/practices/testing-strategy.md) — 抽象戦略
- [`adapters/claude-code/user-level/skills/python-style/SKILL.md`](~/ws/claude-system/adapters/claude-code/user-level/skills/python-style/SKILL.md) — Python 構文 / 静的解析
