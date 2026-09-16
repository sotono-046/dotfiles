# 実行経路

呼び出し元に公開されたtool schemaとinstalled CLIのhelpを優先する。スキルはruntimeの権限を追加しない。

## 同一runtime内

固定配役表のモデルを指定できる場合はnative subagentを優先する。Codexのcollaboration、Claude CodeのAgent/Task等、実際に公開された機能を使う。モデルoverrideが許可されていなければ、固定配役表の利用不可時のルールに従う。

Codexのnative collaborationにClaudeのモデルIDを渡さない。Codex親からFable・Opusへは外部Claude CLIまたは接続済みのClaude委譲機能を使い、Claude親からAstra・Lunaへも外部Codexの経路を使う。モデルが利用可能という説明だけでは、native toolがそのモデルを受け付けることを意味しない。`fork_turns`等のruntime固有引数も外部経路に移植しない。

同梱されていれば [task-orchestration](../../task-orchestration/SKILL.md) の担当分割・runtime adapterを利用できる。なくても、本体の委譲packetと公開schemaで進められる。別のCodexユーザータスクを作成する機能は、内部subagentの代用にしない。

## ClaudeとCodexをまたぐ場合

1. 接続済みのMCP・プラグイン等に委譲機能が公開されていれば、そのschemaに従う。名称だけで存在を仮定せず、継続IDと結果取得手段を確認する。
2. なければ外部CLIを確認する。Claudeからは `codex exec --help`、Codexからは `claude --help` を読み、cwd固定・安全なstdin・結果保存・状態追跡が可能な構成を使う。
3. 外部CLIがない、ログインできない、または現行権限で動かない場合は事実を伝え、固定配役表の利用不可時のルールに従う。

### CLIで保持するもの

- 入力: 委譲packetをファイルに保存しstdinで渡す。本文をshell commandへ補間しない。
- モデル: installed helpで対応を確認し、CLIでは `--model` に固定配役表のIDを渡す。native toolでも対応するmodel引数を使う。応答に実行モデルがあれば指定と照合し、不一致を隠さない。
- Luna High: Codex CLIでは `--model gpt-5.6-luna -c 'model_reasoning_effort="high"'` を使う。native toolでは `model` と対応するreasoning引数に `high` を指定する。現在のschemaで指定可能なことを確認し、指定できなければ利用不可として扱う。
- 作業場所: Codexは対応する `--cd`、Claudeは起動プロセスのcwdを明示する。既存のdirty差分を事前確認する。
- 出力: Codexの `--json` / `--output-last-message`、Claudeの `--print` / `--output-format json` 等、installed helpで確認できた機能を使う。
- 継続: 応答のsession IDとプロセス状態を保存する。再開構文もhelpで確認し、他の作業を拾う `--last` 等より明示IDを使う。
- 権限: read-only担当には対応するsandboxまたは実効的なtool制限を設定する。プロンプトの「編集禁止」だけを技術的な隔離と呼ばない。実装担当も元の認可範囲を超えず、bypass系flagで起動失敗を回避しない。
- 待機: ホストのprocess/session追跡で短くyieldし、有限の実行期限を設ける。期限時はまず状態と成果物を確認し、停止が必要ならこの担当のプロセスだけを対象にする。

CLI認証方式は製品のstatus/help等で確認し、secretやtokenそのものを読んで報告しない。既存のAPI認証からサブスク認証への切替や追加インストールが必要でも、このスキルの利用だけを変更許可と解釈しない。

Fuguを追加するのはユーザーがその利用を求め、利用可能な接続と費用・データ送信範囲が明らかな場合。現在のClaude/Codex契約をFuguにそのまま流用できるとは仮定しない。
