# 一括ワークツリー削除コマンド

## 概要

`temp/sotono-1` から `temp/sotono-5` までの5個のワークツリーとブランチを `wtp` コマンドで一括削除する。
下記における「メインブランチ」は、プロジェクトの`AGENTS.md`にて指定された保存先がある場合にそれに準じる。

## 手順

### 1. 現状の確認

```bash
# 現在のワークツリー状態を確認
wtp list

# 現在のブランチを確認
git branch -a | grep temp/sotono
```

### 2. メインブランチに移動

削除前にメインブランチに移動しておく。

`AGENTS.md`で`dev`が指定されている場合のパターン

```bash
git checkout dev
```

### 3. 5個のワークツリーを一括削除

```bash
# temp/sotono-1 から temp/sotono-5 まで5個のワークツリーを削除
for i in 1 2 3 4 5; do
  wtp remove "temp/sotono-$i"
done
```

### 4. リモートブランチも削除する場合

```bash
# リモートブランチを削除
for i in 1 2 3 4 5; do
  git push origin --delete "temp/sotono-$i"
done
```

### 5. 削除結果の確認

```bash
wtp list
git branch -a | grep temp/sotono
```

## 成果物

- 削除された5個のワークツリー
  - `temp/sotono-1`
  - `temp/sotono-2`
  - `temp/sotono-3`
  - `temp/sotono-4`
  - `temp/sotono-5`
