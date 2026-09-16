# 実行と共有

## ローカルの新規案件

Node.js 22.13以降の `node:sqlite` が必要。現在のNodeで利用可能か確認する。外部npm依存なし。

```sh
python3 /path/to/workflow-review/scripts/init_project.py /absolute/new-review
cd /absolute/new-review
node --test
node local/server.mjs
```

URLは `http://127.0.0.1:4173/`。別ポートなら `PORT=4175 node local/server.mjs`。既存listenerを停止せず、空いたポートを選ぶ。

| 生成先のpath | 役割 |
| --- | --- |
| public/flow-data.json | projectId、フロー、対応工程、根拠、revisionの編集元 |
| public/index.html・styles.css・app.js | フロー画面・グリッド・コメントUI |
| public/element-feedback/ | 既存HTMLへ組み込む要素選択moduleとdemo |
| shared/api.mjs | ローカル/Worker共通の入力検証・コメント処理 |
| local/server.mjs・sqlite.mjs | loopback serverとSQLite adapter |
| .data/comments.sqlite | ローカルの永続コメント。配布/commitしない |
| migrations/ | DB schema。既存DBには追記migrationで適用 |
| worker.mjs・wrangler.example.jsonc | 共有DB用のCloudflare実装例 |

`.data`を消すとコメントを失う。フロー修正はデータファイルを編集し、同じprojectIdと対象IDで更新する。新しい案件だけprojectIdを変える。starterは案件にコピーして編集し、skillのassetsを案件専用に書き換えない。

要素demoは生成後 `/element-feedback/demo.html` へアクセス。既存HTMLにはmoduleをコピーし、demoと同じ初期化を行う。server側には同じprojectIdを設定し、共通APIを同一originでmountする。フローデータを使わない既存アプリでも、APIが参照するmanifestにprojectIdと空のflowsを渡せる。

starterの静的配信は明示したpathだけを許可している。任意のHTML・画像を `public/` に置くだけでは配信されない。既存アプリのserverへ組み込むか、コピーしたstarterのlocal/server.mjsとworker.mjs両方へ必要な公開pathだけを追加する。DBやserverソースを配信対象へ広げない。

## 共有DBの具体例

Cloudflare Worker + D1を同梱する。localとsharedで `shared/api.mjs` とSQLを共有するが、ローカルSQLiteが自動同期されるわけではない。他のホストを使うなら同じ契約をそのDB adapterで実装し、別途検証する。

設定例は `assets.html_handling: "none"` で明示的な `.html` URLを保ち、Worker側で `/` を `/index.html` へ対応させる。この組合せを保つ。Cloudflare既定の拡張子除去とルート制限を混ぜると、`/element-feedback/demo.html` の転送先が404になる。[公式HTML handling](https://developers.cloudflare.com/workers/static-assets/routing/advanced/html-handling/)を参照。

公開依頼前は、既存のWranglerが使える場合にローカル検証まで進められる。設定例を生成案件でコピーして、ローカル用のdatabase_name/idを設定する。実行するCLIのhelpでオプションを確認する。

```sh
cp wrangler.example.jsonc wrangler.jsonc
# このファイル内のDB識別子をローカル用設定へ変更してから実行
wrangler d1 migrations apply LOCAL_DATABASE_NAME --local --config wrangler.jsonc
wrangler dev --local --config wrangler.jsonc
```

WranglerローカルDBはNode版の `.data/comments.sqlite` とは別。上のコマンドは公開・remote migrationを行わない。Wranglerがない場合はNode版の確認を進め、Cloudflare runtime未検証と明記する。導入のためだけに勝手に契約や認証変更をしない。

公開指示後は既存アカウント/宛先、DB binding、利用者の閲覧・投稿範囲を確認し、必要な認証を接続してからremote migration・deployを行う。`workers_dev:false` / `preview_urls:false` の例を無条件で公開へ切り替えない。非公開routeで共有するのか、URLを知る人全員の利用を認めるのかは案件ごとの設定。認証なし自己申告名のまま本人確認済みとは説明しない。

公開URLで別セッション投稿と再読込を検証して初めて共有環境確認済みとする。ローカル試験データをremoteへ自動投入しない。

一次情報: [D1 prepared statements](https://developers.cloudflare.com/d1/worker-api/prepared-statements/)、[Workers assets binding](https://developers.cloudflare.com/workers/static-assets/binding/)。採用時に現在の仕様と実環境を確認する。
