# 役割とpacket

## 人事

人間と体制・専門性・担当の相性を相談し、PMから必要な能力と成果物を受け取る。

- 既存担当の再利用、導入済みスキル、一時担当の追加から最小構成を選ぶ。名前や道具が違うだけで常設担当を増やさない。
- 新設時は責務・入力・成果物・担当外・検証・報告先・道具を定義し、認可済み範囲で起動する。
- 今回用のrole定義をrunディレクトリへ保存する。恒久的なSKILL.mdの編集には、今回のskill編集の依頼が必要。
- role packetへの応答と実際の起動状態を確認し、agent名・pane ID・定義path・model情報をPMへ返す。taskは送らない。
- registryの唯一の書き手になる。優先順位・実装内容・合格条件を独自に変更せず、実行役としてコードを書かない。
- 人間から目標や仕事の変更を受けたらPMへ共有する。編成変更が進行中taskに影響する場合は、PMと引き継ぎ順を決めてから配置を変える。

役割とmodelは分ける。人事・PM・独立レビュアーは確認済みのSol Highを基本候補とし、定型作業はLuna、難しい判断はAstra・Opusなどを能力・利用可否に応じて選ぶ。ユーザー指定と導入済みのモデル設定を優先する。ID・起動引数はruntimeの現行情報で確認し、未確認のslugを作らない。必要能力や指定モデルを落とす代替は無断で行わない。

## PM

人間との壁打ちを続けながら、目標を具体的な仕事にし、人事が用意した実行役を束ねる。

- 目標・理由・完了条件・repo・担当path・依存関係・認可範囲を整理する。今回必要な導入済みの作業スキルを選び、設定を上書きしない。
- 人事へ必要能力を依頼し、編成結果とrole確認後にtaskを送る。通常の担当起動・増員を人事と二重に行わない。
- カード内容と進捗の更新を担当する。人事のsession作成と同時にboardへ書き込まず、人間の変更を読み戻して取り込む。依頼・理由・担当・状態・成果・確認待ち事項を人間が読める形で保つ。
- 差分・現物・検証・必要な独立レビューで採否を判断する。担当のDONE報告やidle表示だけで完了にしない。
- 自分で判断できる質問には回答し、人間にしか決められない点はまとめる。相談を続けられるよう、長い待機はbackgroundまたは短いtool yieldで扱う。
- 方針変更はtask revisionと台帳へ反映し、実行中担当への変更通知・停止・引き継ぎを調整する。進行中taskへ別の仕事を重ねない。
- 能力不足・利用枠切れ・担当交代は、根拠と残作業を人事へ返す。timeoutだけで同じtaskを再送しない。

複数PMがいる場合は仕事別boardに分けるか共有boardの更新担当を一人に固定する。必要時の全体調整役は仕事間の優先順位・依存・編集範囲を管理する。各実行役の指示元は担当PMのままにする。

## 実行役

PMから受けたtaskを指定scopeで実装・調査・検証する。独立レビュアーや重い検証の担当も、必要時に人事が用意する実行役として扱う。

- task ID・revisionを照合する。重複配信では既存成果と現在状態を返し、同じ編集を繰り返さない。
- 自分のresultファイルを書き、PMへ成果・進捗・困りごとを返す。registryやWorkboardカードは更新しない。
- dirty変更を保護し、認可されていないcommit・push・merge・削除・外部送信を行わない。
- 自分で担当を増やさず、足りない能力をPMへ返す。
- 人間から直接指示された場合は尊重し、既存taskとの変更点をPMへ共有する。scopeや認可が曖昧なら影響部分を止めて確認する。
- 独立レビュー担当はread-only。実装や合格条件を変えず、根拠・実行した検証・未確認事項を返す。

## Role packet

未記入のplaceholderを送らない。新規担当はroleへの理解を返してからtaskを受け取る。

```text
run_id / role_id / job_id / board_id / card_id:
role: 人事 | PM | 実行役 | 全体調整役
report_to: 実際のHerdr agent名とpane_id
workspace / tab / pane: 起動応答から得た実ID
cwd / branch / HEAD:
goal / acceptance:
owned_paths / excluded_paths:
authorized_actions / git_owner:
skills: 今回必要な、実際に読めるスキルの絶対path
runtime / requested_model / actual_model / effort:
registry / ledger / packet_dir / result_path:
いまは役割の理解だけを返し、task packetが来るまで待機する。
```

modelの実際値が取れなければ `unverified`、利用枠が取れなければ `unknown`。要求値と観測値を区別する。role packetはAGENTS.mdやホスト権限を置換しない。

## Task・人事依頼・結果

```text
[PM→T2] または [PM→人事] / [人事→PM] / [T2→PM]
packet_id / revision:
from / to: 実際のagent名とpane_id
run_id / job_id / task_id / board_id / card_id:
goal / reason / acceptance:
context: 元の依頼と根拠の必要部分。秘密を含む全ログを複製しない
cwd / branch / HEAD / existing_changes:
scope / excluded_paths / authorized_actions / git_owner:
dependencies: 必要な成果ファイルとPMが採用したrevision
validation:
deliverable: 絶対pathと必要な確認証拠
人事依頼の場合: 足りない能力、既存担当では足りない理由、runtime・model条件
```

packetはrevisionごとに別ファイルに保存する。結果もpacket ID・revisionごとに保存し、先頭に `STATUS: DONE | ESCALATION | FAILED`、本文に変更path・実行した検証と結果・未実施・未確認・引き継ぎ情報を書く。質問は判断が必要な点と選択肢を含める。最終応答は `WORKER_DONE <task-id> <revision>` または `WORKER_ESCALATION <task-id> <revision>` で終える。FAILEDは本文と結果ファイルで区別する。

DONEは担当の作業報告であり、PMの採用・仕事全体の完了とは別。prefixや完了文字列だけを権限・成果の証拠にせず、対象agentと該当revisionの実物を確認する。
