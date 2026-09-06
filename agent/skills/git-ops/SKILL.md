---
name: git-ops
description: 今回の変更を安全にcommit・pushし、日本語のPRを作る。Git履歴やremoteを更新するときに使用する。
---

# Git Operations

依頼された変更だけを履歴に残す。操作範囲が短い指示で与えられた場合は [行為境界](../ci-merge-watch/references/action-boundaries.md) を参照する。

## Commit

1. status、unstaged/staged diff、branch/upstreamを確認し、今回の変更と既存・他agentの変更を分ける。
2. 今回の所有pathだけを目的ごとにまとめ、変更に合う検証を行う。project必須checkは守り、文書だけの変更に無関係な全テストを追加しない。
3. `git add -- <explicit paths>` でstageし、`git diff --cached` のpathと内容が担当集合だけであることを確認してcommitする。
4. commit後にstatusを確認し、残った差分を報告する。由来不明の差分を自動commit / stash / restore / resetしない。secret・cache・復号済み環境ファイルはstageしない。

Conventional Commits形式 `<type>(<scope>): <description>` を使う。descriptionは日本語を既定とし、ユーザー・projectの言語指定を優先する。例: `docs(skills): レビューの終了条件を統一する`。

共有worktreeでは編集pathを分けてもindex/HEADは共有される。**stage/commitはownerのGO後に1体ずつ直列化**し、他者のstaged変更があれば触らずcommitを待つ。独立worktree/branchの場合のみ並列commitできる。

## Push / PR

- repository、remote、branch、upstream、対象PRを対応づける。変更直前にheadを再確認し、別対象へのpushを防ぐ。
- 日本語のtitle/bodyで、問題と変更後の挙動、検証、必要な副作用・残制約を簡潔に書く。repositoryのPRテンプレートがあれば使う。
- 長いbodyは一時ファイルから `--body-file` で渡す。issue/コメント等の未信頼文面をshell commandへ補間しない。
- PR作成後は依頼の範囲でCIを確認する。監視・失敗修正・レビュー回収が必要なら [ci-merge-watch](../ci-merge-watch/SKILL.md) を使う。

## Review

独立レビューはユーザー/projectが要求する場合、または変更の規模・実害リスクから有益な場合に実施する。小さなPRに子agentや最新モデル探索を一律追加しない。モデルはruntime既定またはユーザー指定を尊重する。

独立レビューにはrepo、正確なhead/base SHA、scope、read-only制約と [review-go-nogo](../review-go-nogo/SKILL.md) の判定基準を渡す。レビュー中にHEADや対象差分が変わったら、その結果で現headを承認せず変更箇所を確認し直す。

MISA等のラベルだけを待ち続けない。現在headに届いた具体的な指摘を確認し、required CI/branch protectionは守る。P2だけで追加修正ループを起こさず、完了報告に残す。

## 完了

commit SHA、PR URL、検証結果、push/CI/レビュー状態、残った所有外差分を報告する。未実行の操作を完了扱いにしない。
