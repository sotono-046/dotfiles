---
name: pr-base-sync
description: 対象PRのbranchへ最新baseをmergeし、競合と互換性を確認する。PR-checkやbase取り込み依頼で使用する。
---

# PR Base Sync

PR metadataのbaseを取り込み先の正本にする。project指定と違う場合は差異を示し、誤ったbaseへmergeしない。

1. repo、PR、head/base branch、head SHA、remote owner、local status/HEAD/upstream、進行中Git操作を確認する。branch名だけの一致で対象を決めない。
2. checkout不一致やdirty、既存merge/rebase中ならその作業を保持し、必要に応じてexact PR headから隔離worktreeを作って続ける。自動stash/reset/commitで既存作業を片づけない。
3. 対象remoteをfetchし、remote-tracking base SHAを記録する。local baseへのcheckout/pullは不要。
4. merge直前に作業先のclean status、HEAD、進行中操作、freshなPR headとbase SHAを再確認する。PR更新があれば再固定してから `git merge --no-edit <remote>/<base>` を行う。
5. 競合は依頼範囲と仕様から解決できるものを修正し、両branchの意図を検証する。仕様/認可が決められない競合だけ保留する。中断が必要なら、今回開始したmergeで後続編集を失わないと確認できる場合に限りabortできる。
6. project必須checkと変更に合うfocused test/type-check/lintで互換性を確認する。必要なcommitは [git-ops](../git-ops/SKILL.md) に従い、所有pathを明示stageする。

rebase、force push、branch削除はこの依頼に含めない。pushまで認可されていれば更新後のheadとCIを確認し、なければローカル完了として報告する。既に最新なら有効なno-opとする。

完了報告にはPR、head/base SHA、merge結果、競合解消/未解決、検証結果、push状態を含める。
