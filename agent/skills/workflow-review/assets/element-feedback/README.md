# HTML要素へのコメント

所有するHTML・開発サイトに埋め込む独立モジュールです。既存UIはそのままで、オーバーレイとコメントパネルのみShadow DOMで追加します。ブラウザ拡張や任意サイト注入ではありません。

```html
<script type="module">
  import {initElementFeedback} from '/element-feedback/element-feedback.js';
  const feedback = initElementFeedback({
    projectId: 'your-project', revision: 'commit-or-release-id',
    apiBase: '/api', enabled: true
  });
  // 必要時: feedback.destroy(); 初期読み込み待ち: await feedback.ready;
</script>
```

`demo.html`は`../flow-data.json`からprojectIdとrevisionを読み取ります。単独配信では事前に`window.elementFeedbackConfig = {projectId, revision}`を設定し、同じAPIサーバーから配信してください。直接file://で開くものではありません。親starterへこのディレクトリをそのままコピーできます。`enabled`は既定でfalseです。認証やアクセス制御は配信サーバーで行います。

- 対象には`data-feedback-id="pricing-card"`のような不変でページ内一意のIDを推奨します。次に一意なHTML id、最後に構造selectorを使用します。
- 対象記録は`id, pagePath, selector, textHint, revision`。pagePathはpathnameのみです。スクリーンショットは取得しません。
- フォーム、入力、contenteditable、`data-feedback-private`、`data-sensitive`領域のテキスト・入力値は収集しません。それ以外の表示テキストが160文字まで記録されるため、機密領域には`data-feedback-private`を付けてください。
- 再選択では登録済み対象が実DOM要素へ一意に解決した場合に同じtargetを利用します。安定IDが同じで本文だけ変わった場合は既存targetを「要確認」として開き、highlightしません。構造selectorでは候補位置と同じタグの一意なtextHintが両方一致する必要があり、DOM並び替えや同じ文言の複数要素を黙って付け替えません。
- 新規target IDはprojectId・pagePath・selector（構造selectorではtextHintも）からSHA256で生成します。同じ対象を複数端末が登録しても同じIDとなり、serverは既存metadataを返します。revisionはID生成に含めません。
- 見失った対象・曖昧な対象も一覧からコメントを読めます。空のtextHintしか持たない構造selectorは再読込後「要確認」になるため、安定IDを使用してください。既存selectorを再利用して別の対象に差し替えた場合、完全に同じIDと同じ文章までは区別できません。
- 選択中はクリックやフォーム動作を捕捉します。Escで解除します。Tabでfocusable要素を選べるほか、選択ボタン上の↑↓で非focusable要素を含め巡回しEnterで確定できます。タッチ/ペンではpointerupで選び、直後の合成clickを抑止します。
- iframe内部、Shadow DOM内部、別ページDOM、Canvas内部の図形は対象外です。同一ページに先行登録されたwindow capture listenerの実行を取り消すことはできません。アプリ固有の操作がある場合は初期化順を含め実画面で検証してください。
- 名前はproject単位でlocalStorageへ記憶し、「名前を消去」で記憶も解除します。コメントはテキストとして描画し、Cmd/Ctrl+EnterはIME変換中に送信しません。Doneには理由が必要で、削除操作はありません。保存エラー時は入力を保持します。通常モードでの外側クリックはパネルを閉じ、元ページの操作はそのまま通します。

## API

全リクエストは同一origin、JSONです。GETのprojectId等はURLSearchParamsで渡します。

- `GET targets?projectId=...` → `{targets: [...]}`
- `POST targets` `{projectId,id,pagePath,selector,textHint,revision}` → `{target: {...}}`
- `GET comments?projectId=...&targetType=element&targetId=...` → `{comments: [...]}`
- `POST comments` `{projectId,targetType:'element',targetId,author,body}` → `{comment: {...}}`
- `POST comments/:id/done` `{projectId,reason}` → `{comment: {...}}`

コメントには`id,author,body,doneAt,doneReason`を使用します。exportされる`describeElement`、`locateTarget`、`safeText`はDOM環境で個別検証できます。
