# CodeRabbit レビュー指示書

## 目的

- CodeRabbit CLI で差分をレビューし、指摘を Serena に格納して修正プランを作成する。

## ワークフロー

### 1. CodeRabbit レビューの実行・解析

```bash
coderabbit --prompt-only
```

### 2. Serena への格納

- 解析結果を保存する。
- `Serena MCP`がある場合、それを使用して `Serena` に格納する。

### 3. 修正プランの作成

Serena に格納した指摘を元に修正プランを作成。

### 4. プランレビュー

skill`code-reviewer`を参照し、レビューを承認されるまで繰り返し行うこと。

### 5. プラン承認

Userに対してプランを提示し、承認を得る。