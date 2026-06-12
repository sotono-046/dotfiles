---
name: wtp
description: "Git worktree CLI `wtp` (Worktree Plus, https://github.com/satococoa/wtp) の利用と開発。worktree 作成・一覧・削除・移動、`.wtp.yml` フック設定、リポジトリ開発・PR 貢献。「wtp」「worktree」「git worktree」「wtp add」「wtp.yml」「Worktree Plus」で使用。commit/PR 手順は git-ops を併用。"
---

# wtp (Worktree Plus)

Repo: https://github.com/satococoa/wtp

`wtp` は `git worktree` を拡張した CLI。パス自動生成、リモート追跡、`.wtp.yml` による post-create フック、シェル連携を提供する。

## いつ使うか

- ブランチごとに別ディレクトリで並行開発したい
- worktree 作成時に `.env` コピーや `npm ci` などを自動化したい
- `wtp` 本体の開発・Issue/PR 対応・バグ調査

**使わない場面**

- 単一ブランチの通常 Git 操作 → `git-ops`
- ユーザーが worktree 利用を明示していない → 勝手に `wtp add` しない（`git-ops` と同じ）

## インストール確認

```bash
which wtp || brew install satococoa/tap/wtp
wtp --version
wtp --help
```

代替: `go install github.com/satococoa/wtp/v2/cmd/wtp@latest`

Zsh 連携（go install 時）:

```bash
eval "$(wtp shell-init zsh)"
```

Homebrew 版は初回 `TAB` 補完時に lazy init される。

---

## 日常運用（任意リポジトリ）

### 基本コマンド

```bash
# 既存ブランチから worktree 作成 → 既定 ../worktrees/<branch-path>
wtp add feature/auth

# 新規ブランチ + worktree
wtp add -b feature/new-feature

# 特定コミット/ブランチ起点
wtp add -b hotfix/urgent abc1234
wtp add -b feature/test origin/main

# 作成後にコマンド実行（hooks の後）
wtp add -b feature/x --exec "npm test"

# スクリプト向け: 作成パスのみ stdout
wtp add -b feature/x --quiet

# 一覧
wtp list

# 削除
wtp remove feature/auth
wtp remove --force feature/auth              # dirty でも強制
wtp remove --with-branch feature/done        # マージ済み branch も削除
wtp remove --with-branch --force-branch feature/done

# パス取得 / 移動（shell hook 有効時は wtp cd <name> で直接 cd）
cd "$(wtp cd feature/auth)"
wtp cd @   # main worktree

# 既存 worktree でコマンド
wtp exec feature/auth -- go test ./...
wtp exec @ -- pwd
```

### 推奨フロー（エージェント）

1. 対象が main worktree か確認: `git rev-parse --show-toplevel` / `wtp list`
2. 必要なら main を更新: `git fetch && git switch main && git pull --ff-only`
3. worktree 作成: `wtp add -b feature/<topic>`
4. 作業ディレクトリへ: `cd "$(wtp cd feature/<topic>)"` または `--quiet` 出力を利用
5. 完了後: `wtp remove --with-branch feature/<topic>`（ユーザー指示または明示的クリーンアップ時）

### リモートブランチ解決

- ローカルに無くリモートに 1 件だけあれば自動追跡
- 複数 remote に同名 branch がある場合はエラー → 先に tracking branch を作る:

```bash
git branch --track feature/shared origin/feature/shared
wtp add feature/shared
```

---

## 設定 (`.wtp.yml`)

初回テンプレ:

```bash
wtp init
```

最小例:

```yaml
version: "1.0"
defaults:
  base_dir: "../worktrees"

hooks:
  post_create:
    - type: copy
      from: ".env"      # 常に MAIN worktree 基準
      to: ".env"        # 新 worktree 基準（省略時 from と同じ相対 path）
    - type: symlink
      from: ".bin"
      to: ".bin"
    - type: command
      command: "npm ci"
      env:
        NODE_ENV: development
      work_dir: "."
```

**フックの要点**

| type | from | to | 備考 |
|------|------|-----|------|
| `copy` | main worktree | 新 worktree | gitignore ファイル可 |
| `symlink` | main worktree | 新 worktree | 大きい共有 dir 向け |
| `command` | — | 新 worktree で実行 | env に `GIT_WTP_WORKTREE_PATH`, `GIT_WTP_REPO_ROOT` |

`from` が絶対 path のとき `to` は明示必須。

---

## よくあるエラー

| 症状 | 対処 |
|------|------|
| branch not found | `git fetch`、リモート名確認、tracking branch 作成 |
| multiple remotes | `git branch --track ...` で明示 |
| dirty worktree on remove | コミット/stash または `--force` |
| branch not merged | `--with-branch` だけでは不可 → `--force-branch`（破壊的操作、ユーザー確認） |

---

## wtp リポジトリ開発

### 前提

- Go 1.24+
- Git 2.17+
- タスクランナー: `go tool task`（`Taskfile.yml`、tool pin は `go.mod`）

### レイアウト

| path | 役割 |
|------|------|
| `cmd/wtp/` | CLI（urfave/cli v3） |
| `internal/git/` | worktree / branch 解決 |
| `internal/config/` | `.wtp.yml` |
| `internal/hooks/` | post_create 実行 |
| `internal/command/` | git コマンド builder |
| `test/e2e/` | git ワークフロー E2E |
| `docs/agents/` | エージェント向け dev 手順 |

詳細: https://github.com/satococoa/wtp/blob/main/docs/architecture.md

### 開発コマンド

```bash
git clone https://github.com/satococoa/wtp.git
cd wtp
go mod download

go tool task build      # ビルド
go tool task install    # ローカル install
go tool task test       # unit test
go tool task test-e2e   # E2E
go tool task lint       # golangci-lint
go tool task fmt        # gofmt + goimports（PR 前必須）
go tool task dev        # fmt + lint + test の一式
```

単体テスト例: `go test ./internal/git -v`

### 変更時のルール

1. 挙動変更には unit test。git ワークフロー変更には E2E 追加/更新
2. 触った package は `go tool task fmt` → `go tool task lint`
3. PR 前: `go tool task dev`（最低 `test` + `lint`）
4. commit / PR は `git-ops`（Conventional Commits、英語 subject）
5. upstream docs: `AGENTS.md`, `docs/agents/dev-commands.md`, `docs/agents/code-and-tests.md`

### 設計メモ（実装時）

- Branch 解決: local → 単一 remote → 複数 remote はエラー（`internal/git`）
- `wtp cd` は path を **出力するだけ**。実際の cd は shell hook
- interactive TTY の `wtp add` のみ auto-switch（非 TTY / `--quiet` は path 出力のみ）

---

## 他 Skill との関係

| 状況 | Skill |
|------|-------|
| worktree 作成・削除・`.wtp.yml` | **wtp**（本 skill） |
| commit / PR / 履歴操作 | **git-ops** |
| 並列サブタスクの worktree 分離方針 | **task-orchestration** + 本 skill |

---

## チェックリスト

### worktree 作成前

- [ ] ユーザーが worktree 利用を明示した
- [ ] main / base branch を必要に応じて更新した
- [ ] branch 名が用途を表す
- [ ] プロジェクトに `.wtp.yml` が必要なら hooks を確認した

### wtp 本体 PR 前

- [ ] `go tool task fmt` 実行済み
- [ ] `go tool task test` / 必要なら `test-e2e` 通過
- [ ] `go tool task lint` 通過
- [ ] 挙動変更にテスト追加
- [ ] commit message が Conventional Commits
