---
name: git-ops
description: "Git運用のフォーマット規約。Conventional Commits形式のコミットメッセージと日本語PRテンプレートを提供する。コミットやPR作成時に自動トリガーされる。"
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

## 2. プルリクエスト

- **タイトル含め必ず日本語で記述する**
- 作成前にローカルで CI 相当（型チェック・リント・テスト）を通す
- 長文の body は `.temp/YYMMDD/PR/YYMMDD-PR-<タイトル>.md` に書いてから `gh pr create --body-file` で使用する
- 作成後にレビュー指摘が入ったら `ci-merge-watch` を併用する

### MISA レビュー停滞時の代替レビュー

- MISA レビューが長時間進まない場合は待ち続けず、別タスクの Codex を独立レビュアーとして起動する。Subagent 機能が使える場合はそれを優先し、使えない場合は `codex exec review` を使う
- レビューモデルは固定しない。起動時に OpenAI 公式の [Codex Models](https://learn.chatgpt.com/docs/models.md) と実行環境の利用可能モデルを確認し、複雑なコードレビューに適した最新の Sol 系モデルを選ぶ（現行例: `gpt-5.6-sol`）。ユーザーが「5.6 Sol」などと指定した場合も、そのバージョンに固定する明示指示がなければ、その時点の最新 Sol 系モデルを使う
- 対象 PR、head SHA、base branch、レビュー観点を渡し、作業ツリーを変更させない読み取り専用レビューとする。CLI では次の形を使う

```bash
codex exec -C "$TARGET_REPO" review \
  -m "<latest-sol-model-id>" \
  --base "$BASE_BRANCH" \
  "PRと現在の head SHA を確認し、重大度順にコードレビューしてください。編集はしないでください。"
```

- 代替レビューで重大指摘がなく、必要な CI も通った場合は、MISA レビューと同等の確認結果として扱い、`ci-merge-watch` の後続を進める

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
