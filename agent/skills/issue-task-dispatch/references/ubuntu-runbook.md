# Ubuntuでの起動と再開

## 実行環境を用意する

以下はUbuntuに導入するときの手順例であり、このスキルの作成時には実行しない。path・repository・Issue番号・予算の例を、実行設定に記録した値へ置き換える。

1. Tailscale経由で指定のUbuntuへSSH接続する。同じOSユーザーで`git`、`gh`、`claude`、`codex`、`flock`、`timeout`、systemd user managerを利用できることを確認する。
2. このスキルと必要な既存スキル・pstackをUbuntuへ導入する。dotfilesの`agent/skills/`が配布元で、`install.sh`は直下の`SKILL.md`を自動検出する。`apm.yml`は`includes: auto`であり、このスキル用の個別登録は追加しない。
3. 実行先で`codex exec --help`、`claude --help`、`systemd-run --help`を確認する。以下の起動例は`--expand-environment=no`を使うためsystemd 254以降を必要とする。Lunaの利用可能なmodel IDと`high`対応を確認し、実行設定へ保存する。`gpt-6-luna`は作成時のMacで確認した例であり、Ubuntuで利用可能と推定しない。他モデルへ無断で置き換えない。
4. 同じユーザーの認証と、対象repositoryの読み取り・担当branchへのpush・PR作成・実行記録更新を許可する。headlessで要求されるGit common directoryへの書き込みやネットワーク権限も事前に確認する。拒否された操作は`blocked`とし、全権限の回避フラグを追加しない。
5. SSH切断後もuser managerを維持する設定を確認する。必要な場合は管理者が`loginctl enable-linger 実行ユーザー`を設定する。systemd serviceからも認証情報と必要なPATHを利用できることを確認し、秘密値はコマンド本文へ埋め込まない。

作成時はCodex CLI `0.163.0`とClaude Code `2.1.305`のローカルhelpを確認した。Ubuntuの実機検証は別途必要となる。

## Issueから手動で再開する

以下の例は`/srv/dotfiles`にスキル、`/srv/repos/example`に対象repository、`/srv/agent-state/example`に永続の実行記録を置く。ディレクトリを実行ユーザー専用に用意し、対象repositoryと実行ホストをIssueの実行設定へ記録してから使う。

まずIssueと既存PRを取得する。番号・repository・branchは実行記録と照合する。

```bash
gh issue view 123 --repo owner/repo --json number,state,body,comments,labels
gh pr list --repo owner/repo --state all --head agent/issue-123-w01 \
  --json number,url,state,headRefName,headRefOid,baseRefName
git -C /srv/repos/example worktree list --porcelain
systemctl --user list-units --all 'dispatch-*'
```

次のロックとコマンドは手動・cronで共通にする。`flock`が取得できない場合は既存の割り当て係に任せる。ロックファイルを削除して解除しない。`timeout`の時間とAPI利用額の上限は例なので、導入先の予算に合わせる。

```bash
cd /srv/repos/example
/usr/bin/flock -n /srv/agent-state/example/dispatch.lock \
  /usr/bin/timeout 10m /usr/local/bin/claude -p \
  'Read /srv/dotfiles/agent/skills/issue-task-dispatch/SKILL.md. Reconcile only open agent-ready issues in owner/repo approved for this host. Read existing work records, systemd services, worktrees, branches and all-state PRs first. Continue existing work and launch only eligible missing work as detached systemd services. Record evidence and blockers. Do not merge, enable auto-merge, close, release or delete. Exit after this bounded reconciliation pass.' \
  --output-format json --max-budget-usd 5 \
  >> /srv/agent-state/example/dispatch.log 2>&1
```

`/usr/local/bin/claude`は例であり、実機の`command -v claude`の絶対pathを使う。実行承認はIssue本文にも必要となる。`agent-ready`ラベルを付けるだけで合意を作らない。`blocked`、`review-ready`、closedの作業を繰り返し起動しない。

## ワーカーを独立して起動する

Claudeはrepositoryごとのロック内で、既存のbranch・worktree・service・PRを照合する。新しい作業だけ、記録したbase SHAからworktreeを作る。branch名の例は`agent/issue-123-w01`、worktreeは`/srv/worktrees/example/issue-123-w01`とする。

attemptごとの専用ディレクトリに、[ワーカーへの指示書](task-records.md)を`brief.md`として保存する。指示書にはその時点のIssue仕様も含める。既存のattemptディレクトリとログは上書きしない。

以下の変数は照合済みの実行記録から設定する。`CODEX_BIN`は`command -v codex`で得た絶対path、`LUNA_MODEL`は確認済みIDとする。`UNIT`はrepositoryも含む一意な名前とし、例は`dispatch-owner-repo-123-w01-a01`となる。

```bash
systemd-run --user --expand-environment=no --unit="$UNIT" \
  --property=Type=exec --property=RemainAfterExit=yes \
  --property=RuntimeMaxSec=3600 --working-directory="$WT" \
  /usr/bin/bash -c '
    exec "$1" exec --cd "$2" --model "$3" \
      --config "model_reasoning_effort=\"high\"" \
      --sandbox workspace-write --json \
      --output-last-message "$4/result.md" - \
      < "$4/brief.md" > "$4/events.jsonl" 2> "$4/stderr.log"
  ' _ "$CODEX_BIN" "$WT" "$LUNA_MODEL" "$RUN_DIR"
```

`RuntimeMaxSec=3600`も例なのでIssueの実行時間上限に合わせる。起動時は実際のmodel・effortをログで確認する。`--sandbox workspace-write`で必要な操作が拒否される場合は、事前に認可された狭い権限設定を確認し、満たせなければ停止理由を残す。

systemdのserviceとして起動し、`--scope`・`--pty`・`--pipe`は使わない。`--expand-environment=no`でservice managerによる変数展開を止め、`$1`などの解釈をBashへ渡す。割り当て係が終了しても、service managerが実行を管理する。`systemd-run`の成功は起動成功に限り、実装の成功ではない。[systemd-run公式仕様](https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html)を参照する。

## 実行状態を照合する

```bash
systemctl --user show "$UNIT.service" \
  -p LoadState -p ActiveState -p SubState -p MainPID \
  -p ExecMainCode -p ExecMainStatus -p Result -p ControlGroup
journalctl --user -u "$UNIT.service" --no-pager -n 80
cat /proc/sys/kernel/random/boot_id
```

`running`・`activating`・`deactivating`では再起動しない。`active (exited)`は`RemainAfterExit=yes`によって終了状態が残っている場合があるので、実行中と混同しない。`ExecMainStatus`、ログ、実際のGit差分・PRを照合する。[RemainAfterExitの公式仕様](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html)を参照する。

serviceがない場合は、記録した`boot_id`と現在値、実プロセス、Git状態を確認する。再起動前の一時serviceは自動復元されると仮定しない。失敗したattemptの再実行は、旧serviceのプロセスがcgroup内も含めて終了したことを確認してから、次のattempt名で同じworktreeを使う。古いattemptやserviceを成功扱いに上書きしない。

GitHub更新前に割り当て係が落ちた場合も、一意なservice名・branch名とローカルのログから実行記録を復元する。PRがあれば新しいPRを作らず、そのheadのレビュー・CIを続ける。未pushならローカル差分とcommitを保護して不足分だけ進める。

## cronから再開する

手動の照合が通り、非対話の認証・権限・systemd起動・ログ保存を確認した後に、実行ユーザーのcrontabへ登録する。既存crontabを置換しない。次は5分ごとの例で、pathと予算は手動起動と同じにする。

```cron
*/5 * * * * cd /srv/repos/example && /usr/bin/flock -n /srv/agent-state/example/dispatch.lock /usr/bin/timeout 10m /usr/local/bin/claude -p 'Read /srv/dotfiles/agent/skills/issue-task-dispatch/SKILL.md. Reconcile only approved open agent-ready issues in owner/repo for this host. Inspect existing records, services, worktrees and all-state PRs. Launch only eligible missing work through systemd. Preserve retry budgets. Record evidence and blockers. Never merge, enable auto-merge, close, release or delete. Exit after one pass.' --output-format json --max-budget-usd 5 >> /srv/agent-state/example/dispatch.log 2>&1
```

cronはGrok BotやCursorへの接続を必要としない。毎回GitHubを読み直し、現在の作業表から再開する。cron環境でもuser managerへ接続できることを確認し、必要なら実機の`XDG_RUNTIME_DIR`などをcrontabへ設定する。推測のUIDを固定しない。

401・403、モデル未対応、上限超過、service manager不通では同じ操作を無限再試行しない。記録の`blocked`と残予算を確認する。ローカルログにしか残せない場合も、そのログを照合してから新しいattemptを判断する。

## 導入時の確認

隔離した検証用repositoryとIssueで、以下の結果を確認してから通常タスクに使う。外部操作を伴う検証はその環境で認可された範囲だけ行う。

- 同じ照合を連続で起動しても、同じ作業のworkerとPRが増えない。
- Grok Bot・Cursorを停止しても、既存workerは継続し、次回の手動・cron起動がIssueから追跡する。
- Claude停止、push直後の停止、PR作成直後の停止から、それぞれ既存成果物を再利用する。
- worker失敗、Ubuntu再起動、GitHub不通、仕様変更を成功扱いにせず、残差分と再開条件を残す。
- `review-ready`でもmerge・auto-merge・close・releaseを実行しない。

`codex exec`のJSONLと最終結果出力は[公式の非対話実行手順](https://developers.openai.com/codex/noninteractive)、effort指定は[設定リファレンス](https://developers.openai.com/codex/config-reference)を参照する。Claudeの`-p`と出力形式は[公式のプログラム実行手順](https://code.claude.com/docs/en/headless)を参照する。
