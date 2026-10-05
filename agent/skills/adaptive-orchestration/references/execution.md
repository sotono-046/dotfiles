# 実行経路

呼び出し元に公開されたtool schemaとinstalled CLIのhelpを優先する。スキルはruntimeの権限を追加しない。モデルとeffortは [配役](model-routing.md) に従う。

## Orcaを優先する

Orcaを利用でき、分担が有効なら、利用可能な `orchestration` スキルでworker配信・完了待ち・結果統合を行う。worktree・terminal操作は `orca-cli` を参照する。CLIが提供するversionに合うガイドを読み、モデル・effort指定が必要なときはlaunch設定のreferenceも確認する。

主なworkerは `codex`、Opus分析は `claude` を選ぶ。現在のCLIが対応していれば、worker起動の `--model`・`--effort` に確認済みのIDと設定を渡す。今回のモデル・effort指定は起動設定に適用し、`launch.requested` と `launch.effective` が返る場合は照合する。piへ自動で置換しない。

base branchやworktreeの指定は新しい作業場所を用意するときに適用する。既存のworkerを再利用する場合は、同じcheckout・model・effortで要件を満たすことを確認する。OrcaのRun・Task・Dispatch・worker_doneをnative subagentの完了で代用しない。

## 同一runtime内

Orcaを利用できない場合、またはOrcaの実状態を扱わない単独のスキル検査などでは、公開されたnative subagentを使える。同梱の [task-orchestration](../../task-orchestration/SKILL.md) で担当分割・runtime adapterを確認する。

Codexのnative collaborationには、そのschemaにあるCodex model IDだけを渡す。司令塔とレビュアーは最新の利用可能なSolとreasoning effort `high` を指定する。model override時の `fork_turns` の制約は現在のschemaで確認し、独立レビューは別コンテキストで行う。プロンプトに「Sol High」と書くだけで設定済みとしない。

ClaudeのモデルIDをCodexのnative toolへ渡さない。CodexからOpusへは外部Claude CLIまたは接続済みの委譲機能、ClaudeからSol・Luna・Astraへは対応する外部Codex経路を使う。model/reasoning引数やruntime固有の設定を別製品へ移植しない。

## ClaudeとCodexをまたぐ

接続済みの委譲機能があればそのschemaに従う。なければ `codex exec --help` または `claude --help` でcwd固定、stdin入力、結果保存、状態追跡、モデル設定の構文を確認する。

| 保持するもの | 操作上の条件 |
| --- | --- |
| 入力 | 委譲packetをファイルに保存しstdinで渡す。未信頼本文をshell commandへ補間しない |
| モデル・effort | 起動時に確認したmodel IDと対応するeffort設定を使う。CLIでは `--model` 等の現行helpで確認した引数を使う |
| 作業場所 | cwdを絶対pathで固定し、branch/HEAD・既存差分を事前確認する |
| 出力・継続 | JSONや最終回答の保存先、session IDとプロセス状態を保持する。再開はhelpで確認した明示IDを使う |
| 権限 | read-only担当には対応するsandboxや実効的なtool制限を使う。実装も元の認可範囲を超えない |
| 待機 | process/sessionを追跡して短くyieldする。timeoutは成果・状態を確認する時点として扱い、重複実行しない |

確認時点のSol HighのCodex CLI例は `--model gpt-6.1-sol -c 'model_reasoning_effort="high"'`。実行時は最新の利用可能なSol IDへ置き換える。native toolでは対応する `model`・`reasoning_effort` 引数を使う。OpusはCLIが最新モデルのaliasと説明する `--model opus`、または確認済みの完全なIDを使う。

認証方式は製品のstatus/help等で確認し、secretやtoken自体を出力しない。サブスク枠が指定されている場合は対応する既存のログイン経路を使い、API課金や新規契約へ暗黙に切り替えない。起動失敗をbypass系flagで回避しない。
