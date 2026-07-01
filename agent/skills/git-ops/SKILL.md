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
