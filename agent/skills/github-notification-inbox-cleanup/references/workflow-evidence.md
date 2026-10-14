# 記録と仕様の根拠

## Computer Historyで確認できたこと

指定された6時間要約から、通知整理を記録した10分要約と元イベントをたどった。

- 6時間要約: `/Users/sotono/.codex/memories/extensions/skysight/resources/2026-10-05T18-00-00-ieyx-6h-memory-summary.md`
- 10分要約: `/Users/sotono/.codex/memories/extensions/skysight/resources/2026-10-05T22-40-00-AlPw-10min-memory-summary.md`
- 元イベント: `/Users/sotono/Library/Group Containers/2DC432GLL2.com.openai.sky.CUAService/Library/Caches/ComputerUse/Skysight/segments/2026-10-05T22-40-00Z/events.jsonl`
- セグメント情報: 同じディレクトリの`metadata.json`。記録範囲は2026-10-05 22:40〜22:50 UTC。

元イベントの41行目、event ID `77537`、`2026-10-05T22:46:06Z`では、ChatGPTのアクセシビリティ差分に次の会話が表示された。日本時間では2026-10-06 07:46:06。77行目のevent ID `77599`と88行目の`77616`にも同じ会話がある。

1. ユーザー: 「Gmailのgithubうるせえからアーカイブできる？全部やって良い」
2. 応答: 個人・仕事用Gmailを確認し、受信トレイのGitHub通知をまとめてアーカイブする方針。
3. 完了報告: 個人Gmail23通、仕事用0通、両方の受信トレイのGitHubメールが残り0。

確認できたのは、依頼、対象範囲、画面に表示された完了報告である。このセグメントにはGmailの検索式、接続ID、API応答、選択・アーカイブ操作そのものの証拠はない。23通と残件0は当時の報告値として扱い、現在の件数やAPIで検証済みの値とは扱わない。

## 再利用する手順との区別

両アカウントの受信トレイを対象にすること、一括アーカイブ、アカウント別の件数と残件報告は記録に基づく。送信元による検索、全ページ取得、message/threadの区別、再検索による検証は、同じ作業を再実行するために定義した手順である。

作成時に実環境のGmail tool schemaで次を確認した。接続IDや上限は実行時に読み直す。

- `gmail_search_emails`と`gmail_search_email_ids`: `query`、`link_id`、`next_page_token`で検索・ページ取得。
- `gmail_batch_modify_email`: message IDを対象にラベルを追加・除去。
- `gmail_archive_emails`: thread IDを対象に、スレッド内の全メッセージから`INBOX`を除去。作成時は最大100スレッド。

## 公式資料

以下は2026-10-07に確認した。検索条件や操作を変更するときに必要な箇所を参照する。

- [Gmailの検索演算子](https://support.google.com/mail/answer/7190?hl=en): `from:`で送信元を絞れる。会話表示では、検索に一致したメッセージ以外も同じ会話に含まれる場合がある。
- [Gmailのアーカイブ](https://support.google.com/mail/answer/6576?hl=en): 受信トレイから除かれたメールは「すべてのメール」に残る。新しい返信で受信トレイに戻ることがある。
- [GitHub通知のメールヘッダー](https://docs.github.com/en/subscriptions-and-notifications/reference/email-notification-headers): 通知の識別にヘッダー情報を使える。
- [GitHubの通知メール送信元の説明](https://github.blog/news-insights/the-library/notification-email-improvements/): `notifications@github.com`の説明。古い記事のため、実行時のメールで送信元と通知の種類を確認する。
