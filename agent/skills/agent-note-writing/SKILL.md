---
name: agent-note-writing
description: Obsidianの作業メモや再利用するSOW・Issue下書きを、出典と作業コンテキスト付きでまとめる。
---

# Agent Note Writing

会話なしでも背景・結論・次の行動が分かる日本語のメモにする。事実・推測・未確認を区別し、生ログの代わりに必要な証拠を残す。

## 作成と保存

- `SOW作って` / `Issue下書き` は本文を作成する。保存の指定がなければ会話上で返す。
- `保存して` / `メモして` / `記録して` は文脈で保存が明らかなら実行する。明示pathや現在のvault指定を優先し、既に決まった保存先を聞き直さない。
- `Issue化して` / `Issue作って` は本文を準備して対象repoへ作成する依頼。下書きだけで止めず、利用可能なGitHub toolへ引き継ぐ。公開コメント等は [行為境界](../ci-merge-watch/references/action-boundaries.md) と今回の明示認可に従う。

## Vaultへの保存が必要なとき

保存先が未指定なら、既知のMacBookの `/Users/sotono/Library/CloudStorage/Dropbox/Mitumine` またはMac miniの `/Users/sotono-mini/Library/CloudStorage/Dropbox/Mitumine` が存在するか確認する。別vaultが会話で指定されていればそちらを使う。既知のpathが使えない場合は本文を完成させ、保存先だけ確認する。存在しない既定vaultを勝手に新設しない。

通常の新規メモは `_agent/yy/mm/YYYYMMDDhhmmss-topic-name.md`。ユーザーが既存メモへの追記・更新を依頼した場合はそのファイルを編集し、無関係な本文や設定を保護する。`.obsidian/` はこの作業で変更しない。同じファイルを複数agentで同時編集しない。

## 作業コンテキスト

repoに関するメモはproject、repository、branchを実値で確認し、frontmatterと本文冒頭に記載する。不明な値を推測せず `未確認`、非Gitなら `非 git repo` とする。利用先の既存テンプレートがあれば項目名を合わせる。

```yaml
---
title: <日本語タイトル>
date: YYYY-MM-DD
tags: [agent, <topic>]
from: <作成agent>
project: <project>
repository: <repo>
branch: <branch>
publish: false
---
```

SOW/Issue下書きには背景、観測事実、判断・対応方針、完了条件、未確認事項と次アクションを、規模に合う短さで含める。単純なメモに空の見出しを増やさない。

secret、token、cookie、個人/顧客情報はメモへ転載しない。必要な根拠は安全な出典やredacted excerptで示す。公開してよいURLか不明な内部URLも伏せる。

## 完了

保存した場合は絶対path、タイトル、要約を返す。外部作成まで依頼された場合は作成先URLと状態を示す。本文作成のみ、保存不能、未実行の外部操作を完了済みと混同しない。
