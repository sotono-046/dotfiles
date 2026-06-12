---
name: tmux-agent-bridge
description: tmux 経由で別ペインの Claude Code / Codex / その他 REPL エージェントへプロンプトを送って協調動作させる運用スキル。送信は必ず「本文 → 別コマンドで Enter」の 2 段送信で行い、ペースト混入や送信漏れを防ぐ。`tmuxでClaudeに送る`, `tmuxでCodexに投げる`, `別ペインのエージェントに指示`, `tmux send-keys`, `tmuxでエージェント連携`, `司令塔から子エージェント` で使用する。
---

# tmux Agent Bridge

tmux の別ペイン / 別 window / 別 session で動いている対話的エージェント（Claude Code, Codex CLI, `cursor-agent` interactive, aider, REPL 全般）に対して、現在の司令塔エージェントからプロンプトを送信して協調作業させるための運用スキル。

ヘッドレス実行（`claude --print`, `cursor-agent --print` など）が使える場合はそちらが第一選択。本スキルは **すでに対話的に立ち上がっているエージェントに後から指示を流し込みたい** ケース、または **複数のエージェントを画面上で並走させて人間が観察したい** ケース向け。

## `tmux-ide` との関係（併用前提）

本スキルは「立ち上がっているエージェントに指示を送る運用」だけを担当する。**tmux のレイアウト構築（session / window / pane の作成、Claude や dev server の自動起動）は `tmux-ide` スキルを使う**。

- レイアウト構築 → `tmux-ide`：`ide.yml` に pane と起動コマンドを宣言し、`tmux-ide` で起動 / `restart` / `validate`。Claude Code の Agent Teams 機能（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）の前段としてのペイン整備もこちら。
- 司令塔 → 各ペインへの指示送信 → 本スキル：`tmux-ide` が並べた pane id を `scripts/tmux-agents-list.zsh` で拾い、`scripts/tmux-send.zsh` で本文 + 別 Enter の 2 段送信。

注意：`tmux-ide` の Agent Teams は Claude Code 内部のチーム機能に依存していて Codex には効かない。Codex を混ぜたい / 任意タイミングで外部から送り込みたいときは本スキルが必要。

## 鉄則 — 必ず Enter を別コマンドで送る

`tmux send-keys` で長い本文と `Enter` を同じコマンドで送ると、以下のトラブルが頻発する。

- 改行を含む本文の途中で勝手にコマンドが実行される
- bracketed paste mode が中途半端に解除されて入力が壊れる
- Claude Code / Codex 側が「ペースト確認」を出して止まる
- 末尾の `Enter` が消えて入力欄に残ったままになる

したがって **必ず本文と Enter を分けて 2 回 send-keys する**。本スキルで提供する `scripts/tmux-send.zsh` は常にこの 2 段送信を行うので、原則これを経由すること。

```zsh
# OK — 本文と Enter を分ける
tmux send-keys -t "$PANE" -l -- "$BODY"
sleep 0.15
tmux send-keys -t "$PANE" Enter

# NG — 本文に Enter を混ぜる
tmux send-keys -t "$PANE" "$BODY" Enter   # ← 本文中の改行で誤発火する
```

ポイント:

- `-l` (literal) を付けて本文中の `;` や `$` を tmux のキー名として解釈させない
- 本文送信と Enter の間に **100〜200ms の sleep** を入れる（ターミナル側の bracketed paste 終端処理を待つ）
- 改行を含む本文は `tmux load-buffer` + `paste-buffer` を使うとさらに安定する（`scripts/tmux-send.zsh` の `--paste` モード）

## 提供スクリプト

### `scripts/tmux-send.zsh`

引数:

```
tmux-send.zsh <target-pane> <message...>
  --paste              # load-buffer + paste-buffer を使う（複数行・長文向け）
  --no-enter           # 末尾の Enter を送らない（手で確認したいとき）
  --wait <seconds>     # 本文送信と Enter の間の待機（既定 0.2s）
  --pre-enter          # 送信前に一度 Enter を打って入力欄をクリアする
  --stdin              # メッセージを stdin から読む
```

target-pane は `session:window.pane` 形式（例: `agents:0.1`）または `%12` 形式の pane id。`tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} #{pane_current_command}'` で確認できる。

### `scripts/tmux-agents-list.zsh`

現在動いている tmux ペインのうち、Claude Code / Codex / cursor-agent / aider と思われるものを列挙する。pane_current_command と pane_title を見て判定する。

```
SESSION:W.P  PANE_ID  COMMAND    TITLE
agents:0.1   %12      node       claude
agents:0.2   %13      codex      codex
```

## 標準ワークフロー（司令塔 → 子エージェント）

1. **対象ペインを特定する**
   `scripts/tmux-agents-list.zsh` を実行し、送り先の pane id を確定する。複数候補があれば必ずユーザーに確認する。誤爆を避けるため、`tmux display-message -t <pane> -p '#{pane_current_command} #{pane_title}'` で最終確認する。

2. **入力欄をクリアする（任意）**
   既に入力欄に何か残っていると本文の頭に混ざる。心配なときは `--pre-enter` を付けるか、`tmux send-keys -t <pane> C-c` で空にしてから送る（C-c は実行中タスクを中断するので、相手が idle なときだけ）。

3. **task packet を作る**
   送信内容は自己完結にする。司令塔の暗黙の文脈は子エージェントから見えない。テンプレ:

   ```markdown
   You are working in pane <pane-id> coordinated by the orchestrating agent.

   Repo: /absolute/path
   Goal: <達成したいこと>
   Scope: <触ってよい範囲 / 触らない範囲>
   Constraints:
   - Do not commit/push unless told
   - Stop and report if scope is unclear
   Deliverable: <返してほしい形式>
   ```

4. **送信する**
   長文や複数行を含むときは `--paste` を使う:

   ```zsh
   ./scripts/tmux-send.zsh agents:0.1 --paste --stdin <<'EOF'
   <task packet>
   EOF
   ```

   1 行の短い指示なら直接引数で渡してよい:

   ```zsh
   ./scripts/tmux-send.zsh agents:0.1 "テスト走らせて結果だけ貼って"
   ```

5. **送信後に状態を確認する**
   送ったつもりで Enter が落ちていないことがあるので、数秒待ってから `tmux capture-pane -t <pane> -p -S -40` で末尾を確認する。プロンプト末尾にメッセージが残っているなら Enter を追い送りする:

   ```zsh
   tmux send-keys -t <pane> Enter
   ```

6. **応答を取得する**
   子エージェントの応答は `tmux capture-pane -t <pane> -p -S -200` でスクロールバック込みで吸い出し、司令塔側で要約・レビュー・次の指示生成に使う。長時間応答待ちなら `tmux capture-pane` を一定間隔でポーリングする。

7. **検証と合流**
   子エージェントが編集したファイルは司令塔側で `git diff` してレビューする。コミットや PR 作成は司令塔がやる（`git-ops` skill 参照）。子エージェントには破壊的操作を委ねない。

## デフォルトの役割分担（番号ベース）

ユーザーから明示的な役割指定がない場合、**pane 番号で役割を固定する**。

- **1 番（pane index 0、または `tmux-ide` の lead pane）= 司令塔 / レビュー役**
  意図整理、タスク分割、task packet 作成、差分レビュー、検証、Git 管理を担当。コード編集は原則しない。
- **2 番（pane index 1、または最初の teammate pane）= 実装役**
  司令塔から受け取った packet に従ってコード編集 / テスト追加 / 機械的修正のみを行う。スコープ拡大・設計判断・Git 破壊的操作はしない。
- 3 番以降がある場合は追加の実装役 or レビュー専任として、司令塔（1 番）が起動時に役割を割り当てて宣言する。

### 自分の番号を把握する

各エージェントは作業開始前に**自分がどの pane にいるかを必ず確認する**。これを怠ると 1 番が実装を始めたり、2 番がレビュー指示を出したりして役割が崩れる。

```zsh
# 自分の pane id と index を取得
echo "pane_id=$TMUX_PANE"
tmux display-message -p '#{session_name}:#{window_index}.#{pane_index} id=#{pane_id} title=#{pane_title}'
```

- `$TMUX_PANE` は tmux が自動で各 pane の環境変数にセットする pane id（例: `%12`）。
- `#{pane_index}` が 0 なら自分は 1 番（司令塔）、1 なら 2 番（実装役）。
- `tmux-ide` 経由なら `pane_title` の `Lead` / `Teammate N` でも判別可能。

判定結果はセッション中の自己認識として保持し、自分の役割と異なる依頼が来たら**実行する前に役割確認を返す**こと（例: 2 番が「全体設計を考えて」と言われたら司令塔に差し戻す）。

## マルチエージェント並走

複数のエージェントを別ペインで並走させる場合の指針:

- **同じファイルを同時に編集させない**。ファイル分割か、worktree 分割で衝突を防ぐ（`task-orchestration` の原則）。
- pane title を `tmux select-pane -t <pane> -T "claude:frontend"` のように意味あるラベルにしておくと list が読みやすい。
- 各エージェントには「自分のペイン id」「担当範囲」「他のエージェントとは独立に動け」を最初の packet に書く。
- 終了同期は司令塔がポーリングで取る。各エージェントに `DONE:<short-tag>` のような sentinel 文字列を最後に出力させ、`capture-pane` で grep する。

## tmux 周りの実用コマンド集

| 目的 | コマンド |
| ---- | -------- |
| 全ペイン一覧 | `tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} #{pane_current_command} #{pane_title}'` |
| 特定ペインの末尾を見る | `tmux capture-pane -t <pane> -p -S -100` |
| 特定ペインに改行だけ送る | `tmux send-keys -t <pane> Enter` |
| 特定ペインを中断 | `tmux send-keys -t <pane> C-c` |
| ペイン名をつける | `tmux select-pane -t <pane> -T "<label>"` ＆ `set -g pane-border-format '#T'` |
| 新規 window で claude を起動 | `tmux new-window -n claude 'claude'` |
| 新規 pane を縦分割で開く | `tmux split-window -h -t <window> 'codex'` |
| pane を kill | `tmux kill-pane -t <pane>` |
| session ごと切り離す | `tmux detach -s <session>` |
| 既存セッションにアタッチ | `tmux attach -t <session>` |

## よくある失敗と対処

- **本文が途中で実行される** → 本文に裸の Enter / Return が混ざっている。`--paste` モードで送り直す。
- **Enter が効かない / 入力欄に残る** → ターミナル側が bracketed paste 待ち。100〜300ms 待ってから `tmux send-keys -t <pane> Enter` を追加で叩く。
- **「Paste detected, press Enter to send」みたいな確認が出る** → Claude Code 側のペースト確認。これも Enter を 1 回追加で送れば抜ける。`tmux-send.zsh` は paste モードのとき自動でこの追い Enter を打つ。
- **送り先を間違えてシェルに流し込んだ** → 即 `C-c`。シェル履歴を汚した場合は `history -d` で削る。
- **送ったのに反応がない** → 対象ペインが裏 window のときフォーカスが要らないが、`pane_in_mode=1`（コピーモード中）だと入力を受け付けない。`tmux send-keys -t <pane> -X cancel` でコピーモードを抜けてから再送。
- **改行 1 つで送信される設定 (Codex 等)** → 本文を分割して送らない。`--paste` で 1 ブロックとして流し込む。

## 制約

- このスキルは送信側の運用ルールであり、相手エージェントの応答品質は保証しない。
- 認証ダイアログや TUI モーダル（権限プロンプトなど）は `send-keys` で抜けられないことがある。その場合はユーザーに対応を依頼する。
- macOS の Terminal.app / iTerm2 / WezTerm で動作確認。Linux でも tmux 3.x なら同様に動くはず。
