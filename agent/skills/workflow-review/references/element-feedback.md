# HTML要素へのフィードバック

## 標準の導入先

自分たちが管理するHTML/開発サイトへ `assets/element-feedback/` のmoduleを組み込む。既存サイトのレイアウト・色・操作を変更せず、フィードバックUIだけを独立して載せる。ブラウザ拡張や任意の第三者サイトへの注入は別の導入方式であり、標準ひな形の対応を装わない。

生成プロジェクトでは `/element-feedback/` に配置される。moduleのexportとdemoを確認して初期化し、projectId・明示的なrevision（例: PRのcommit SHA、設計版番号）・同一originのapiBaseを渡す。revisionはコメント作成時の版を識別する値であり、変更のたびにprojectIdを変えるものではない。

## 選択モード

通常モードではページ本来の操作を保つ。「要素を選択」で検査を開始し、pointer位置の要素の輪郭・タグを表示、clickで選択してコメントする。選択中のclickだけcapture段階で止め、リンク遷移やform送信を発火させない。Escapeで解除する。検査UI自体は対象に含めない。

マウスだけでなく、キーボードで対象を選び入力・送信する経路を設ける。touchではtapで選ぶ。iframeやshadow root内部に未対応なら明示し、親コンテナを選んだことを内部要素の選択と呼ばない。

## アンカーと履歴

保存するのはpagePath、selector、短いtextHint、revisionとstable target id。URLのquery/hash、フォームの入力値、password、ページHTML全体、スクリーンショットを自動収集しない。機微な部分は `data-feedback-private` 等の除外属性で対象外にできるようにする。

対象を再表示するときの優先順位:

1. 明示的な `data-feedback-id` が一意であれば優先する。アプリ開発者が改訂後も同じ意味の対象にだけ同じIDを使う。starterでは誤転付を避けるため、明示IDでもtextHintの一致を確認する。文言変更時は「要確認」となる。
2. 安定したHTML idを使う場合も一意性を確認する。
3. 構造selectorは一意一致とtextHint照合を両方満たす場合だけ候補にする。位置だけで一致させない。空のtextHint等、照合根拠が弱い場合は要確認とする。
4. 0件・複数件・根拠不一致なら「対象が見つかりません/要確認」。元のmetadataとコメントを保持し、別要素に自動転付しない。

同じ文字の反復要素や動的リストはCSS selectorだけでは区別しきれない。重要な対象には明示IDを付ける。全ページのHTML更新に完全追従できるとは説明しない。

同じ対象へ再投稿する際は登録済みtargetを再利用する。安定IDが同じで本文だけ変わった場合も、既存targetを「要確認」として開き、highlightは行わない。target登録成功後にコメント失敗しても、再試行で別targetを量産しない。新規登録にはproject・pagePath・selectorに基づく決定的IDを使い、同時登録も同じDBレコードへ収束させる。構造selectorではtextHintもIDに含める。消えた対象を一覧から選んで過去のコメントを読めるようにする。再紐づけ機能が必要なら元情報を保った明示操作として追加する。

## APIとの接続

targetType=`element` に共通コメント契約を適用。target登録には `POST /api/targets`、一覧には `GET /api/targets?projectId=...` を利用する。pagePathで絞って現在の画面の対象を判定し、違うページの同じselectorを同じ対象にしない。

既存アプリのAPIへ組み込む場合もprojectごとのアクセス制御を引き継ぐ。moduleを入れただけではDB・認証・公開範囲は設定されない。[コメント契約](comments.md)と[実行と共有](runtime.md)を参照する。
