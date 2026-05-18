---
name: runtime-config-source-of-truth-audit
description: env、dotenvx、build arg、CI/CD substitution、Docker image、Cloud Run等のruntime設定を突き合わせ、実際に効いている値とSSOTを特定する。`envの実値`, `どこで設定`, `GCPに見えない`, `復号して`, `runtime設定確認` で使用する。
---

# runtime-config-source-of-truth-audit

設定の説明で止めず、実際に効いている値と、その値の source of truth を突き止める。

## トリガー

- `envで明示？`, `復号して実値見て`, `どこで指定？`
- Cloud console に見えない設定の説明を求められた
- live 環境と local の値が食い違っている
- build-time env と runtime env の区別が必要

## 確認レイヤー

1. コード上の参照箇所
2. `.env` / dotenvx / secret manager などの local effective value
3. CI/CD 設定、substitution、build arg
4. Dockerfile / image bake-in
5. runtime service env
6. deployed revision / image digest / build metadata
7. live endpoint / logs

## 進め方

1. 変数名、設定名、対象環境を確定する
2. コード検索で参照箇所と fallback を見る
3. local env は復号または実行時展開で実値を見る
4. CI/CD と deploy 設定を確認する
5. runtime env にない場合は build-time bake-in を疑う
6. live revision がどの build / commit / image を使うか確認する
7. 表で `layer`, `value`, `source`, `confidence` をまとめる

## Secret 表示ルール

- API key、token、private key、password、cookie、署名付きURLは全文表示しない
- 原則は `set` / `empty` / `missing`、prefix/suffix 数文字、hash、length で比較する
- ユーザーが全文表示を求めても、chat、shell output、最終回答には secret 全文を出さない
- 必要なら手元で確認し、redacted proof、hash、length、source だけを伝える
- shell output や最終回答に secret が残りそうな場合は、必ず redaction して伝える

## 回答フォーマット

```markdown
| layer | value | source | confidence | note |
| --- | --- | --- | --- | --- |
```

最後に「実際に効いている可能性が最も高い値」と「SSOT」を分けて書く。

## 注意

- `.env` の値だけで cloud runtime の実値とみなさない
- Cloud Run 等の service env に出ない値でも build arg で image に焼き込まれている場合がある
- ライブラリ/API仕様は Context7、OpenAI API は `openai-docs`、その他は公式 docs や live API で確認する
