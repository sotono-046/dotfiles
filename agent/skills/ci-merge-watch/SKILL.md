---
name: ci-merge-watch
description: PRのCIとレビューを確認し、依頼された失敗修正・更新・mergeまで進める。監視だけの依頼では状態変更しない。
---

# CI / Review / Merge

まず [行為境界](references/action-boundaries.md) で依頼の完了地点を決める。`マージまで` はmerge可能で停止し、`マージして` はmergeまで実行する。

## 対象を固定する

PR URL/番号、明示head branch、Checksのrun/SHA、現在checkoutの順で候補を探す。branch名だけで決めず、repository owner、head repository、head SHA、base、stateを確認する。複数候補ならread-only調査を進め、対象が一意になるまで状態を変更しない。closed/merged PRは履歴確認に限り、再度修正・ready・mergeしない。

local checkoutが別branchやdirtyなら既存差分を保護する。ローカル編集が必要な場合は確認済みPR headから隔離worktreeを用意し、依頼内の作業を続ける。remoteの状態照会だけにclean checkoutを要求しない。

## 確認・修正

- 現headのrequired checks、レビュー判断、unresolved threads、merge conflictを確認する。短い状態照会は直接行う。
- 長時間監視や独立した大量ログ調査は、並列化が有益で利用可能な場合に委譲する。[runtime adapter](../task-orchestration/references/runtime-adapter.md) を必要時に読む。1 PRにつき監視役は1体、待機上限と停止条件を指定する。
- 修正依頼があれば失敗原因をtest / type-lint / setup / flaky-externalに分類し、最小の再現と関連検証で修正する。commit/pushは [git-ops](../git-ops/SKILL.md) に従う。
- レビューは [review-go-nogo](../review-go-nogo/SKILL.md) で分類する。対応済みthreadだけ、対応commitと検証の根拠を確認してResolveする。判断待ち・未修正・理由付き非対応は残す。新規コメント投稿は明示依頼がある場合だけ。
- headが更新されたら旧headのcheck結果を無効にして再確認する。生ログを大量に返さず、失敗check/run、原因、最小抜粋を示す。secret/PIIは引用しない。

## 状態変更直前の確認

各操作に必要な証拠をfreshに取得する。PR headが変わったら対象を再固定し、古い判断で続行しない。

| 操作 | 必要な確認 |
|---|---|
| push | local status/HEAD/upstream、repoとPR branchの対応、remote PR headが想定したpush前SHAのまま。今回の変更がcommit済みで、push元がclean |
| CI rerun | 対象runのrepository/head SHAと現PR headが一致し、rerunの認可と理由がある。成功checkやclean local checkoutは前提にしない |
| Resolve | 現PR head、対象threadの最新内容、対応commitがheadに含まれること、修正に必要な検証。無関係なpending checkやdirtyな別checkoutだけでは止めない |
| ready | 現PR head/state/draftと依頼で求めたCI・レビュー条件。draft中に起動しないcheckならその仕組みを確認し、ready後に監視 |
| merge | 現PR head/base、同headのrequired checks成功、必要approval/branch protection、NO-GOゼロ、conflictなし。取得不能/pendingならmerge保留 |

required checksがない場合はnoneと記録する。CIの成功やapprovalを捏造せず、失敗を握りつぶさない。merge方法はユーザー指定・repository慣習を優先し、指定がなければ利用可能なsquashを既定候補にする。branch削除は別認可を要する。

## 完了

依頼の完了地点に達したらPR URL、head SHA、checks、NO-GOとfollow-up、実行した更新を返す。P2の任意指摘をゼロにするために監視を延長しない。待機上限や外部blockerに達した場合は現在状態と再開条件を示し、成功扱いにしない。
