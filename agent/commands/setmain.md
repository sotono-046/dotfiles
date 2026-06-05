# メイン開発ブランチへ戻して最新化（/setmain）

## 概要

現在の Git リポジトリで、**メイン開発ブランチ**にチェックアウトし、リモートの最新状態に更新する。

- トリガー: `/setmain`
- 引数: なし

## メイン開発ブランチの決定順

次の順で1つだけ選ぶ。**どれも解決できなければ Git 操作は行わず、理由を報告して停止する。**

1. **リポジトリ直下の `AGENTS.md` に明示指定がある場合** — そのブランチ名を使う。
2. **指定がない場合** — リモートまたはローカルに存在する **`develop` を優先**。
3. **`develop` がない場合** — 存在する **`dev` を使う**。
4. **`develop` も `dev` もない場合** — **実行しない**（`main` / `master` へのフォールバックはしない）。

### `AGENTS.md` の読み取り

リポジトリルート（`git rev-parse --show-toplevel`）の `AGENTS.md` を読み、次のいずれかにマッチする**最初の1件**を採用する。

- 見出し `## メイン開発ブランチ` の直後の行（空行を除く最初の非空行）
- 行内指定: `メイン開発ブランチ: <branch>` または `メイン開発ブランチ：<branch>`

例:

```markdown
## メイン開発ブランチ

develop
```

```markdown
メイン開発ブランチ: dev
```

`AGENTS.md` が無い、または上記パターンにマッチしない場合は「指定なし」とみなし、手順2へ進む。

## 手順

### 0. 前提確認

```bash
git rev-parse --is-inside-work-tree
git rev-parse --show-toplevel
git remote get-url origin   # 失敗したらリモート未設定として報告して停止
```

- Git リポジトリでない、または `origin` が無い場合は**実行しない**。

### 1. メイン開発ブランチ名を解決

1. `AGENTS.md` から明示指定を探す（上記ルール）。
2. 見つからなければ、存在確認のため `git fetch origin --prune` を実行する。
3. ブランチ存在判定（ローカル ref または `origin/<branch>` のいずれかがあれば OK）:

```bash
git fetch origin --prune

branch_exists() {
  local b="$1"
  git show-ref --verify --quiet "refs/heads/${b}" \
    || git show-ref --verify --quiet "refs/remotes/origin/${b}"
}
```

4. 解決順: `AGENTS.md` 指定 → `develop` → `dev`。
5. 採用したブランチ名と、どのルールで選んだか（明示 / develop / dev）をユーザーに1行で報告する。
6. 最終候補がどれも `branch_exists` で false なら**実行しない**。候補一覧と「`develop` / `dev` が見つからない」旨を報告する。

### 2. 作業ツリーの確認

```bash
git status --porcelain
```

- 未コミット変更がある場合は、**勝手に stash / commit しない**。変更概要を示し、ユーザーに stash またはコミットを求めて**停止**する。
- クリーンなら続行。

### 3. メイン開発ブランチへ切り替え

ローカルにブランチが無くリモートだけある場合は tracking 付きで作成する。

```bash
MAIN_BRANCH="<解決したブランチ名>"

if git show-ref --verify --quiet "refs/heads/${MAIN_BRANCH}"; then
  git checkout "${MAIN_BRANCH}"
else
  git checkout -B "${MAIN_BRANCH}" "origin/${MAIN_BRANCH}"
fi
```

### 4. 最新化

```bash
git pull --ff-only origin "${MAIN_BRANCH}"
```

- `--ff-only` で fast-forward できない場合（ローカルに独自コミットがある等）は、状況を報告して**強制操作はしない**（`reset --hard` / `pull --rebase` はユーザー指示があるまで行わない）。

### 5. 結果確認

```bash
git branch --show-current
git status -sb
git log --oneline -3
```

## 成果物

- メイン開発ブランチ上で、リモートと fast-forward 整合した作業ツリー
- 採用ブランチ名と解決根拠（`AGENTS.md` / `develop` / `dev`）の報告

## やらないこと

- `main` / `master` への自動フォールバック
- 未コミット変更の自動 stash / commit
- fast-forward 不可時の強制上書き（`reset --hard` 等）
- ワークツリー（`git worktree`）の追加・削除
