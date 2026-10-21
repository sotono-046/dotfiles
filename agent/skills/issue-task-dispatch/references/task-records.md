# Issueとワーカーの記録形式

## Issue本文

会話で合意した内容をこの形式で記録する。例の値は導入先で決める。未確定項目が完了条件に影響する場合は、`agent-ready`を付けない。

```markdown
## 合意済み仕様

- spec_revision: 1
- 意図・背景:
- 対象repositoryとbase branch:
- 対象範囲:
- 対象外:
- 完了条件:
  - [ ] AC-1 実行結果で判定できる条件
- 検証方法と必要な証拠:
- 実行承認の根拠となる会話の合意:
- 外部操作の範囲: 担当branchへのcommit・push、PR作成、実行記録の更新
- 人間が行う操作: merge、close、release

## 実行設定

- executor_host / os_user:
- repository_path / state_directory:
- max_parallel / max_attempts_per_work / max_runtime_seconds:
- 確認済みLuna model ID / reasoning effort: 実環境のID / high
- Projects URLと既存fieldへの状態対応:

## 作業表

| work_id | 対応AC | 担当path・成果物 | 依存work_idと解除条件 | branch・worktree | 状態 | 最新実行記録 |
| --- | --- | --- | --- | --- | --- | --- |
| w01 | AC-1 | | なし | | ready | |
```

依存の解除条件は「先行PRのheadに基づいて検証可能」か「人間がmergeした後」かを明記する。後者ではmergeを自動化しない。単に先行workerが終了しただけでは解除しない。

仕様を変更するときは会話で合意し、`spec_revision`を進める。digestはIssue全体ではなく「合意済み仕様」節だけのUTF-8本文からSHA-256で算出する。作業表の更新で仕様変更を誤検出しない。変更時は実行中作業の受入れ判定を保留し、新仕様との対応を確認してから再開する。

## 実行記録

割り当て係はIssueコメントに次の情報を記録し、作業表からそのコメントへリンクする。ワーカーは自分の実行先へ結果を書き、共有の作業表は更新しない。割り当て係が停止しても、次の割り当て係が記録を復元する。

```text
repository / issue_number / work_id / attempt:
spec_revision / spec_digest / base_sha:
executor_host / os_user / boot_id:
systemd_unit / branch / worktree / run_directory:
actual_model / reasoning_effort:
state / started_at / checked_at / finished_at:
exit_code / commit_sha / pr_url:
acceptance_evidence / validation_commands_and_results:
reviewed_head_sha / required_checks / review_verdict:
failure_reason / attempts_used / remaining_budget / next_action:
```

`ready`は承認済みかつ依存解決済み、`running`は実プロセス確認済み、`pr-open`はPR実在確認済み、`review-ready`は必須検証・独立レビュー・現headのCI確認済みとする。`blocked`には原因と再開条件を付ける。人間によるmerge・closeは別の事実として記録し、`review-ready`を`done`に読み替えない。

GitHubへ記録できない間は、既存workerのログをローカルに保全する。新規割り当てやPR作成を進めず、復旧後に実状態を照合して記録を反映する。認証情報や生の秘密値はIssue・PR・ログへ含めない。

## ワーカーへの指示書

```text
Issue URLと取得した合意済み仕様、spec_revision、spec_digest:
work_id / attempt / systemd_unit:
目標と対応する完了条件:
担当path / 対象外path / 依存関係:
worktree絶対path / branch / base SHA:
実際のmodel ID / reasoning effort high:
必要なスキルの発見済み絶対path:
検証コマンドと保存する証拠:
実行時間・試行回数の残予算:
commit・push・PR作成の認可範囲:
結果の保存先と返却形式:

最初にAGENTS.mdと既存差分を読む。担当作業だけを実装・検証する。
仕様が変わった場合や判断が不足する場合は、理由と残差分を記録して止める。
検証を満たしたらgit-opsを読み、担当差分だけcommit・pushしてPRを作る。
PRは全stateから先に検索する。closed・mergedなら自動再作成しない。
Issueとの関連はRefsを使う。merge・auto-merge・close・release・削除は禁止。
変更path、exact SHA、PR URL、検証結果、未解決事項を結果に残す。
```
