---
name: ci-merge-watch
description: PR URL/番号やGitHub Checks文脈があるとき、CI監視、失敗ログ調査、修正、レビューコメント回収を扱う。`CI見て` は監視のみ、ready化/mergeは明示指示のみ。`PR監視`, `checks直して`, `マージまで` などで使用する。
---

# ci-merge-watch

PR を「作ったところ」で止めず、CI とレビューが落ち着くまで面倒を見る。

## トリガー

- ユーザーが PR の CI 監視、失敗修正、マージを依頼した
- PR URL/番号、head branch、または GitHub Checks が文脈上特定できる
- `CI green`, `checks`, `readyにして`, `mergeして` と PR 文脈で言われた
- 既に PR があり、落ちている check の調査から始める必要がある

ローカルの test / type-check / lint を通すだけなら `green-loop` を主役にする。

## 基本方針

1. PR とローカル checkout の対応を確認する
2. `gh pr checks` / `gh pr view --json` で現在の check 状態を見る
3. 失敗 check はログを取得し、原因を分類する
4. 修正依頼がある場合は、ローカルで再現できる最小コマンドを見つけて修正する
5. `green-loop` を併用し、関連テスト・型・lint を通す
6. PR 更新依頼がある場合は commit / push して CI を再監視する
7. CodeRabbit などの actionable review があれば回収する
8. 明示指示がある場合のみ、全 check とレビュー状態を確認して ready 化または merge する

## 状態変更ゲート

- `CI見て` / `監視して`: check 状態と失敗原因を報告し、修正・commit・push・ready化・merge はしない
- `直して` / `通して`: 対象範囲の修正まで進める。commit / push は文脈上明らか、または明示指示がある場合のみ行う
- `PR更新して` / `pushして`: commit / push まで進める
- `readyにして`: checks とレビュー回収後に ready 化する
- `mergeして`: merge 条件を満たしたうえで merge する

## 併用する Skill

- CI failure の原因修正は `green-loop` を併用する
- commit / push / PR 操作は `git-ops` のルールを優先する
- GitHub review thread の詳細回収は GitHub 系 review comment workflow を優先する

## 監視コマンド

```bash
gh pr view <PR> --json number,title,state,isDraft,mergeStateStatus,reviewDecision,headRefName,baseRefName,statusCheckRollup
gh pr checks <PR> --watch
gh run view <RUN_ID> --log-failed
```

JSON は stdin pipe で壊れやすい環境がある。長めの処理では一度変数や一時ファイルに入れてから parse する。

CI ログや PR コメントを引用するときは最小抜粋にし、token、URL query、env、PII は redaction する。

## 失敗分類

- **test failure**: 対象 test をローカルで再現して修正
- **type/lint failure**: `green-loop` に寄せて修正
- **setup/dependency failure**: lockfile、node_modules、env、CI cache、package manager を先に疑う
- **flaky/external failure**: rerun の可否と根拠を確認
- **review requested changes**: unresolved / actionable comment を取り込み、非対応なら理由を書く

## Review 回収

- unresolved thread と requested changes を確認する
- actionable は修正または理由付きで非対応にする
- bot comment は重複、nit、任意提案を分ける
- review 回収後は、何を対応し何を残したか PR コメントまたは最終報告に残す

## Ready / Merge

- CI 監視だけの依頼では ready 化も merge もしない
- ready 化はユーザーが明示した場合のみ行う
- ready 化を依頼されている draft PR は、全 check green とレビュー回収後に ready 化する
- merge はユーザーが明示した場合のみ行う
- merge 前に base branch、merge method、delete branch の希望を確認済みか見る
- 指示がなければ squash merge を既定候補にするが、repo の慣習があれば優先する

## 終了条件

- 全必須 check が success
- actionable review comment が残っていない
- 依頼範囲に応じて PR が監視完了、ready 化済み、または merge 済み
- できなかった場合は、失敗 check、原因、次に必要な操作を短く残す
