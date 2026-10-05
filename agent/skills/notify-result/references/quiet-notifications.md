# 自動通知の抑制と配信

## dotfilesで管理するもの

共通方針は `agent/AGENTS.md`、明示通知の手順は `agent/skills/notify-result/` に置く。`install.sh` は共通方針と各スキルをCodex・Claude Code・Gemini・piへ配信する。既存のsymlink先は変更内容を参照するが、実行中のエージェントが指示を読み直したことまでは保証しない。

新しいMacへ反映するときは、先に次で配信予定を確認する。

```bash
./install.sh --agent-only --dry-run
```

現在のローカルClaude設定はアプリがhookを追加した実ファイルになっている場合がある。`install.sh --agent-only` は退避後にdotfiles版へ置き換えるため、Orcaなどの追加設定が必要な環境では通知項目だけを既存JSONへ反映する。通知抑制のために設定全体を置換しない。

## Claude Code

dotfilesの `agent/settings.json` では次を設定する。

- `preferredNotifChannel: "notifications_disabled"` で通常のterminal通知を止める。
- `agentPushNotifEnabled: false` でRemote Controlの自動pushを止める。
- `Notification` / `Stop` の `afplay /System/Library/Sounds/Hero.aiff` を実行する通知音hookを除く。

ローカル `~/.claude/settings.json` でも同じ項目だけ反映し、Orca・Paseoなどが管理する状態報告hookと、作業メモ用hookは残す。hookを全停止する設定にはしない。新しいセッションで有効な設定を確認し、プロジェクト固有の通知hookがあれば別に確認する。

`Stop` はClaudeの応答終了であり、依頼全体の完了ではない。[公式hook仕様](https://code.claude.com/docs/en/hooks#stop) と、通知経路の [公式設定説明](https://code.claude.com/docs/en/terminal-config#get-a-terminal-bell-or-notification)、[モバイルpushの説明](https://code.claude.com/docs/en/remote-control#mobile-push-notifications) を参照する。実環境のschemaは `agent/settings.json` の `$schema` でも確認できる。

## pi・Codexのローカル通知音

2026-10-05に、Orcaの通知設定とは別にHeroの音を鳴らす二つの設定を確認した。ユーザーから両方を外す指示を受けて再確認した時点で、以下の状態になっていた。

- piの `~/.pi/agent/extensions/notify-when-input-needed.ts` は削除済み。以前は `ui_prompt_start` と `agent_settled` から `afplay /System/Library/Sounds/Hero.aiff` を実行していた。残っているOrcaの状態報告拡張は維持する。
- Codexの `~/.codex/config.toml` の `notify` は、Computer Useの `SkyComputerUseClient turn-ended` と `--previous-notify` に設定された `~/.agi-tools/codex-notify.sh` のみ。以前の `bash -lc afplay …/Hero.aiff` は除去済み。`codex-notify.sh` は状態ファイルの更新だけで、音の再生処理はない。Computer Useの処理、Orcaのhook、作業メモhookは維持する。

上記のローカル設定と対象hook・拡張に `afplay` / `Hero.aiff` の残存がないことを確認した。音の実再生は検証していない。起動中のセッションが古い設定・拡張を保持してまだ鳴る場合は、作業を区切って再読み込みまたは再起動する。

別Macでも、piの拡張とCodexの `notify` を個別に確認する。音を消すために `notify` 全体や状態報告hookを削除しない。

### 質問・承認待ちのPop

ユーザーの追加指示により、質問・承認待ちだけは `Pop` を鳴らす。`agent/notifications/` に設定と導入スクリプトを置く。完了通知用の `notify` や `Stop` には追加しない。

```bash
python3 agent/notifications/install.py
```

この導入スクリプトは、piの質問音拡張のsymlinkとCodexの質問・承認hookだけを追加する。既存のOrca・Paseo・作業メモhookを保持し、変更前の設定は `~/.local/state/dotfiles/backups/` に退避する。通常の `install.sh --agent-only` とは別に実行する。

質問音の管理groupは更新時にgroup単位で置換するため、その中に別のhookを混在させない。今回の実設定では独立したgroupに追加し、既存hookがすべて保持されたことを変更前の設定と照合した。

Codexは質問ツールの `PreToolUse` と、承認要求の `PermissionRequest` を使う。piはagent実行中の `ui_prompt_start` を使う。通常の終了・idle・子の終了や内部質問は対象外。自由文の疑問符から質問を推測する処理はないため、会話内に書くだけの質問では音は出ない。

Codexのhook仕様と信頼確認は[公式ドキュメント](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks)を参照する。質問音も止めたいセッションは、起動時に `AGENT_QUESTION_SOUND=off` を渡す。Orcaの通知を再び有効にした場合も、二重に鳴らさないようこの質問音をOFFにする。

2026-10-05、このMacでは追加した2件だけをCodexの `/hooks` で信頼済みにし、`PreToolUse` / `PermissionRequest` のActiveがそれぞれ3件になったことを確認した。別Macでは導入後に同じ信頼確認が必要。Codexは新しいセッション、piは `/reload` または再起動で設定を読み込む。

helperのPython mockテスト3件、piのイベントmockテスト、設定を保持する再導入テストは成功。Lunaが実装し、Astraの独立レビューはGO。実際の音の再生と実質問イベントによる動作は未検証。

## Orca

2026-10-05、ユーザーがOrcaの通知をOFFにし、共有スクリーンショットで「通知を有効にする」がOFFになっていることを確認した。個別の「Agentのタスクが完了しました」「ターミナルベル」はONのまま、通知全体をOFFにした状態。画面ではネイティブのデスクトップ通知を対象としている。実際のイベントによる通知停止、別profile・別Mac・モバイルpushは未検証。

同じ運用を別のMacやprofileへ適用するときは、通知設定の「通知を有効にする」をOFFにする。設定上の対応項目は `settings.notifications.enabled`。

```json
{
  "enabled": false
}
```

これは確認用の断片であり、Orcaの設定全体へ上書きするJSONではない。`notify-result` はOSへ直接送信する別経路なので、明示的に依頼された結果の通知はこのスキルで扱う。

インストール済みOrca 1.4.218の実装では、agentの `blocked` / `waiting` を「needs input」として通知する経路があり、タスク完了と同じ通知設定で制御される。通知全体OFFは質問時にも適用され、デスクトップ通知を止める。今回はその状態を維持し、質問音だけを別のhookで補う。

エージェントの画面操作はAccessibility権限エラーと別経路のtimeoutで使えず、設定変更はユーザーが行った。CLIの `agent-context` には通知設定を変更するコマンドが見当たらなかった。保存JSONやprofileのSQLiteを稼働中に直接書き換えず、設定画面で変更して状態を確認する。

`orca agent hooks off` は状態把握にも影響するため、この目的には使わない。共通指示だけでOrca自身の自動通知まで止まったと報告しない。

## 確認すること

通常依頼とworker終了で明示通知が出ず、依頼された結果についてだけリーダーまたは担当が一度通知することを確認する。macOSではその明示通知にだけ `Hero` サウンドが付く。同じ依頼IDの再送は抑制される。テストは一時directoryと偽の通知backendを使い、検証のために実通知を増やさない。

ローカル通知は実行hostで出る。別Mac・スマートフォンへの転送、Orcaのpush、OS上での実表示は、このスクリプトの検証とは別に確認する。
