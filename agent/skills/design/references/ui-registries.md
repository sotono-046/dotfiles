# UI registriesの利用手順

Kibo UI・Aceternity UI・blocks.soは、共通のshadcn CLI / MCPから利用する。公式資料と取得する部品の依存関係を確認し、必要な部品だけ導入する。

## 探索とプロジェクト設定

対象アプリの`components.json`を確認する。MCPでこの3つのregistryを使うときは、既存の`registries`へ必要な項目だけ追加する。他の設定やregistryを上書きしない。接続できても、対象アプリにregistryが未設定なら検索・内容取得はできない。

```json
{
  "registries": {
    "@kibo-ui": "https://www.kibo-ui.com/r/{name}.json",
    "@aceternity": "https://ui.aceternity.com/registry/{name}.json",
    "@blocks-so": "https://blocks.so/r/{name}.json"
  }
}
```

これは`registries`の部分例。`components.json`の新規作成が必要なら、対象stackのshadcn公式セットアップに従う。dotfilesやアプリ以外のrepositoryへ、この設定を置かない。

[Registry Directory](https://ui.shadcn.com/docs/directory)から追加候補を探す。CLIは[公式index](https://ui.shadcn.com/r/registries.json)にあるnamespaceを解決できる。部品名やURLを推測せず、公式サイト・registryで確認する。

## MCP / CLIの使い方

`shadcn` MCPで対象プロジェクトのregistryを確認し、検索・部品の内容確認・追加コマンドの取得へ進む。取得したコマンドは対象アプリで実行する。MCPのtool名と引数は、現在公開されているschemaから確認する。MCPプロセスの作業ディレクトリが対象アプリと一致しているか確認する。

CLIを使う場合も対象アプリのディレクトリで実行する。

```bash
# 調査
npx -y shadcn@latest search @kibo-ui -q "calendar"
npx -y shadcn@latest search @aceternity -q "hero"
npx -y shadcn@latest search @blocks-so -q "login"
npx -y shadcn@latest view @kibo-ui/announcement
npx -y shadcn@latest view @aceternity/bento-grid
npx -y shadcn@latest view @blocks-so/login-01

# 採用した部品だけ導入
npx -y shadcn@latest add @kibo-ui/announcement
npx -y shadcn@latest add @aceternity/bento-grid
npx -y shadcn@latest add @blocks-so/login-01
```

追加されるコード・依存関係・既存部品の変更を確認し、既存テーマに合わせる。Kibo UIはshadcn/uiのCSS Variablesによるテーマを前提とする。Aceternity UIのMotion依存やclient componentの条件は、選んだ部品の資料で確認する。有料テンプレートの利用条件は無料部品と分けて確認する。

接続障害や403が出た場合は、公式サイトや公開ソースから必要な部品を確認して進める。取得できなかった部品の導入・検証は完了扱いにしない。

## エージェントへの配信

このdesignスキルはdotfilesのsymlinkでClaude Code・Codex・Piへ配信する。MCPはmachine-local設定に登録する。復元コマンドと設定先は [agent/mcp-servers.md](../../../mcp-servers.md) を参照する。

MCP追加後はClaude Code / Codexを再起動し、Piでは`/reload`するか新しいセッションを開始する。部品の導入は対象アプリの作業時に行う。

## 一次資料

- [shadcn MCP](https://ui.shadcn.com/docs/mcp)
- [Registry Directoryの仕様](https://ui.shadcn.com/docs/registry/registry-index)
- [Kibo UIセットアップ](https://www.kibo-ui.com/docs/setup)
- [Aceternity UI CLI / MCP](https://ui.aceternity.com/docs/cli)
- [blocks.so公式ソースとregistry設定](https://github.com/ephraimduncan/blocks#usage)
