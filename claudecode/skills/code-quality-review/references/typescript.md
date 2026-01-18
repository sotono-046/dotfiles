# TypeScript/JavaScript チェック項目

## 静的解析コマンド

```bash
# パッケージマネージャー検出
if [ -f "pnpm-lock.yaml" ]; then
  pnpm type-check || pnpm tsc --noEmit
elif [ -f "yarn.lock" ]; then
  yarn type-check || yarn tsc --noEmit
else
  npm run type-check || npx tsc --noEmit
fi
```

## リントコマンド

```bash
# ESLint
pnpm lint || npm run lint || yarn lint

# Biome（ESLintの代替）
pnpm biome check . || npx biome check .
```

## 重点チェック項目

### 型安全性

- `any` の使用を避ける（`unknown` を使用）
- 型アサーション (`as`) の乱用を避ける
- `strictNullChecks` が有効か確認
- ジェネリクスの適切な使用

### エラーハンドリング

- Promise の `.catch()` または try-catch
- 非同期関数での適切なエラー伝播
- カスタムエラークラスの活用

### セキュリティ

- `eval()` や `Function()` の禁止
- `innerHTML` の代わりに `textContent`
- ユーザー入力のサニタイズ
- 環境変数での機密情報管理

### パフォーマンス

- 不要な再レンダリング（React）
- メモ化の適切な使用（useMemo, useCallback）
- バンドルサイズの確認
- 動的インポートの活用

### モノレポ固有

- 共有パッケージ（@org/*）の適切なインポート
- パッケージ間の循環依存の回避
- ワークスペースプロトコル（workspace:*）の使用
