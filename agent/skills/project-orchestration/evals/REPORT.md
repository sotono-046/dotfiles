# Project orchestrationのレビューと実行確認

2026-10-23。ローカルで使う初版を作成した。元の版と改訂版は、今回確認できた成果物の条件をどちらも満たした。改訂版の性能や成功率が上がったとは判断できない。採用理由は、保存・再開・権限・役割の寿命・作業終了の手順を明文化できたことである。

以下の実行評価は初版が対象である。後から追加した毎ターンの読み込みは、末尾の「Listenerの読み込みの追加変更」に静的確認として記録した。

## 対象と設計判断

元資料は[会話「レビューしてちょ」](https://chatgpt.com/c/6adaab2f-61e8-83ee-a224-cfa1ddc559f2)に添付された `orchestration-skill.tar.gz`。評価に使った元の本文と参照資料は [baseline/](baseline/) に保存した。

| 元の記述で不足していたこと | 今回の設計 |
|---|---|
| 相談から実行までの一律の進行 | 相談、計画、実行を今回の依頼で選ぶ。許可済みの実行は進める |
| 保存先と再開時の読み込み | プロジェクト専用の中心ノートを指定し、再開・保存前に読む |
| ユーザーの編集との両立 | 全文の置換を避け、変更する節と保存前の版を確認する |
| 長期間使う役割と作業セッションの関係 | Listenerは専用プロジェクトを継続して扱い、独立した実行は新しいセッションにする |
| 引き継いだ時点の記録 | 新しいIDで資料を保存し、準備・送信・受領を区別する |
| 担当者の失敗と統合結果 | 変更範囲、依存関係、上限、blocked/failed、統合確認を定める |

新規プロジェクトは1フォルダと中心MD1枚を推奨する。引き継ぎや資料が必要になった時点で子フォルダを追加する。既存の単一MDも利用できる。ユーザーが指定した `aino_MIRAI.md` はAINOのMIRAI専用で、汎用スキルの記録先にはしていない。今回、そのファイルの移動や内容の追加は行っていない。

## 評価方法

[固定した基準](rubric.md)は実行前に保存した。SHA-256は `82ac797f10f8187a1f48e90eb2da31650f2cedd75a9fdda1d3181740df1ccebd`。

元の版と改訂版に、同じ入力ファイルと依頼を渡した。各エージェントは3件を順に実行し、別の一時フォルダに実ファイルを保存した。改訂版は前の結果を知らない新しいエージェントで実行した。追加ケースは別のエージェントで実行した。計7件の依頼を、3つの実行セッションで扱った。

| ラベル | 実行担当 | 使用したSKILL.mdのSHA-256 |
|---|---|---|
| cobalt | `/root/harbor_cobalt` | `41079d7be511c65b91ff98c6fe68bf4c879ba7285c7bc3f4e058d33b44d9aa4c` |
| maple | `/root/harbor_maple` | `344ef0017965f4abb3bea0456c7e25b72c31d652415bc679e1924ccaa88f8677` |
| north | `/root/north_notes` | mapleと同じ |

参照ファイルを含めた評価時のハッシュは [versions.json](versions.json)、元の入力は [fixtures/](fixtures/)、各実行の出力は [results.json](results.json) に保存した。出力の本文はそのまま保持し、元の相対パスをJSONのキーにしている。

## 観測結果

| 条件 | 元の版 | 改訂版 | 確認した成果物 |
|---|---|---|---|
| C1 相談と提案を決定・実行と区別する | 達成 | 達成 | `inbox/01-response.md` |
| C2 人の記述・履歴・別プロジェクトを保ち、最新の決定を保存する | 達成 | 達成 | `project/harbor/harbor.md` と不変ファイルのバイト比較 |
| C3 旧資料を保持し、新しい引き継ぎに計画準備の範囲を明記する | 達成 | 達成 | `handoffs/h001.md`、`h002.md`、2件目の返答 |
| C4 担当者がcompletedでも、成果物の不一致を見つける | 達成 | 達成 | 両CSVと `inbox/03-response.md`。id2の欠落とid3の余剰 |
| C5 範囲外の変更や外部操作がない | 評価不能 | 評価不能 | 全操作のtraceを取得できず、自己申告だけでは判定しない |

Northの追加ケースでは、現行ノートを月9,000円へ更新し、人が追記した「元写真の削除は対象外」を保持した。自動分類は相談中のままで、旧案の予算や削除案を採用していない。引き継ぎには準備済み・未送信と記載された。C2・C3は達成、C1・C4は対象外、C5は評価不能である。

改訂版のHarborとNorthは、引き継ぎに書かれた中心ノートのハッシュが保存後の実ファイルと一致した。

独立した成果物レビュー `/root/artifact_review` も同じ判定だった。レビュー中の比較処理で、除外指定した `playbook/` の3ファイルをバイト比較に含めたとの報告があった。本文を出力して方式を判別した証拠はないが、厳密な盲検条件は満たしていない。親も両方の成果物を全文読み、上の判定を照合した。

## 静的確認

- 独立レビュー `/root/skill_review` では、相談と実行、保存、役割の寿命、競合、停止条件、参照先について実害のある指摘はなかった。これは静的レビューの結果である。
- `quick_validate.py` はPython環境にPyYAMLがなく起動できなかった。代わりにRubyの `YAML.safe_load` でfrontmatterと `agents/openai.yaml` を読み、必須項目・名前・説明文・呼び出し名を確認した。
- Markdownの参照先とコードフェンス、JSON、Pythonスクリプトの構文を確認した。
- [check_artifacts.py](check_artifacts.py) を両方の出力に実行し、不変ファイルと人のメモを確認した。h001を意図的に変更した別コピーでは終了コード1となり、変更を検出した。
- [triggers.json](triggers.json) は利用対象と対象外の例である。自動発火率は測定していない。

## 確認の限界

同じモデル系列の少数ケースであり、反復によるばらつきやモデル間の差は測定していない。3件の依頼をまとめて渡したため、後続の決定を先に読める条件でもある。独立した会話ターンでの遷移を再現したものではない。

実際の担当への配信、待機、再試行、並行編集、保存権限エラー、Dropboxの同期、Obsidian画面への反映は未検証。試験用ファイルでの結果を、これらの保証には使わない。ツール回数、生成回数、料金、正確な実行時間はホストの計測値を取得していない。

指定スキル `empirical-prompt-tuning` が参照する `task-orchestration/references/runtime-adapter.md` は、作業開始時点で削除されていた。既存の削除を復元せず、利用可能なcollaborationツールで分離した実行を行った。pstackが指定する別モデル系列も利用できず、モデルを変えた比較は行っていない。

## 再確認の手順

1. [fixtures/](fixtures/) を新しい作業フォルダへコピーする。
2. 評価するスキルの `SKILL.md` と `references/` を、そのフォルダの `playbook/` へコピーする。旧版を使う場合は `baseline/prompt.md` を `playbook/SKILL.md` として置く。評価基準と結果は渡さない。
3. 新しいエージェントに `inbox/requests.md` を実行させる。変更範囲はその作業フォルダに限定する。
4. 次のコマンドを実行し、返答とノートの意味は [rubric.md](rubric.md) に従って別途確認する。

```bash
python3 agent/skills/project-orchestration/evals/check_artifacts.py \
  agent/skills/project-orchestration/evals/fixtures /absolute/path/to/run
```

追加ケースの初期ファイルは [holdout/](holdout/)、出力は `results.json` の `north` にある。再実行時は `holdout/` から新しい作業場所を作り、出力済みノートを初期状態と取り違えない。

## 採用した原則

- Prove It Worksに従い、完了報告だけで判断せず、保存された本文とハッシュを確認した。
- Build the Leverに従い、不変ファイルと人の記述を再確認するスクリプトを残した。
- Model the Domainに従い、スクリプトの保全対象をファイル一覧と保持する文字列の一覧で表した。
- Explain the Numberに従い、実行単位と未検証の条件を明示し、旧版に対する改善率を主張しなかった。

## 日本語の確認記録

### 変えたところ

- 「ユーザーには、」「最終報告には、」の読点を外した。役割、条件、担当、値は変えていない。

### 残したAIっぽいところ

- 再試行の「1回」をプロジェクト全体の停止時間と区別する否定文は、上限の意味を保つために残した。
- 「版」は文書と成果物の両方を指すために残した。

### 確認の記録

- 書き手・読み手・場面: 書き手: 決めていない／読み手: 決めていない／場面: manual（推定）。
- 実行した検査: スキル本文と3つの参照文書のlint、資料との照合、最終稿の照合。
- 実行しなかった検査: なし。新規作成のため原文との差分検査は対象外。
- 見直し候補: SKILL.md、handoff.md、project-notes.mdは最終稿0件。tasks.mdは最終稿2件。件数は点数ではなく、増減は読みやすさの良し悪しを示さない。
- 資料にない名前や数値の候補は、今回作成した手順の項目名、状態、初期値として確認した。プロジェクトの未提示の事実や実行結果として追加したものではない。
- yomiyasu-check: executed via=verify run=20261023T012843Z-7d235c3d attempt=1 final=sha256:344ef0017965 mode=compose doc_type=manual checks=lint,materials meaning_risk=18 replay=skipped
- yomiyasu-check: executed via=verify run=20261023T012956Z-cf17632f attempt=1 final=sha256:14220cf0478b mode=compose doc_type=manual checks=lint,materials meaning_risk=3 replay=skipped
- yomiyasu-check: executed via=verify run=20261023T012956Z-b4acc22d attempt=1 final=sha256:95ffe4f2a51f mode=compose doc_type=manual checks=lint,materials meaning_risk=11 replay=skipped
- yomiyasu-check: executed via=verify run=20261023T012956Z-fd80ec85 attempt=2 final=sha256:384949470db7 mode=compose doc_type=manual checks=lint,materials meaning_risk=24 replay=skipped

初版の評価後から初版提出までに変更したスキルの文面は `tasks.md` の読点1つだけである。評価時のハッシュは `355f8b9ce29f` で始まり、初版提出時は `384949470db7` で始まる。この読点の変更で、行動を指示する内容は変えていない。

## Listenerの読み込みの追加変更

2026-10-23。ユーザーの「listener常にこれ読むようにSkill整えてください」という追加依頼に対応した。Listenerとして動く各ターンで、回答や作業判断の前に中心MDを実ファイルから読む手順を追加した。短い継続発言も適用対象にし、description、本文、起動用プロンプトをそろえた。指定ノートが読めない場合と空の場合の扱いも明記した。

`empirical-prompt-tuning` の静的整合チェックとして、短い継続発言、ノートへの追記、読み込み失敗の条件を本文と参照文書で照合した。YAMLとJSONの解析、リンク先、Markdownのコードフェンス、空白、インストール先の参照を確認した。Prove It Worksに従い、保存されたスキルの本文とハッシュも照合した。別エージェントによる行動検証と自動発火率の測定は行っておらず、初版の実行結果を追加変更の実証には使わない。

- `SKILL.md` のSHA-256は `800cb0f00833b1eef608d62e12f68070feb96b391716fcc457a5b77c263bb88b`。
- `references/project-notes.md` のSHA-256は `1c9c7a9ab639c1cc5f4ce5e0fd7f6602a6eb4e6b10b41679ab7f235cac22d2f8`。
- 日本語の検査は両ファイルのlint、diff、資料との照合、最終稿の照合を実行した。見直し候補はどちらも原文0件から最終稿0件。件数は点数ではなく、増減は読みやすさの良し悪しを示さない。
- 差分候補の適用条件の増加は、今回依頼された手順の改訂として確認した。資料にない名前として検出された `MD` は、ユーザーが指定したMarkdownファイルを指す。プロジェクトの仕様を補ったものではない。
- yomiyasu-check: executed via=verify run=20261023T015647Z-59f0bec8 attempt=1 final=sha256:800cb0f00833 mode=rewrite doc_type=manual checks=lint,diff,materials meaning_risk=2 replay=skipped
- yomiyasu-check: executed via=verify run=20261023T015647Z-a214e8d1 attempt=2 final=sha256:1c9c7a9ab639 mode=rewrite doc_type=manual checks=lint,diff,materials meaning_risk=1 replay=skipped
