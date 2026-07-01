# リポジトリガイドライン

## プロジェクト構成

このリポジトリは個人用 dotfiles とエージェント設定を管理します。ルート直下の `.zshrc`、`.tmux.conf`、`starship.toml`、`zellij.conf`、`zellij.kdl`、`ccstatusline.json`、`Brewfile`、`install.sh` はユーザー環境に直接反映される設定です。`raycast/` には Raycast 用の補助スクリプトがあります。`agent/` は Codex / Claude 向け設定で、`agent/skills/` は skill パッケージ、`agent/commands/` は slash command プロンプト、`agent/agents/` は subagent 定義、`agent/settings.json` はツール権限と hook を管理します。`agent/` 配下を変更するときは `agent/AGENTS.md` にも従ってください。

## 開発・検証コマンド

- `./install.sh`: dotfiles を所定の場所へ symlink し、ローカルツールをインストール / 設定します。
- `brew bundle --file Brewfile`: このリポジトリで宣言した Homebrew 依存関係をインストールします。
- `zsh -n .zshrc install.sh raycast/*.sh`: shell スクリプトを実行せずに構文チェックします。
- `git diff --check`: commit 前に whitespace error を検出します。

単一の build step はありません。触った設定に応じて最小限の検証を行い、そのうえで上記の軽量チェックを実行してください。

## コーディングスタイルと命名

セットアップや自動化は shell script を基本とし、`#!/usr/bin/env zsh` または既存ファイルの interpreter style に合わせます。shell の制御ブロックは 2 space indentation を優先し、凝った書き方より読みやすい command を選びます。意図的な word splitting が必要な場合を除き、path と variable は quote してください。新しい command や skill directory は、`agent/skills/git-ops` や `agent/skills/ci-merge-watch` に合わせて lowercase hyphenated name を使います。Markdown は簡潔な見出し、例、直接的な指示を優先します。

## テストとレビュー方針

変更内容に対して最も狭く安全な検証を実行します。shell を編集した場合は、対象 script に `zsh -n` を通し、可能なら実環境に影響しない一時環境で command を実行します。agent skill や command を編集した場合は、Markdown の表示、参照 path、script、trigger phrase が存在することを確認します。新しい skill、slash command、エージェント向けプロンプトを作成または大幅改訂した場合は、別エージェントによる実行レビューで不明瞭点を洗い出してからブラッシュアップしてください。install 周りの変更では、`./install.sh` を走らせる前に symlink target を dry review してください。

## Commit と Pull Request

Git history は `feat(starship): ...`、`fix(zshrc): ...`、`docs(skills): ...`、`chore(plugin-creator): ...` のような Conventional Commit style を使います。commit は対象領域ごとに小さく保ってください。Pull Request では、影響する設定または agent workflow、実行した検証 command、symlink 変更・package install・permission 更新などローカルマシンへの副作用を説明します。

## Security と設定管理

machine-local secret、private token、generated cache、復号済み environment file は commit しないでください。`agent/settings.json` の permission 変更は最小限にし、広い tool access が必要な理由を説明します。
