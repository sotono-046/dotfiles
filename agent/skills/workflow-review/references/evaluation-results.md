# 評価記録

## 初版

2026-09-16。対象はこのスキルと同梱starter/element-feedback。業務フロー比較と管理下HTMLへの要素選択コメントの2モード。公開、クラウド作成、実データ変更は行っていない。

## 方法と上限

独立executorへ同じ架空貸出資料（受付3工程、返却確認2工程、フォーム受付/一覧記録は予定、責任者の確認は継続）を渡した。生成先は別々の一時ディレクトリ。評価者の結論を渡さず、スキルと入力資料から作成・実行させた。baselineは8分、修正版は5分。比較はbaselineと1回の改訂。親が生成物・実行結果・ブラウザを照合した。

事前critical: 独立した生成物、変更なしの保持/提案と事実の区別、IDとコメントの永続性、Done理由と非削除、要素選択/消失時の保持、公開しない境界、実際のグリッドとmobile可読性。失敗を見てcriticalを変更していない。

Fableは `claude-fable-5` の独立設計→Astraから反証→Fableから反証→完成物のコードレビューを実行。Fableのコードレビュー自体は実行検証ではない。指摘は親がコードと再現で判定し、修正後の検証は親と独立executorで行った。

## 観測と修正

| ケース | 観測 | 対応・再確認 |
| --- | --- | --- |
| 初回案件化 | 公開flow-dataを替えると固定サンプルIDのテスト4件が失敗 | test専用fixtureへ分離。新しいexecutorの別project/flow/step IDでも、テストコード変更なしで4件成功 |
| 要素demo初期化 | 初回コピーはprojectIdがサンプルと不一致 | manifestからprojectId/revision取得。修正版の別案件demoも起動 |
| 変更なしの工程 | 責任者確認がAfterに残り、アプリ2工程は予定、根拠A/Bあり | 両executorの生成JSONと画面を確認 |
| 要素の文言改訂 | stable selectorでもtext差で別targetを作る問題 | 同一stable selectorの既存議論を要確認として開く。親ブラウザで改訂後も元コメントを表示、targetは1件 |
| フロー間接続の消失 | 描画しないgapが履歴の除外集合に残る問題 | 描画済みtargetを元に履歴判定。最終テストへ回帰ケース追加 |
| 送信中の本文編集 | 成功時に追加入力を消す可能性 | 送信時の本文と一致するときだけ消去 |

Fableの「stable IDなら文言変更を自動再接続」は、誤転付を避けるためそのまま採用せず、議論の再利用とhighlight判定を分けた。SQLite/Postgresを環境変数だけで切り替える案も採用せず、SQLite/D1の共通APIと実際のadapterを用意した。

## 検証結果

- 最終starter: `node --test` 5/5成功。永続性、並替/削除後保持、project/target分離、入力/Origin拒否、Done空理由/再Done409/削除不可、element metadata、孤立gapの履歴判定を含む。
- スキル: frontmatter validator、Markdown相対参照、Python scaffolder、既存出力先の拒否、JS構文チェック成功。Codex/Claudeのスキル登録先を照合。
- 独立修正版trial: JSONと引渡し文書だけの案件用変更で、起動・同梱テスト4件・工程とフロー間の投稿・再読込・Done・Escape・390px表示を確認。後から追加した孤立gap回帰テストは親が確認。
- 親ブラウザ: flow Cmd+Enter投稿→Done→再読込保持、element選択時のリンク遷移抑止→投稿→Done、HTML対象削除後の本文/理由閲覧、文言改訂後の議論保持を確認。
- グリッド実測: desktop幅1220px、12列、ガター32px、対応カード幅562pxが左右同じ。mobile幅390pxで4列・document scrollWidth390px。白背景も確認。
- element ID関数: stable文言/revision変更で同ID、project違い/構造textHint違いで別IDをassert確認。

## 限界

ローカルでの評価であり、Cloudflare/D1公開環境、実機touch、SafariのIME、認証連携、全framework、同時操作の実ブラウザ網羅は未検証。未使用の第三の業務シナリオによるholdoutは行っていない。工数削減・全案件への一般化・費用効果は測定していない。実行中のtool数/利用量は一括測定していない。


## 追加の empirical-prompt-tuning レビュー（2026-09-16）

初版を固定コピーし、過去の評価結果を見せずに独立executorへ渡した。代表ケースは備品申請の2フロー（メール受付・上長承認・発注／受領・受取確認・台帳記録）、将来案はフォーム受付と台帳自動記録だけ。境界ケースは既存HTMLの申請ボタン・リンク・同じ文言のカード・private入力領域への要素コメント組込み。両ケース8分、最大2改訂と原因限定再確認、最大3子を事前の上限とした。

criticalは事実と提案の区別、変更なしAfterの保持、IDとコメントの永続性、既存HTMLの操作維持、保存・Done・対象変更時保持、別ブラウザタブ共有、ローカル限定、スキルからの再現性。結果を見て判定基準を変えていない。文書・実装契約は別のread-only reviewerが調べた。今回の独立評価は標準モデルで行い、Fableを再実行したとは扱わない。

| 観測した問題 | 修正 | 確認 |
| --- | --- | --- |
| private領域をクリックするとtargetを登録できる | 選択・metadata生成・旧target再解決・輪郭表示で除外 | 実moduleの独立harnessで登録1件から0件、旧targetも再接続しない |
| 要素モードで記憶した名前を消せない | 名前消去ボタンでproject用localStorageと入力を消去 | 独立harnessで両方を確認 |
| 通常モードの外側クリックでパネルが閉じない | パネルを閉じ、元ページのクリックは抑止しない | 独立harnessで閉鎖とイベント非抑止を確認 |
| Cloudflareローカルでdemo.htmlが拡張子なしへredirectされ404になる | assets.html_handlingをnoneにし、Workerでrootをindex.htmlへ明示対応 | 実Wranglerでroot・index.html・demo.html・moduleがredirectなし200 |

代表フローはstarterコード変更なしで案件化できた。投稿後にフロー表示順を逆転し、別タブから工程・フロー間の同じコメントを表示、Done理由と元本文を保持。Afterはアプリ予定2工程・人4工程を保った。390pxでdocument scrollWidthも390px。未実装を実装済みとして表示していない。

最終の生成プロジェクトで `node --test` は7/7成功。API・再起動永続性・対象分離・Done原子性・孤立gapに加え、private/名前消去/外側クリックの実module harnessとWorker配信の回帰テストを含む。DOM harnessは実ブラウザ試験と区別する。独立の契約再レビューは3指摘すべて解消、限定範囲でGO・残P2なし。

Wrangler 4.127.1のローカルD1へmigrationを適用し、投稿201、Done200、二重Done409、元のDone理由保持を実HTTPで確認。クラウドリソース作成・公開はしていない。初版の限界のうちCloudflareのローカルruntimeは追加検証したが、remote環境・実機touch・Safari IME・全framework・認証連携は引き続き未検証。時間削減効果や全案件での成功率は測定していない。


修正版の境界ケースは、baselineの結論を知らない新しいexecutorが同じ素材・8分上限で最初から組み込んだ。実ブラウザで通常ボタン操作維持、検査時のクリック抑止、投稿・Done・再読込・別タブ共有を確認。文言変更では要確認として元議論を表示、削除後も本文とDone理由を閲覧できた。private選択拒否、選択解除後のリンク動作、keyboard選択も成功し、再現欠陥はなかった。その固定snapshotでは6テスト成功、後から追加したUI回帰harnessを含む最終生成物は親が7/7を確認した。

判定は今回の実証範囲で **OK**。重大な再現欠陥と発見した契約不整合は解消。修正版の独立試行では重複カードの兄弟挿入、mobile/touch、IME、送信失敗時draftは未測定。baseline側の重複文言・兄弟挿入の成功を、修正版での再測定とは呼ばない。
