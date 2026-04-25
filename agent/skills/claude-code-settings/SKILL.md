---
name: claude-code-settings
description: Claude Code の settings.json 設定ファイルのレビュー・作成・修正を支援するスキル。permissions の書き方、パターン構文、ベストプラクティスに関する知識を提供する。settings.json のレビュー依頼時や権限設定の相談時に自動的にトリガーされる。
---

# Claude Code Settings スキル

Claude Code の settings.json 設定ファイルの作成・レビュー・修正を支援する。

## 目的

- settings.json の正しい構文とパターンを提供する
- permissions（allow/ask/deny）ルールのベストプラクティスを適用する
- 一般的な設定ミスを検出・修正する

## ワークフロー

### 設定レビュー時

1. 対象の settings.json を読み取る
2. 以下の観点でチェックする：
   - パス指定の構文（`//` vs `/` vs `~/`）
   - Bash パターンの適切性
   - deny/ask/allow の優先順位
   - MCP ツール名の形式
3. 問題点を指摘し、修正案を提示する

### 設定作成時

1. ユーザーの要件をヒアリングする
2. `references/permission-rules.md` を参照して適切なパターンを選択する
3. `references/settings-options.md` を参照して利用可能なオプションを確認する

## 重要なルール

### パス指定（Read/Write/Edit）

| パターン | 意味                                     | 例                               |
| -------- | ---------------------------------------- | -------------------------------- |
| `//path` | ファイルシステムルートからの**絶対パス** | `Read(//Users/alice/secrets/**)` |
| `~/path` | **ホーム**ディレクトリからのパス         | `Read(~/Documents/*.pdf)`        |
| `/path`  | **設定ファイルに相対的な**パス           | `Edit(/src/**/*.ts)`             |
| `path`   | **現在のディレクトリに相対的な**パス     | `Read(*.env)`                    |

**警告**: `/Users/alice/file` は絶対パスではなく、設定ファイルに相対的なパスとして解釈される。絶対パスには必ず `//Users/alice/file` を使用する。

### Bash パターン

| ワイルドカード | 位置               | 動作                                     |
| -------------- | ------------------ | ---------------------------------------- |
| `:*`           | パターンの末尾のみ | プレフィックスマッチング（単語境界付き） |
| `*`            | 任意の場所         | グロブマッチング（単語境界なし）         |

**例**:

- `Bash(npm run:*)` → `npm run build`, `npm run test` にマッチ
- `Bash(git * main)` → `git checkout main`, `git merge main` にマッチ
- `Bash(ls*)` → `ls -la` と `lsof` の両方にマッチ（注意）

**注意**: `Bash(*)` は**すべての** Bash コマンドにマッチしない。すべてを許可するには括弧なしで `Bash` を使用する。

### ルール評価順序

1. **Deny** ルールが最初にチェックされる
2. **Ask** ルールが2番目にチェックされる
3. **Allow** ルールが最後にチェックされる

最初にマッチするルールが動作を決定する。deny ルールは常に allow ルールより優先される。

## 参照ドキュメント

詳細なパターン構文は `references/permission-rules.md` を参照。
利用可能な設定オプションは `references/settings-options.md` を参照。
