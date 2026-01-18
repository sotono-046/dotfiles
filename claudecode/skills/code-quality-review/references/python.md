# Python チェック項目

## 静的解析コマンド

```bash
# 型チェック
mypy . --ignore-missing-imports
# または
pyright .
```

## リントコマンド

```bash
# Ruff（推奨：高速）
ruff check .

# flake8
flake8 .

# pylint
pylint **/*.py
```

## フォーマット

```bash
# Black
black --check .

# Ruff format
ruff format --check .

# isort（インポート順）
isort --check-only .
```

## 重点チェック項目

### 型安全性

- 型ヒントの使用（Python 3.9+）
- `Optional` と `Union` の適切な使用
- `TypedDict` でのdict型定義
- `Protocol` でのダックタイピング

### エラーハンドリング

- 具体的な例外クラスのキャッチ
- `except Exception` の回避
- コンテキストマネージャ（`with`）の活用
- ログ出力での例外情報

### セキュリティ

- `eval()` や `exec()` の禁止
- SQL インジェクション対策（プレースホルダ使用）
- `pickle` の信頼できないデータでの使用禁止
- 機密情報のハードコード禁止

### パフォーマンス

- リスト内包表記の活用
- ジェネレータの適切な使用
- `asyncio` での非同期処理
- N+1問題（ORMクエリ）

### コードスタイル

- PEP 8準拠
- docstring（Google/NumPy/Sphinx形式）
- 関数の単一責任
- マジックナンバーの定数化
