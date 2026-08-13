---
name: git-ops
description: "Git の変更を所有範囲ごとに安全に整理し、明示 staging、Conventional Commits、日本語 PR テンプレートで commit / push / PR を進める。`コミットして`、`ワーキングツリーを整理`、`pushして`、`PR作って` で使用する。共有 worktree では他 agent・ユーザーの差分を保護し、commit を直列化する。"
---

# Git Operations

コミットと PR のフォーマット規約。一般的な Git の使い方は公式ドキュメントに従い、ここでは形式だけを定める。

## 1. コミットメッセージ

Conventional Commits 形式。description は英語で簡潔に書く。

```
<type>(<scope>): <description>
```

type: `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `ci` / `chore`

```bash
feat(auth): add OAuth2 login support
fix(api): resolve token expiry issue
```

- 変更は単一の目的ごとに小さくコミットする
- `git add -A` は使わず、対象ファイルを明示的にステージする

### Commit preparation

1. `git status --short --branch` と unstaged / staged diff を確認する。
2. 変更を「今回の依頼」「既存のユーザー変更」「別 agent の変更」「生成物・secret」に分類する。
3. 今回の所有 path だけを目的別グループへ分け、各グループに focused validation を対応づける。
4. `git add -- <explicit paths>` で1グループだけ stage する。
5. `git diff --cached --name-only` と `git diff --cached` を確認し、意図した path / 内容だけなら commit する。
6. commit 後に status を再確認し、残った変更を勝手に commit / stash / restore / reset せず報告する。

「ワーキングツリーをクリーンにして」と言われても、由来や所有権が不明な変更を一括 commit しない。目的が異なる変更は分割し、今回の権限外は残す。machine-local secret、cache、復号済み環境ファイルは stage しない。

### Shared worktree / index / HEAD

複数 agent が同じ Git 状態を共有するときは、編集を非競合 path へ並列化しても commit は直列化する。

- 各 agent は owner から GO が出るまで stage / commit しない。
- GO を受けた agent だけが担当 path を明示 stage する。
- staged path が担当集合だけであることを確認してから commit する。
- commit 完了後に次の agent へ GO を出す。
- agent ごとに独立 worktree / branch がある場合だけ並列 commit を許可する。

## 2. プルリクエスト

- **タイトル含め必ず日本語で記述する**
- 作成前にローカルで CI 相当（型チェック・リント・テスト）を通す
- 長文の body は `.temp/YYMMDD/PR/YYMMDD-PR-<タイトル>.md` に書いてから `gh pr create --body-file` で使用する
- 作成後にレビュー指摘が入ったら `ci-merge-watch` を併用する

### MISA 指摘と独立レビュー

- MISA のステータスやラベル変化は待たない。`review:pending` または `review:blocker` が付いていても、レビューコメントやスレッドに具体的な指摘がなければレビュー入力としては無視する
- PR がレビュー段階に入ったら、待機やポーリングを挟まず、別タスクの Codex に同じ head SHA を独立レビューさせる。Subagent 機能が使える場合はそれを優先し、使えない場合は `codex exec review` を使う
- レビューモデルは固定しない。起動時に OpenAI 公式の [Codex Models](https://learn.chatgpt.com/docs/models.md) と実行環境の利用可能モデルを確認し、複雑なコードレビューに適した利用可能な最新モデルを選ぶ。ユーザーが特定バージョンを指定した場合は、そのバージョンに固定する明示指示かを確認する
- 対象 PR、head SHA、base branch、レビュー観点を渡し、作業ツリーを変更させない読み取り専用レビューとする。判定基準は `$review-go-nogo`。prompt に同スキルの reviewer packet を含める。起動直前に `git status --short --branch` と HEAD を記録し、終了直後に再取得して差分がないことを確認する。CLI では次の形を使う

```bash
codex exec -C "$TARGET_REPO" --sandbox read-only review \
  -m "<runtime-selected-review-model>" \
  --base "$BASE_BRANCH" \
  "PRと現在の head SHA を確認し、$review-go-nogo の基準でコードレビューしてください。NO-GO は再現可能な P0/P1 の実害だけ。P2 以下は follow-up。編集はしないでください。"
```

前後で status または HEAD が変化していたらレビュー結果を採用せず、意図しない mutation として停止する。

- 独立レビューで NO-GO がなく、必要な CI も通った場合は、MISA ラベルの変化を待たずに `ci-merge-watch` の後続を進める。P2 follow-up が残っていても後続を止めない
- MISA から現在の head に対する具体的な指摘が実際に届いた場合は無視しない。指摘の根拠と適用可否を確認し、必要な修正と検証を行い、最新 head を再レビューしてからコメントを解決する

### PR テンプレート

```markdown
## 変更概要

[変更内容の簡潔な説明]

## 関連イシュー

- closes #[イシュー番号]

## 変更内容

- [変更点1]
- [変更点2]

## UI変更

<!-- UI変更がある場合はスクリーンショットを添付 -->

## 確認事項

- [ ] ローカルで CI 相当のチェックを実行した

## 注意事項

<!-- マイグレーション、インフラ変更などがあれば記載 -->

## スキップしたチェック

<!-- スキップしたチェックがあれば理由を明記 -->
```
