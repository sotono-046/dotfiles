# Herdr マルチエージェントチーム編成（司令塔方式）

複数 pane の agent を「司令塔・参謀・レビュー・ハーネス・実行役」に役割分担させ、実装→レビュー→検証のループを回すための実践パターン。yuyu-mirai の STT 修正セッション（PR #1922〜#1930、2026-07-28）で実運用した構成を一般化したもの。

## 役割モデル

| 役割 | 任務 | 実体の一例 |
| --- | --- | --- |
| 司令塔 | 全体プランの保持・タスク分配・採否判断・マージ判断。自分ではコードを書かない | Claude Code (Opus / Fable) |
| 参謀 | レビュー結果の妥当性評価・検算、実装指示書の立案、実測データ分析。実装とハーネス実行はしない | Claude Code (Fable) |
| レビュー（準司令塔） | 独立コードレビュー、PR に付く AI レビュー指摘の回収と対処統括。大量指摘はファイル非競合グループに束ねてサブエージェント並列修正 | codex 高推論モデル |
| ハーネス | E2E ハーネス・重い検証の実行と証跡報告だけ。コードは修正しない。コストがかかるため司令塔の指示なしに起動しない | codex 実行系モデル |
| 実行役 ×N | 指示された scope のコード修正とテスト。scope 外は編集しない。担当分を 1 コミット | codex 高推論モデル |

原則:

- 役割はすべて pane label にする（`司令塔` `参謀` `レビュー` `ハーネス` `実行役1` `実行役2`）。`herdr pane rename` と `herdr tab rename`（`司令室` / `実行室`）で誰が何をしているか一目でわかる状態を保つ。
- 実装役とレビュー役を同一 agent に兼務させない。レビューの独立性が判断材料になる。
- 全 pane を同じ worktree で動かし、触ってはいけない checkout（本体リポジトリ等）を role packet に明記する。worktree を新設する場合は `herdr worktree create` で作り、既存 worktree の再利用は `herdr worktree list` で確認してから `herdr worktree open` を使う。
- 並列実行役はファイル集合が重ならないように scope を切る。task packet に「他 pane の担当ファイルには触らない」と担当領域を両方書く。

## 標準レイアウト: 2x2 グリッドと既定モデル割当

チーム編成を指示されたら、ユーザーが別のレイアウトを指定しない限り **1 tab の 2x2 グリッド** を既定としてデザインする。司令塔は自分（このスキルを実行している pane）で、左上に置く。

```text
┌──────────┬──────────┐
│ 司令塔    │ レビュー   │
│ (自分)    │           │
├──────────┼──────────┤
│ ハーネス  │ 実行役1    │
└──────────┴──────────┘
```

既定のモデル割当（起動前に利用可能なモデルを確認し、capacity 落ちや廃止があれば近い性格のモデルへ差し替える）:

| pane | 役割 | 起動コマンド |
| --- | --- | --- |
| 左上 | 司令塔 | 自分（Claude Code。Opus / Fable 級を推奨） |
| 右上 | レビュー | `codex -m gpt-5.6-sol -c model_reasoning_effort=high` |
| 左下 | ハーネス | `codex -m gpt-5.3-codex-spark -c model_reasoning_effort=high` |
| 右下 | 実行役1 | `codex -m gpt-5.6-luna -c model_reasoning_effort=high` |

グリッドの構築手順。各 split の応答 JSON から新しい pane_id を読み、rename → `agent start` の順で埋める。

```zsh
# 自分の pane を起点に 2x2 を作る（応答の result.pane.pane_id を変数に取る）
herdr pane split --current --direction right --ratio 0.5 --no-focus          # → 右上
herdr pane split --pane "$HERDR_PANE_ID" --direction down --ratio 0.5 --no-focus  # → 左下
herdr pane split --pane <右上pane> --direction down --ratio 0.5 --no-focus   # → 右下

herdr pane rename <右上pane> "レビュー"
herdr agent start reviewer --kind codex --pane <右上pane> -- -m gpt-5.6-sol -c model_reasoning_effort=high
# ハーネス・実行役1 も同様に rename → agent start
```

規模が大きくなったら拡張構成に移行する:

- **参謀を足す場合**: 参謀（Claude Code / Fable 級）を司令室グリッドに入れ、ハーネスか実行役を別 tab へ追い出す。司令室 = 司令塔・参謀・レビュー・ハーネスの 2x2、実行室 = 実行役×N が実績のある形。
- **実行役を増やす場合**: `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd /abs/worktree --label "実行役2"` で tab を切り、応答 JSON の pane_id（tab create は `result.root_pane.pane_id`。フィールド名は応答を確認）へ `agent start` する。

```zsh
# 散らばった pane を部屋にまとめる
herdr pane move <pane_id> --tab <tab_id> --split right --target-pane <pane_id> --ratio 0.5 --no-focus
herdr tab rename <tab_id> "司令室"
herdr tab rename <tab_id2> "実行室"
```

## Role packet（初回に 1 回だけ送る）

役割・境界・報告形式を先に固定する。task はまだ送らない。

```text
Role: 実行役（コード修正の実行）

作業ディレクトリ: /abs/worktree/path
ブランチ: <branch>
重要: 本体の /abs/main/checkout は古いコミットです。そこでは絶対に作業しないでください。

あなたの担当:
- 司令塔が指示した scope のコード修正とテスト追加
- ローカルでの type-check / lint / unit test 実行
- 担当分のみを 1 コミットにまとめる（git add -A は禁止、対象ファイルを明示して add する）

やらないこと:
- 指示された scope 外のファイルを編集すること
- 明示指示のない push / PR 作成 / マージ
- ハーネス実行（別 pane の担当）
- 仕様の独自拡張。不明点や blocker は作業を広げず報告する

報告フォーマット: 変更ファイル(file:line) / 実行コマンド / 結果 / 残課題

いまは待機で構いません。この role を理解したことだけ一行で返答してください。
```

レビュー役には「レビューと指摘対処の統括」、ハーネス役には「実行と証跡報告だけ。低レイヤ検査を full cycle の代替にしない」「報告に session ID・到達状況・件数・PASS/FAIL を必ず含める」を担当として書く。

## Task packet（作業単位ごとに送る）

暗黙の会話文脈に依存しない自己完結の指示。`Task:` 見出し、背景、scope、制約、deliverable を含める。

```zsh
herdr agent prompt "$pane_id" 'Task: <一行の目的>（Phase 2 / 本丸）

背景: <なぜやるか。関連 PR / Issue / 直前の判定>
Scope: <対象ファイル・対象領域。読み取りのみ等の制限>
制約: <禁止事項。並列 pane の担当領域には触らない等>
Deliverable: <報告に含める項目>' --wait --timeout 1800000
```

- レビュー依頼は「読み取り専用、ファイル編集禁止」を必ず明記する。
- 判断を変える新事実が出たら「【追加情報: 前の指示を一部訂正します】」を冒頭に付けて追送する。
- レビューの質を上げたいときは、同じレビュー役に「あなたの結論への反証を試みてください」と devil's advocate タスクを追送する。実際に参謀の見落とし（質問跨ぎの re-arm）をこの往復で検出できた。

## 待機と回収

- 単一 agent の完了待ちは `herdr agent prompt --wait` か `herdr agent wait`。
- 複数 agent や CI・ビルド・成果物ファイルなど herdr の外の状態は、background の polling script（Monitor / `run_in_background`）で待つ。foreground の sleep ループはブロックされるため使わない。状態変化した時だけ 1 行出力し、終了条件で `ALL_SETTLED` のような番兵を出して exit する。

```zsh
# 複数 pane の settle 待ち（background で実行する）
until [ "$(herdr agent get "$impl_pane" | sed -n 's/.*"agent_status":"\([a-z]*\)".*/\1/p')" != "working" ] \
   && [ "$(herdr agent get "$reviewer_pane" | sed -n 's/.*"agent_status":"\([a-z]*\)".*/\1/p')" != "working" ]; do
  sleep 15
done; echo "ALL_SETTLED"
```

回収は `herdr pane read "$pane_id" --source recent-unwrapped --lines 60` で報告本文を読み、司令塔が差分・検証結果を確認してから採用する。

## ペイン間メッセージプロトコル

ユーザー本人も直接話しかける pane（特に参謀）とやり取りする場合は、発信者がわかる prefix を必須にする。

```zsh
herdr agent prompt <参謀pane> '[司令塔→参謀] PR #1930 のレビュー結果を検算してください。...'
herdr agent prompt <司令塔pane> '[参謀→司令塔] 検算完了。判定: GO（無条件）。独立検証: bun test 514 pass / 0 fail を自分で実行して確認。'
```

- 報告は「判定（GO / 条件付きGO / NO-GO）+ 根拠 + 自分で実行した検証コマンドと結果 + やっていないこと（実装・harness 実行なし等）」の形に揃える。判定定義は `$review-go-nogo`。NO-GO は再現可能な P0/P1 の実害のみ。条件付きGO は follow-up 付き GO。
- 参謀・レビューの結論が割れたら、司令塔が両論を突き合わせて裁定する。裁定結果と訂正は該当 pane に返して認識を揃える。

## ハードリミットと打ち切り

開始前に司令塔が予算を宣言し、引き継ぎパケットにも書く。

- 修正 PR 最大 N 本、ハーネス（重い検証）最大 N 回
- 新規に見つかった別問題は Issue 化して打ち切り、現タスクの scope に足さない
- 同じ失敗が続くときはループを止めて参謀に方針再判定を振る

## 司令塔の引き継ぎ（handoff packet）

セッション交代・新しい司令塔 pane の起動時は、新 pane に以下を 1 メッセージで渡す。

1. チーム表: pane ID / 役割 / 実体（model）を表で
2. herdr の実測注意点（このスキル本体の要点）
3. プロジェクト状況と「正本ノート」（Obsidian 等）の絶対パス。プランの正本は必ず外部ノートに保存しておき、pane の会話履歴を正とはしない
4. 守るべきルール（リポジトリの保護ルール、CI を再トリガーする操作はまとめてから一度で通す、等）
5. ハードリミットと次のアクション
6. 完了確認の合図（例: 把握できたら「司令塔引き継ぎ完了」とだけ出力）

## 実測の落とし穴（SKILL.md 本体の注意点に加えて）

- モデルが時間帯により "at capacity" で落ちていたら、代替モデルで起動し直すか、参謀・司令塔が役割を一時的に肩代わりして進行を止めない。
- role packet → task packet の順を崩さない。task から送ると境界（scope 外編集・push 禁止など）が固定されないまま作業が始まる。
