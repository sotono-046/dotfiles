# PR-check コマンド

## 概要

PR対象のブランチ `$ARGUMENTS` に最新のメインブランチをマージし、最新状態でのチェックを可能にする。
`$ARGUMENTS` が指定されていない場合は、現在のブランチを対象とする。
下記における「メインブランチ」は、プロジェクトの`AGENTS.md`にて指定された保存先がある場合にそれに準じる。

## 手順

### 1. 現状の確認

```bash
# 現在のブランチを確認
git branch --show-current

# PRブランチの状態を確認
git status

# 未コミットの変更がある場合は先にコミットまたはスタッシュ
git stash  # 必要に応じて
```

### 2. メインブランチを最新に更新

`AGENTS.md`で`dev`が指定されている場合のパターン

```bash
# リモートの最新を取得
git fetch origin

# メインブランチに切り替えて最新化
git checkout dev
git pull origin dev
```

### 3. PRブランチに戻ってメインをマージ

```bash
# PRブランチに戻る
git checkout $ARGUMENTS

# メインブランチをマージ
git merge dev
```

### 4. コンフリクトがある場合

```bash
# コンフリクト箇所を確認
git status

# コンフリクトを解消後
git add .
git commit -m "merge: dev into $ARGUMENTS"
```

### 5. マージ結果の確認

```bash
# マージ後の状態確認
git log --oneline -5

# 必要に応じてテスト実行
# npm test / pnpm test / yarn test など
```

### 6. スタッシュした変更を戻す（必要に応じて）

```bash
git stash pop
```

## 成果物

- 最新のメインブランチがマージされたPRブランチ
- PRがメインの最新コードと統合された状態でのチェックが可能に
