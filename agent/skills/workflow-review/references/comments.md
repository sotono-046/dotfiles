# コメントの共通契約

## 保存

対象はprojectId + targetType(flow/step/gap/element) + targetId。本文、投稿者、server生成日時、Done状態、Done理由・日時を保存する。ブラウザのlocalStorageはproject単位の名前記憶だけに使う。自己申告名はログイン認証を意味しない。

初回の投稿で名前を必須にし、次回から補完する。変更/クリア手段を用意する。本文は文字列として描画し、HTMLとして挿入しない。失敗時は入力を保ち、保存成功と表示しない。送信中は多重投稿を防ぐ。

API・DBは入力の型、長さ、対象存在、project一致を検証する。SQL bindを使い、日時はserverで確定する。同一originを基本とし、共有のためだけにワイルドカードCORSを追加しない。

starter API: `GET /api/comments?projectId=...&targetType=...&targetId=...` → `{comments:[]}`、`POST /api/comments` に `{projectId,targetType,targetId,author,body}` → `{comment:{...}}`。Doneは `POST /api/comments/:id/done` に `{projectId,reason}`。DB/応答側のフィールドは `doneReason` と `doneAt`。旧対象は `GET /api/comments/history?projectId=...` でも取得できる。

## 開閉と入力

カード全体hover/focus-withinでコメントボタンを見つけられるようにする。touchでは常時、既存コメントがある対象には件数を表示する。

popoverは同時に1つ。再タップ、外側、×、Escapeで閉じ、別対象のボタンでは切り替える。パネルを操作しているときに背後のカードへclickが抜けないようにする。Escape/×で呼び出し元へfocusを戻す。非同期応答が遅れても別対象の欄を上書きしない。

Cmd+Enter、Windows等はCtrl+Enterで送信。通常Enterは改行。IME変換中は送らない。画面端・scroll・resizeでパネルが画面外に出ないようにする。

## Done

削除操作の代わりにチェックボタンを置く。クリックでラベル「理由」、placeholder「理由を書いてください」、右上「×」、送信「OK」のフォームを出す。空白だけならOKを無効化し、serverでも拒否する。

Done後も本文・投稿者・理由・日時を閲覧できる。レコードは削除しない。競合するDoneは原子的に未完了から更新し、二度目の理由で元の理由を上書きしない。存在しないIDを成功扱いしない。再開機能は標準外で、必要になったときに履歴イベントとして設計する。

## 共有

複数利用者は同じserver DBを読む。端末ごとのSQLiteやlocalStorageは共有DBにならない。公開前に、利用者と閲覧・投稿可能な範囲を決める。機密性が必要なら既存認証やアクセス制御を接続する。noindexやURLを知っていることはアクセス制御ではない。

本番コメントを試験用にDone化したり削除したりしない。検証専用project/DBを使う。ローカル検証データを公開DBへ移すかどうかは公開工程で区別する。
