# 一括ワークツリー作成コマンド

## 概要

`temp/sotono-1` から `temp/sotono-5` までの5個のブランチを作成し、それぞれに対応するワークツリーを `wtp` コマンドで一括作成する。
下記における「メインブランチ」は、 プロジェクトの`AGENTS.md`にて指定された保存先がある場合にそれに準じる。

## 手順

### 1. 現状の確認

```bash
# 現在のブランチとワークツリー状態を確認
git branch -a
wtp list

# すでにある場合はそれを一旦削除する。
wtp remove <worktree-path>
```

### 2. メインブランチを最新に更新

`AGENTS.md`で`dev`が指定されている場合のパターン

```bash
git fetch dev
git checkout dev
git pull dev
```

### 3. 5個のワークツリーを一括作成

```bash
# temp/sotono-1 から temp/sotono-5 まで5個のワークツリーを作成
for i in 1 2 3 4 5; do
  wtp add -b "temp/sotono-$i"
done
```

### 4. 作成結果の確認

```bash
wtp list
git branch -a | grep temp/sotono
git checkout dev
```

## 成果物

- 各ブランチに対応する5個のワークツリー
  - `temp/sotono-1`
  - `temp/sotono-2`
  - `temp/sotono-3`
  - `temp/sotono-4`
  - `temp/sotono-5`
