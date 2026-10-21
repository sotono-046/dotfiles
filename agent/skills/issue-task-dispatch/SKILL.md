---
name: issue-task-dispatch
description: Grok Botとの会話で合意した開発タスクをGitHub Issueに記録し、Tailscale越しのUbuntuでClaude Codeが分割、Codex Luna Highがworktreeごとに実行する。司令塔の停止後にIssueから手動・cronで再開する運用に使う。成果物は検証済みPRまでとし、merge・close・releaseは人間が行う。
---

# Issue task dispatch

Grok BotやCursorのセッションが終了しても、確定済みのIssueから実行を再開する。会話でのタスク決定と、Ubuntuでの割り当て・実装を分ける。このスキルを追加しただけでは、Ubuntuへの導入やcronの登録は行われない。

## 役割と判断の所在

| 担当 | 行うこと | 引き継ぐ記録 |
| --- | --- | --- |
| Grok Bot、Outer Loop | ユーザーとの会話で文脈を蓄え、意図・対象範囲・完了条件を一緒に決める | 合意済みの内容をIssue本文へ記録し、Projectsに関連付ける |
| Claude Code、割り当て係 | Issueを読み、完了条件を変えずに作業単位へ分割し、依存関係と担当を決める | 作業表、実行記録、PRと検証結果 |
| Codex、Luna Highワーカー | 作業単位ごとのworktreeで実装・検証し、担当差分をcommit・pushしてPRを作る | exact SHA、PR URL、検証結果、未解決事項 |
| 人間 | 意図や範囲の変更を会話で決め、成果物を受け入れる | merge、Issue・PRのclose、release |

実行時の正本はGitHub Issue本文の合意済み仕様とする。ProjectsはそのIssueに結び付いた進捗表示として使う。会話の未確定案を実行待ちに入れない。ProjectsとIssueの表示が食い違ったら、Issueと実際のPR・プロセスを照合して進捗表示を修正する。

Grok Botが停止した場合は、人間と代替の会話環境で新しい意図を決めてIssueに反映する。割り当て係やcronが推測で完了条件を追加・変更しない。実装上の分割だけなら、既存の合意範囲でClaudeが決めてよい。

## 開始前の確認

1. 対象repository、Issue、base branch、実行するUbuntuホストとOSユーザーを固定する。Tailscale経由でSSH接続し、GitHub・Claude Code・Codexの認証と権限を同じ実行ユーザーで確認する。
2. [Issueとワーカーの記録形式](references/task-records.md)で意図・範囲・完了条件・実行承認を確認する。不足する判断は`blocked`として残し、独立して進められる作業だけ続ける。
3. repositoryの`AGENTS.md`、既存差分、既存PR、worktree、実行中のserviceを読む。今回指定のClaude割り当て係とLuna Highワーカーを、他スキルの既定モデルより優先する。
4. 以下のスキルを実行環境で発見し、必要な段階で本文を読む。未導入のものを実行済みと扱わず、必要な段階を`blocked`として不足を報告する。

| 段階 | 実在するスキル・原則 | 使い方 |
| --- | --- | --- |
| 設計 | `pstack:architect` | 非自明な設計を先に整理し、担当path・入出力・依存関係を決める |
| 分配 | `pstack:swarm` | 独立した作業へ分割し、各ワーカーに完了条件・専用worktree・返却物を渡す |
| 再開 | `pstack:principle-make-operations-idempotent` | 現在のPR・branch・serviceを読み、必要な差分だけ実行する |
| 完了確認 | `pstack:principle-prove-it-works` | ワーカーの返答だけに頼らず、実際のPR・SHA・検証結果を確認する |
| 独立レビュー | `pstack:interrogate` | 実装者とは別のコンテキストから、現PR headの実害・見落としを確認する |
| 指摘の採否 | [review-go-nogo](../review-go-nogo/SKILL.md) | 重大な実害と任意改善を分ける。正式名称は`review-go-nogo` |
| Git操作 | [git-ops](../git-ops/SKILL.md) | 担当差分だけのcommit・push・日本語PR作成に使う |
| CI確認 | [ci-merge-watch](../ci-merge-watch/SKILL.md) | 監視、承認範囲内の修正、現headの再確認まで。mergeは実行しない |
| worktree整理 | [git-worktree-safe-audit](../git-worktree-safe-audit/SKILL.md) | 人間の整理判断に先立つ読み取り専用監査に使う |

pstackは外部プラグインとして導入先を確認する。Macのバージョン付きキャッシュpathをUbuntuへ固定しない。各スキルが参照する追加スキルも必要時に確認する。モデルや実行環境の既定値が今回の指定と異なる場合は、今回の指定を優先する。

## 分割と実行の所有権

Claudeは各作業に安定した`work_id`を割り当て、Issueの作業表に記録する。再開しても同じ作業を別のIDへ作り直さない。各作業は専用branchとworktreeを1つ持つ。依存する作業は直列にし、同じpathを同時に編集させない。別worktreeでもGitの管理情報は共有されるため、worktreeの追加・削除は割り当て係だけが行う。

実行ホストは1台に固定し、手動起動とcronが同じrepository用`flock`を使う。GitHubのラベルやコメントには原子的な取得保証がないため、それらをロックとして使わない。別ホストへの引き継ぎは、旧ホストが実行・pushできないことを人間が確認してから行う。接続不能だけでは引き継がない。

ワーカーはUbuntuのsystemd user serviceから起動する。割り当て係の子プロセスとして放置したり、SSH接続やCursorの生存だけに依存させたりしない。実行単位は`repository / Issue番号 / work_id / attempt`とし、service名とログ保存先もそこから一意に決める。[Ubuntuでの起動と再開](references/ubuntu-runbook.md)を使う。

Issueと実行記録に、同時実行数、実行時間上限、試行回数上限を残す。開始直後に、現在の実行数・実行可能な作業・依存待ち・次に確認する結果を記録する。上限に達した作業は`blocked`にし、cronの次回起動で試行予算をリセットしない。

## 実行ループ

1. Grok Botとユーザーがタスクに合意したら、確定内容をIssue本文に書く。準備済みラベル`agent-ready`は実行承認済みのIssueにだけ付ける。Projectsのfield名・IDは導入先で確認する。
2. Claudeはロック取得後に、承認済みのopen Issueを読み直す。既存作業表があれば先に再開判定を行い、不足分だけ分割・登録する。各完了条件を担当作業と検証へ対応付ける。
3. Claudeは確定したbase SHAから専用branch・worktreeを用意する。存在する場合は対応関係と状態を確認して再利用する。既存差分のreset・clean・一括stashはしない。
4. 起動前に作業表へ`attempt`とservice名、worktree、branch、仕様の`spec_revision`と本文のdigestを記録する。その後serviceを起動する。起動前後に停止しても、この記録とserviceの実在を照合して続ける。
5. Luna Highワーカーは指示書から実装・検証する。範囲や完了条件が変わっていたら作業を止め、Claudeに判断を返す。commit・push・PR作成の前にもIssueの仕様を照合する。
6. 完了条件を満たしたら、担当差分だけをcommit・pushする。同一branchの既存PRを全stateから確認し、open PRがあれば再利用する。PR本文は`Refs #番号`で関連付け、`Fixes`・`Closes`・`Resolves`などの自動close指定は使わない。
7. Claudeは実際のPR・SHA・検証結果を取得し、独立レビューとCI確認を行う。修正が必要なら同じ作業へ記録を追加して返す。head更新後の判定には新しいheadの証拠を使う。
8. 必須検証とレビューが済んだら`review-ready`を記録し、人間へPRを渡す。Issueはopenのままにする。実行不能・認証失敗・予算超過は理由と再開条件を残す。

ワーカーのexit code 0や「完了」という返答だけで、PR作成や完了条件達成を判定しない。変更不要の場合も、実コード上の根拠と検証結果を残して人間へ返す。

## 停止後の再開判定

Grok Bot、Cursor、Claude Codeの会話履歴やsession IDがなくても、Issueから次を照合する。session resumeは補助として使い、仕様や実行状態の代わりにしない。

| 確認した状態 | 次の行動 |
| --- | --- |
| serviceが実行中、または停止処理中 | 起動を追加せず、既存の実行を監視する |
| 起動記録あり、serviceなし | 同一ホストの再起動・既存プロセス・PR・branchを調べ、未起動か停止済みかを確かめる |
| service終了、ローカル差分やcommitあり、PRなし | 変更と検証を確認し、同じbranchから不足するcommit・push・PR作成だけ進める |
| push済み、PR記録なし | repositoryとhead branchで全stateのPRを検索し、存在するPRを記録する |
| open PRあり | 再実装せず、現headのレビューとCIから続ける |
| PRがclosedまたはmerged | 自動再作成・reopenしない。人間の判断とIssueの実際の状態を記録する |
| worker失敗・時間超過 | ログと残差分を保全し、プロセスの終了を確認する。予算内で修正方針がある場合だけ次のattemptを起動する |
| GitHub、Ubuntu、認証へアクセスできない | 新しい割り当てを止める。既存workerの生存を推測せず、復旧後に再照合する |

Ubuntu再起動後は一時serviceが消えていても、永続ディスクの作業とGitHubを照合する。GitHubと実行ホスト自体の障害を自動で解消するスキルではない。未pushの作業はホストの永続ディスクとバックアップに依存する。

## 人間への引き渡し

Issue URL、各作業のPR URLとexact head SHA、完了条件ごとの検証、required CI、レビュー判断、残件、再開方法を短く返す。merge・auto-merge設定・close・release・自動削除は行わない。整理時も監査結果だけでworktreeを削除しない。
