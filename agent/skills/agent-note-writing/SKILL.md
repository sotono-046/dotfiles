---
name: agent-note-writing
description: Obsidian vault へエージェント作業メモを保存するとき、または SOW、Issue 下書き、調査メモ、運用ルールなど後で再利用するドキュメントを書くときに使用する。`保存して`、`メモして`、`記録して`、`SOW作って`、`Issue下書き`、`ドキュメント化` で発火する。
---

# agent-note-writing

Sotono さんの Obsidian vault に、エージェントが扱いやすい作業メモや下書きを残すための規約。保存先、frontmatter、ファイル名、保存ゲートを揃える。

## まず判断する

| Trigger | 動作 |
| --- | --- |
| `保存して`、`Obsidianに残して`、`vaultに置いて`、`メモとして保存` | vault の `_agent/` 配下に新規ファイルとして保存する |
| `メモして`、`記録して` | 文脈上「保存」が自然なら vault に保存する。単なる要約依頼にも読める場合は、会話上のメモを出して保存前に確認する |
| `SOW作って`、`Issue下書き`、`ドキュメント化` | 原則として会話上の下書きで止める。保存語が併記された場合のみ vault に保存する |
| `Issue作って`、`PRにコメントして`、`共有Docを更新して` | この skill だけでは外部作成しない。明示指示を確認して該当 skill / tool に引き継ぐ |

SOW、Issue 下書き、調査メモ、運用ルールなどを作る場合は、保存の有無に関係なくこの skill の文体・構造・秘匿情報ルールを使う。vault へ保存するのは、保存語がある場合、または保存先パスが明示されている場合に限る。

## 保存先

MacBook では vault はここにある:

```text
/Users/sotono/Library/CloudStorage/Dropbox/Mitumine
```

Mac mini ではここにある:

```text
/Users/sotono-mini/Library/CloudStorage/Dropbox/Mitumine
```

エージェントが作るメモは vault 直下の `_agent/` 配下に置く。

```text
_agent/yy/mm/YYYYMMDDhhmmss-topic-name.md
```

例:

```text
_agent/26/05/20260519072246-agent-note-writing-guide.md
```

## ファイル作成手順

1. 現在のマシンで存在する vault パスを確認する。
   - どちらの vault パスも存在しない場合は作成しない。想定パスと確認結果を報告して止める。
2. repo 作業に関係するメモなら、作業コンテキストを実値で確認する。
   - project: ユーザー指定、作業ディレクトリ、または親ディレクトリ名から分かるプロジェクト名。不明なら `未確認`。
   - repository: `git rev-parse --show-toplevel` と `git remote get-url origin` から分かる repo 名 / URL。不明なら `未確認`。
   - branch: `git branch --show-current` で現在ブランチを確認する。値は `branch名`、`detached HEAD:<short sha>`、`非 git repo`、`なし`（repo作業でない）、`未確認`（確認不能）の優先順で明記する。
3. 現地時刻で `yy/mm` ディレクトリを決める。
4. 必要なら `_agent/yy/mm/` を作る。
5. ファイル名は `YYYYMMDDhhmmss-topic-name.md` にする。topic は短い英字 kebab-case。
6. 同じ秒に複数作る場合は topic を変えて衝突を避ける。
7. 既存ファイルへの追記より、新しいセッション単位ファイルを優先する。
8. `.obsidian/` 配下は変更しない。

## Frontmatter

vault の `_temp/agent.md` を基準にする。Templater 記法は展開済みの実値へ置き換える。テンプレートに project / repository / branch 相当の項目がある場合は、その項目名を優先して実値を入れる。現テンプレートに項目がない場合でも、repo 作業に関係するメモでは以下の項目を追加する。

```yaml
---
title: <日本語タイトル>
date: YYYY-MM-DD
tags: [agent, <topic>]
from: codex
project: <project-name or 未確認>
repository: <repo-name or repo-url or 未確認>
branch: <branch-name or detached HEAD or 未確認>
thumb:
publish: false
---
```

- `title`: Obsidian 上で内容が分かる名前。
- `date`: 作成日。`YYYY-MM-DD` の実値。
- `tags`: 話題・分類。最初に `agent` を入れる。
- `from`: ファイルを書いた主体。Codex が書くなら `codex`。
- `project`: どのプロジェクトのメモか。
- `repository`: 何のリポジトリか。repo 名だけで曖昧なら remote URL も本文に書く。
- `branch`: 何のブランチで動いているか。repo 作業でない場合は `なし`、非 git repo なら `非 git repo`、確認不能なら `未確認`。
- `thumb`: 必要なければ空。
- `publish`: 原則 `false`。

## 本文ルール

- 本文は日本語で書く。英語のコマンド、ログ、固有名詞はそのままでよい。
- repo 作業に関係するメモは、本文冒頭に `## 作業コンテキスト` を置き、プロジェクト、リポジトリ、ブランチを明記する。frontmatter に同じ情報がある場合も、本文で読める形にする。
- 事実、推測、未確認、次アクションを分ける。
- 後で再利用する読者が、会話ログなしでも背景と結論を追える粒度にする。
- 生ログ全文は避け、必要部分を要約する。長いログを残す必要がある場合は、範囲と理由を明記する。
- API キー、トークン、パスワード、cookie、個人情報、顧客情報、内部 URL は原則 redaction する。
- secret はユーザーが全文表示を求めても保存しない。必要なら source、長さ、hash、末尾数文字などの証跡で代替する。

## SOW / Issue 下書き

SOW や Issue 下書きを書くときは、保存の有無に関係なく次を含める。

- 背景
- 観測された事実
- 判断・仮説
- 対応方針
- 完了条件
- 未確認事項
- 次アクション

Issue 下書きは作成まで進めない。`Issue化` は title / body / checklist の下書きで停止し、`gh issue create` や外部投稿は明示指示後に行う。

`artifact-to-work-items` と併用する場合は、artifact から作業単位・Issue/SOW構造へ分解する工程を `artifact-to-work-items` が担当し、Obsidian 保存、frontmatter、ファイル名、再利用メモとしての文体をこの skill が担当する。

## 競合回避

Dropbox 同期を前提に、同じファイルを複数エージェントで同時編集しない。大量ファイルを一度に作る場合は事前にユーザーへ確認する。既存の重要メモを直す必要がある場合は、元ファイルを壊さず新規メモで差分や追記案を残す。

## 完了報告

保存した場合は、最後に絶対パス、タイトル、保存内容の短い要約を報告する。保存しなかった場合は、下書き作成のみで止めたことを明示する。
