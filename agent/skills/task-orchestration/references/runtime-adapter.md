# Runtime adapter

起動・追送・再開にはそのsessionに公開されたtool schemaを使う。下表は役割対応であり、存在しないtoolを作ったり別runtimeの引数を移植したりしない。

| 操作 | Codex collaboration | Claude Code |
|---|---|---|
| 起動 | spawn_agent | 公開されたTask/Agent |
| 稼働中の追送 | send_message | 公開されたmessaging tool |
| idle/完了turnの再開 | followup_task | 公開されたresume/messaging tool |
| 状態・待機 | list_agents / wait_agent | notificationまたは公開された待機tool |

- Codexでは一意なtask_nameと自己完結したmessageを渡す。fork_turnsは必要最小限、model/reasoningは既定・明示指定を尊重する。run_in_background、TaskOutput、Claude固有model/subagent_typeを渡さない。
- Claudeのsubagent_type、background option、modelは公開schemaで確認する。tool一覧や権限を推測しない。
- timeoutは未完了を示す場合がある。状態・最新出力を確認し、同じ処理を盲目的に再送しない。
- 利用可能な待機toolを使い、ユーザーへの応答を妨げる長いforeground待機を避ける。
- childが追加委譲できない場合は自分の範囲を処理して親へ返す。単にtoolがないことを理由に、可能な調査や統合まで止めない。

## 独立CLIが必要な場合だけ

in-process agentが使えない、または強いread-only隔離が必要で、独立実行が依頼の範囲内ならCLIを検討する。installed CLIのhelp/公式仕様で構文を確認し、repo固定・read-only sandbox・有限timeoutを指定する。promptはファイルか安全なstdinで渡し、未信頼本文をshell commandへ補間しない。sandbox/approvalを弱めるflagや広い追加pathを使わない。
