---
name: ci-merge-watch
description: PR/CI/review/merge文脈で、PR URL/番号、head branch、GitHub Checks、または現在ブランチからPRを特定し、CI監視、失敗ログ調査、修正、レビューコメント回収とResolveを扱う。`CI見て` は監視のみ、既定はCI greenかつmerge可能で停止、ready化/mergeは明示指示のみ。`PR監視`, `checks直して`, `レビュー指摘対応`, `マージまで` などで使用する。
---

# ci-merge-watch

PR を「作ったところ」で止めず、CI とレビューが落ち着くまで面倒を見る。

## トリガー

- ユーザーが PR の CI 監視、失敗修正、マージを依頼した
- PR/CI/review/merge 依頼で、PR URL/番号、head branch、GitHub Checks、または現在ブランチから PR を一意に特定できる
- `CI green`, `checks`, `readyにして`, `mergeして` と PR 文脈で言われた
- PR のレビュー指摘、unresolved thread、changes requested の対応を依頼された
- 既に PR があり、落ちている check の調査から始める必要がある

ローカルの test / type-check / lint を通すだけの依頼なら、このスキルではなく通常フローで全通まで修正・再実行を繰り返す。

## 基本方針

1. PR とローカル checkout の対応を確認する（PR 番号未指定時は後述の「PR 特定」に従う）
2. **CI 監視はサブエージェントに委譲する**（後述の「サブエージェント委譲」）。司令塔は委譲・結果統合・状態変更ゲート判断に専念し、`gh pr checks --watch` の長時間 polling や `gh run view --log-failed` の大量ログを自分のコンテキストで抱えない
3. 失敗 check はサブエージェントが原因を分類し、最小再現コマンドと該当ログの最小抜粋を報告する
4. 修正依頼がある場合は、関連テスト・型・lint が全通するまで修正と再実行を繰り返す。複数 check の独立修正は `task-orchestration` の原則で並列サブエージェント化する
5. PR 更新依頼がある場合は commit / push し、再度監視サブエージェントを起動する
6. 修正依頼または ready / merge 文脈で actionable review があれば回収し、対応後に修正済み thread を Resolve する
7. merge 明示指示がなければ、全 check とレビュー状態を確認し、merge 可能になった段階で停止して報告する
8. `マージまで` / `mergeして` などの明示指示がある場合のみ、全 check とレビュー状態を確認して merge する

## PR 特定

PR URL/番号が指定されていない場合は、文脈から PR を一意に解決して監視対象にする。**ユーザーに番号を聞き返す前に、以下の自動検知を必ず試す**。優先順位は、明示された head branch、GitHub Checks から一意に特定できる PR、現在の checkout（ブランチ or ワークツリー path）に紐づく PR の順。

1. 明示された head branch がある場合は、`gh pr list --head <HEAD_BRANCH> --state all --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,baseRefName,isDraft` で候補を確認する。
2. GitHub Checks の URL、run、commit SHA などから PR 候補を得た場合も候補配列として扱い、候補数が 1 件で、`gh pr view <PR> --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,baseRefName,isDraft` による詳細確認を通った場合だけ監視対象にする。
3. ここまでで特定できない場合は、**現在の作業 path / worktree からブランチを推定する**:
   - `git rev-parse --show-toplevel` で worktree のルートを取得する（dotfiles など複数 worktree を運用するリポジトリで、呼び出し元 cwd と PR head が食い違う事故を防ぐ）
   - `git -C <toplevel> branch --show-current` で current branch を確認する。空なら detached HEAD とみなし、`git -C <toplevel> rev-parse HEAD` の SHA から `gh pr list --search "<SHA>" --state all --json ...` で候補を探す。それでも特定できなければ停止する
4. current branch が取れる場合は、`gh pr list --head <CURRENT_BRANCH> --state all --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,baseRefName,isDraft` で候補配列を確認する。open PR が 1 件あればそれを優先。open が無く closed/merged のみなら停止条件（手順 9）に従う。
5. 候補を 1 件に絞れたら、必要に応じて `gh pr view <PR> --json number,url,state,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,baseRefName,isDraft` で詳細を確認する。`gh pr view` 引数なしの暗黙解決だけで複数候補チェックを省略しない。
6. `gh pr list --head` は branch 名だけの一致なので、候補の `headRepositoryOwner` / `headRepository` / `isCrossRepository` / `headRefOid` と、local upstream / remote / commit が食い違う場合は一意扱いせず停止する。
7. 候補が 1 件かつ local checkout と PR head の対応が説明できる場合だけ監視対象にする。複数候補、detached HEAD で SHA 検索も外れた、PR 未作成などで一意に決まらない場合は、自動検知で試したコマンドと結果を短く示したうえで PR 番号/URL/head branch の指定をユーザーに求めて停止する。ローカル未コミット差分を PR の代替として監視しない。
8. PR を解決した後、状態変更へ進むたびに後述の「Mutation preflight」を実行する。最初に取得した `headRefOid`、check SHA、local status を後続操作へ使い回さない。
9. PR が closed / merged の場合は原則停止する。続行する場合も CI/log/history の read-only 確認に限定し、修正・Resolve・ready・merge には進まない。

## 状態変更ゲート

- `CI見て` / `現状見て`: check 状態と失敗原因を報告し、修正・commit・push・ready化・merge はしない
- `PR監視` / `CI通るまで` / `checks通るまで`: check 完了まで監視し、merge 可能状態まで確認して止める。修正・commit・push・ready化・merge は別指示がある場合のみ行う
- `直して` / `通して`: 対象範囲の修正まで進める。commit / push は文脈上明らか、または明示指示がある場合のみ行う。merge はしない
- `レビュー指摘対応` / `指摘直して`: actionable review comment を修正し、必要な commit / push 後、対応済み thread だけ Resolve する。merge はしない
- `PR更新して` / `pushして`: commit / push まで進め、CI 再監視後に merge 可能状態まで確認して止める。merge はしない
- `readyにして`: checks とレビュー回収後に ready 化する。merge はしない
- `マージまで` / `mergeまで` / `mergeして` / `マージまでしておいて`: merge 条件を満たしたうえで merge する

### Mutation preflight

push、CI rerun、review reply / Resolve、ready 化、merge、branch deletion など、GitHub または remote の状態を変える各操作の**直前**に次を fresh に再取得する。1 回の preflight で複数 mutation をまとめて許可しない。

- local の `git status --short --branch`、current branch、HEAD、upstream
- PR の current `headRefOid`、head branch、state、draft 状態
- 判断根拠に使う check / run の head SHA、status、conclusion。run id がある場合は `gh run view <RUN_ID> --json headSha,status,conclusion` 等で SHA を再固定する

Resolve / ready / merge など push 以外の mutation は、local worktree が clean、local HEAD と PR `headRefOid` が一致し、利用する check SHA も同じ `headRefOid` を指す場合だけ進める。required check が存在しない場合は「none」と記録し、古い SHA の green を代用しない。PR head の変化、dirty / diverged、pending または取得不能な check evidence があれば停止して再監視する。

push では local HEAD が current PR head より先行してよいが、worktree が clean、branch / upstream が対象 PR と一致し、remote の current `headRefOid` が記録した push 前 SHA から変わっていないことを必須にする。push 後は新しい `headRefOid` を再固定し、それ以前の check 結果を無効として再監視する。

## 併用する Skill

- commit / push / PR 操作は `git-ops` のルールを優先する
- GitHub review thread の詳細回収は GitHub 系 review comment workflow を優先する
- 複数 check の独立修正を並列化する場合は `task-orchestration` の原則に従う

## サブエージェント委譲

CI 監視・ログ取得・レビュー回収はサブエージェントへ委譲する。司令塔が `gh pr checks --watch` の long-polling や大量ログを抱えない。tool の起動・追送・待機は `$task-orchestration` の runtime adapter を使い、Claude Code の API を Codex で generic tool として扱わない。

### 役割分担

- **司令塔（このスキル発動エージェント）**: PR 特定、状態変更ゲート判定、サブエージェント起動、結果統合、ユーザー報告、commit/push/Resolve/ready/merge などの状態変更操作
- **監視サブエージェント**: `gh pr checks <PR> --watch` 等で CI 完了まで待機し、最終 check 状態（success/failure/pending）と失敗 check 一覧を JSON 形式で返す。ログ本体は持ち帰らず、必要な失敗 check name と run id のみ
- **ログ調査サブエージェント**: 特定の失敗 check について `gh run view <RUN_ID> --log-failed` を実行し、原因の最小抜粋（5〜30 行程度）、失敗分類、ローカル再現コマンド候補を返す。token / URL query / env / PII は redaction
- **レビュー回収サブエージェント**: unresolved thread と actionable comment を列挙し、thread URL / latest comment / 該当 file:line / 対応要否の判断材料を構造化して返す

### 起動方針

- 各サブエージェントには「監視対象 PR 番号」「リポジトリ」「read-only 制約」「報告フォーマット」「最大待機時間」「停止条件」を明示して渡す
- 並列化条件: 失敗 check が複数あり、ログ調査が独立しているなら、ログ調査サブエージェントをファイル非競合グループで並列起動してよい
- 監視サブエージェントは 1 PR につき 1 つに絞る。`--watch` の重複起動は避ける
- サブエージェントは状態変更（commit / push / Resolve / ready / merge）を行わない。司令塔だけが行う
- サブエージェントの報告は 1 ターンあたり 500 トークン以下を目安にし、生ログの貼り付けは禁止

### Codex adapter

- `collaboration.spawn_agent` で監視・ログ調査・レビュー回収 agent を起動する。
- 実行中 agent へ停止条件や追加 run id を追送する場合は `collaboration.send_message` を使う。
- idle / turn 完了済み agent に追加調査を依頼する場合は `collaboration.followup_task` を使う。
- 状態は `collaboration.list_agents`、mailbox update は `collaboration.wait_agent` で待つ。timeout だけを失敗と扱わない。
- Codex の呼び出しに `run_in_background`、`TaskOutput`、`subagent_type` を渡さない。

### Claude Code adapter

- 公開 schema の `Task` または `Agent` で agent を起動する。
- schema が対応している場合だけ `run_in_background` と `TaskOutput` を使う。
- `Explore` / `general-purpose` などの `subagent_type` は実在と権限を確認してから使う。
- Claude Code 固有の tool / model 名を Codex adapter へコピーしない。

修正 agent を別途起動する場合、共有 worktree / index / HEAD では編集だけを非競合 path へ並列化し、stage / commit は owner GO 後に1グループずつ直列化する。対象 path の明示 staging と `git diff --cached --name-only` 確認を必須にする。

### 監視コマンド（サブエージェントが使う）

```bash
gh pr view <PR> --json number,title,state,isDraft,mergeStateStatus,reviewDecision,headRefName,baseRefName,statusCheckRollup
gh pr checks <PR> --watch
gh run view <RUN_ID> --log-failed
```

JSON は stdin pipe で壊れやすい環境がある。長めの処理では一度変数や一時ファイルに入れてから parse する。

CI ログや PR コメントを引用するときは最小抜粋にし、token、URL query、env、PII は redaction する。

## 失敗分類

- **test failure**: 対象 test をローカルで再現して修正
- **type/lint failure**: ローカルで型チェック・lint を再現し、全通まで修正する
- **setup/dependency failure**: lockfile、node_modules、env、CI cache、package manager を先に疑う
- **flaky/external failure**: rerun の可否と根拠を確認
- **review requested changes**: unresolved / actionable comment を取り込み、非対応なら理由を書く

## Review 回収

- unresolved thread と requested changes を確認する
- actionable は修正または理由付きで非対応にする
- PR で指摘があった場合は、修正、必要な commit / push、関連 test / CI 確認まで進め、対応した thread だけ Resolve する
- Resolve 前に thread URL、latest comment、対応 commit、必要なら test / CI 証跡を対応づける
- 判断不能、設計判断待ち、未修正、外部依存待ち、理由付き非対応の thread は Resolve しない
- bot comment は重複、nit、任意提案を分ける
- review 回収後は、何を対応し何を残したか PR コメントまたは最終報告に残す

## Ready / Merge

- CI 監視だけの依頼では ready 化も merge もしない
- 既定では、全必須 check が success、actionable review comment が残っていない、merge conflict がなく merge 可能、という状態まで確認して停止する
- ready 化はユーザーが明示した場合のみ行う
- ready 化を依頼されている draft PR は、全 check green とレビュー回収後に ready 化する
- merge はユーザーが `マージまで` / `mergeまで` / `mergeして` / `マージまでしておいて` などで明示した場合のみ行う
- merge 前に base branch、merge method、delete branch の希望を確認済みか見る
- 指示がなければ squash merge を既定候補にするが、repo の慣習があれば優先する

## 終了条件

- 全必須 check が success
- actionable review comment が残っていない
- 対応済み review thread が Resolve 済み
- merge conflict がなく、merge 可能状態まで確認済み
- merge 明示指示がない場合は、merge せずそこで停止して報告済み
- merge 明示指示がある場合は、merge 済み
- できなかった場合は、失敗 check、原因、次に必要な操作を短く残す
