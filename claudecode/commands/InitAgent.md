# AGENTS と CLAUDE の初期化

- `CLAUDE.md`と`AGENTS.md`に書いてある内容を比較し、統合する
- 統合した内容を skill`code-reviewer`を参照し、レビューを承認されるまで繰り返し行うこと。
- レビュー結果を`AGENTS.md`に書き込む

## CLAUDE.mdの初期化

下記コマンドを使って、プロジェクトのCLAUDE.mdを初期化してください。

```bash
: > CLAUDE.md
echo $'@AGENTS.md' > CLAUDE.md
```
