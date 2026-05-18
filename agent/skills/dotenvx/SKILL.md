---
name: dotenvx
description: dotenvx で .env を暗号化・複数環境管理・key ローテーション・GitHub Actions 連携するときに使用。run/encrypt/decrypt コマンド、DOTENV_PRIVATE_KEY 運用、rotate 手順。Git worktree（子）で作業するときは必要に応じて .env.keys を取り寄せてデバッグする手順も参照。
---

# dotenvx Skill

dotenvx は .env ファイルの読み込み・暗号化を行う環境変数管理ツール。言語・フレームワーク非依存。

## インストール

```bash
# curl（推奨）
curl -sfS https://dotenvx.sh | sh

# brew
brew install dotenvx/brew/dotenvx

# npm
npm install @dotenvx/dotenvx --save
```

## 基本コマンド

```bash
# 環境変数を読み込んでコマンド実行
dotenvx run -- node index.js

# 特定の .env ファイルを指定
dotenvx run -f .env.production -- npm start

# 複数ファイル読み込み（後が優先）
dotenvx run -f .env -f .env.local -- npm start

# 環境変数を取得
dotenvx get DATABASE_URL

# 全環境変数を表示
dotenvx get
```

## 暗号化

```bash
# .env を暗号化（DOTENV_PUBLIC_KEY, DOTENV_PRIVATE_KEY 生成）
dotenvx encrypt

# 特定ファイルを暗号化
dotenvx encrypt -f .env.production

# 復号化
dotenvx decrypt

# 暗号化されたファイルを実行（DOTENV_PRIVATE_KEY が必要）
dotenvx run -- node index.js
```

### 暗号化の仕組み

- `dotenvx encrypt` 実行で公開鍵/秘密鍵ペアを生成
- `DOTENV_PUBLIC_KEY`: .env ファイル内に保存（暗号化用）
- `DOTENV_PRIVATE_KEY`: ローカル環境または CI に設定（復号化用）
- 環境別: `DOTENV_PRIVATE_KEY_PRODUCTION` で自動判定

## オプション

| オプション       | 説明                 |
| ---------------- | -------------------- |
| `-f, --env-file` | .env ファイル指定    |
| `--overload`     | 後続ファイルで上書き |
| `--quiet`        | 出力抑制             |
| `--verbose`      | 詳細表示             |
| `--debug`        | デバッグ情報表示     |

## 複数環境の管理

```
.env                 # 共通設定
.env.local           # ローカル上書き（gitignore）
.env.production      # 本番環境
.env.development     # 開発環境
```

```bash
# 本番環境で実行
dotenvx run -f .env.production -- npm start

# 開発 + ローカル上書き
dotenvx run -f .env.development -f .env.local -- npm run dev
```

## Worktree での作業（.env.keys の取り寄せとデバッグ）

**Git worktree** で**子**の作業コピーだけを切ったとき、**親**側にはあるが子には無いファイルとして **`.env.keys`** が典型例になる（`.gitignore` されており clone / worktree add では入ってこない、など）。

暗号化済み `.env` を **`dotenvx run`** で読ませたり、IDE から **復号できる環境変数つきでデバッグ**したいときは、**必要なタイミングだけ**秘密鍵を手元に用意する。

### 方針

- **常にコピーする必要はない**。API を叩かない作業、軽いコード修正、型確認、lint など復号不要な作業なら `.env.keys` なしで進める。
- デバッグや `dotenvx get` で復号が要るときだけ、**キー（`.env.keys` または `DOTENV_*_PRIVATE_KEY`）を取ってくる**。
- Worktree で `.env.keys` が必要になった場合でも、**自動でコピーしない**。まず `.env.keys` なしで進められない具体的な理由（失敗しているコマンド、復号が必要な検証内容など）を確認し、その理由、コピー元とコピー先の絶対パス、実行予定コマンド、コミットしない確認をユーザーに提示して、**明示的な許可を得てから**コピーする。
- ユーザーが許可していない段階では、`.env.keys` の中身を表示したり、ログへ出したり、別ファイルへ退避したりしない。必要なら存在確認・パス確認・ファイル権限確認までに留める。

### `.env.keys` を持ってくる例

1. **親のワークツリーからコピー**（同一マシンで親が既にセットアップ済みのとき）  
   `git worktree list` の**先頭行**が親のパス。親のリポジトリルートにある `.env.keys` を、**子のリポジトリルート**にコピーする。実行前に、次の形でユーザー確認を挟む。

   ```text
   worktree で復号が必要です。以下のコピーを実行してよいですか？
   why:  <失敗しているコマンドや、復号が必要な検証内容>
   from: /path/to/parent/repo/.env.keys
   to:   /path/to/child/worktree/.env.keys
   command: cp /path/to/parent/repo/.env.keys /path/to/child/worktree/.env.keys && chmod 600 /path/to/child/worktree/.env.keys
   note: .env.keys の中身は表示せず、git add しません。
   ```

   許可後にだけ実行する。

   ```bash
   # 例: 親パスを確認してから（パスは環境に合わせる）
   git worktree list
   cp /path/to/parent/repo/.env.keys /path/to/child/worktree/.env.keys
   chmod 600 /path/to/child/worktree/.env.keys
   ```

2. **1Password / 社内の秘密管理 / 別端末**など、チームの定めた経路で平文のキーや `.env.keys` を受け取る（worktree に限らない通常運用と同じ）。

3. **シェルに直接渡す**（ファイルを置かない選択）  
   親の環境で `export` 済みなら同じ値を子のターミナルにコピーする、あるいは `DOTENV_PRIVATE_KEY` / `DOTENV_PRIVATE_KEY_<環境>` だけを安全な手段で貼る。

### デバッグまでの流れ

```bash
# .env.keys を置いたうえで（または DOTENV_PRIVATE_KEY を export したうえで）
dotenvx run -- npm run dev
# または
dotenvx run -- node --inspect-brk dist/main.js
```

IDE（VS Code / Cursor 等）の「起動構成」では、**親と同じ環境変数**（`DOTENV_PRIVATE_KEY` など）を **`.env.keys` を読み込むラッパー経由**にするか、`envFile` で**平文を置かない**よう、ドキュメント化された方法に従う。多くの場合はターミナルで `dotenvx run --` してからデバッガをアタッチする、または `dotenvx` が提供する run 連携を使う。

### 注意

- **`.env.keys` はコミットしない**（`.gitignore` を維持）。子にコピーしたファイルも誤って add しない。
- 共有マシンではパーミッション（`chmod 600` 等）を意識する。
- 子を `git worktree remove` するとき、**子側にだけ置いた `.env.keys` はディレクトリごと消える**。必要なら親に残る原本に影響はないが、都度コピーが要る点は踏まえておく。

## Key ローテーション

private key が漏洩疑いになったとき、または定期的な rotation 時の手順。`dotenvx rotate` 専用コマンドは執筆時点で存在しないため（最新は公式 docs を確認）、decrypt → 新 key で encrypt を明示的に行う。

**順序が最重要**: CI secret を **先に** 新 key に更新してから、新暗号文を merge する。逆だと旧 key で新暗号文を復号しようとして prod が落ちる。

```bash
# 1. 作業ブランチ + 旧 key 退避
git switch -c chore/rotate-prod-dotenv-key
set +o history
OLD_PRIV="$DOTENV_PRIVATE_KEY_PRODUCTION"

# 2. 旧 key で復号（平文に戻す）
DOTENV_PRIVATE_KEY_PRODUCTION="$OLD_PRIV" dotenvx decrypt -f .env.production

# 3. 既存 PUBLIC_KEY を削除してから再 encrypt（新 key ペアが生成される）
sed -i.bak '/^DOTENV_PUBLIC_KEY_PRODUCTION=/d' .env.production
dotenvx encrypt -f .env.production
NEW_PRIV=$(dotenvx get DOTENV_PRIVATE_KEY_PRODUCTION -f .env.keys)

# 4. CI secret を新 key に更新（merge より先）
gh secret set DOTENV_PRIVATE_KEY_PRODUCTION --body "$NEW_PRIV" --env production

# 5. 新暗号文を commit + merge + deploy
git add .env.production && git commit -m "chore: rotate production dotenv key"
git push && gh pr create --fill && gh pr merge --squash --auto

# 6. クリーンアップ
unset OLD_PRIV; set -o history
rm .env.production.bak
```

**漏洩時の追加対応**:

- git 履歴に残る旧暗号文は過去の旧 key で復号可能なまま。key ローテだけでは不十分
- 暗号化されていた値自体（DB password、API key 等）も **並行して再発行** 必須
- 履歴からの完全除去が必要なら `git filter-repo` を使うが、force push 影響が大きいので慎重に

**ダウンタイム回避**: 一時的に `DOTENV_PRIVATE_KEY_PRODUCTION` と `DOTENV_PRIVATE_KEY_PRODUCTION_NEW` を並行保持し、デプロイ成功後に旧を削除する blue-green 運用も可。

## GitHub Actions

curl でインストール。最小例は以下。

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Install dotenvx
    run: curl -sfS https://dotenvx.sh | sh

  - name: Run tests
    env:
      DOTENV_PRIVATE_KEY: ${{ secrets.DOTENV_PRIVATE_KEY }}
    run: dotenvx run -- npm test
```

## 参考

- https://github.com/dotenvx/dotenvx
- https://dotenvx.com/docs
