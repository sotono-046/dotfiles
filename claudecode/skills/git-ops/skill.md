---
name: git-ops
description: "Git運用のベストプラクティスを提供するスキル。Conventional Commits形式のコミットメッセージ作成、PR作成、ワークツリー管理を支援。コミットやPR作成時に自動トリガーされる。対象：(1) コミットメッセージの作成、(2) PRの作成・テンプレート適用、(3) ワークツリーの分離・管理。"
---

# Git Operations

Git運用のベストプラクティスを提供し、一貫したワークフローを実現する。

## トリガー条件

- ユーザーがコミットを依頼した時
- ユーザーがPR作成を依頼した時

---

## 1. コミットメッセージ

### Conventional Commits 形式

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Type 一覧

| Type       | 用途                                                   |
| ---------- | ------------------------------------------------------ |
| `feat`     | 新機能の追加                                           |
| `fix`      | バグ修正                                               |
| `docs`     | ドキュメントのみの変更                                 |
| `style`    | コードの意味に影響しない変更（空白、フォーマットなど） |
| `refactor` | バグ修正でも機能追加でもないコード変更                 |
| `perf`     | パフォーマンス改善                                     |
| `test`     | テストの追加・修正                                     |
| `build`    | ビルドシステム・外部依存に関する変更                   |
| `ci`       | CI設定ファイル・スクリプトの変更                       |
| `chore`    | その他の変更（srcやtestに影響しない）                  |

### 例

```bash
feat(auth): add OAuth2 login support
fix(api): resolve token expiry issue
docs(readme): update installation instructions
refactor(user): extract validation logic
```

### コミット作成手順

1. `git status` で変更内容を確認
2. `git diff --staged` でステージング内容を確認
3. 変更内容に基づいて適切な type と scope を選択
4. 簡潔で明確な description を作成（日本語不可、英語で記述）
5. 必要に応じて body で詳細説明を追加

---

## 2. プルリクエスト

### PR作成の前提条件

- ローカルで `pnpm ci`（または該当するCIコマンド）を実行済み
- 型チェック、リント、テストがすべて通過

### PRテンプレート

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

- [ ] ローカルで `pnpm ci` を実行した
- [ ] 型チェックが通過した
- [ ] リントエラーがない
- [ ] テストが通過した

## 注意事項

<!-- マイグレーション、Cloud Runタスク、マニフェスト変更などがあれば記載 -->

## スキップしたチェック

<!-- スキップしたチェックがあれば理由を明記 -->
```

### PR作成の注意

- **必ず日本語で記述する**（タイトル含む）
- 長文のPRは `.temp/YYMMDD/PR/YYMMDD-PR-<タイトル>.md` にファイル作成してから `gh pr create` で使用

### PR作成コマンド例

```bash
# 日付を取得
DATE=$(date +%y%m%d)

# PRファイルを作成
mkdir -p .temp/${DATE}/PR
cat > .temp/${DATE}/PR/${DATE}-PR-機能追加.md << 'EOF'
## 変更概要
...
EOF

# PRを作成
gh pr create --title "feat(scope): 機能の説明" --body-file .temp/${DATE}/PR/${DATE}-PR-機能追加.md
```

---

## 3. ワークツリー管理

### 使用条件

**ユーザーから指示があったときのみ**使用する。

### `wtp` コマンド

```bash
# ヘルプを確認
wtp --help

# 新しいワークツリーを作成（mainブランチを最新にしてから実行）
wtp add -b feature/add-new-feature

# ワークツリーの一覧
wtp list

# ワークツリーの削除
wtp remove <worktree-path>
```

### ワークツリー使用時の注意

1. 作成前に `main` ブランチを最新の状態に更新
2. ブランチ名は機能を表す明確な名前を使用
3. 作業完了後は不要なワークツリーを削除

---

## チェックリスト

### コミット前

- [ ] 変更内容が単一の目的に集中している
- [ ] コミットメッセージが Conventional Commits 形式
- [ ] scope が適切に設定されている
- [ ] description が英語で簡潔

### PR作成前

- [ ] `pnpm ci` を実行した
- [ ] 型チェックが通過
- [ ] リントエラーがない
- [ ] テストが通過
- [ ] PRの説明が日本語で書かれている
- [ ] 関連イシューがリンクされている

### ワークツリー作成前

- [ ] ユーザーから明示的に指示があった
- [ ] main ブランチが最新
- [ ] ブランチ名が適切
