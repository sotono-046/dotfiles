# initagent

プロジェクトの `AGENTS.md` と `CLAUDE.md` を初期化・更新する。

このスキルの目的は、AI エージェントが安全かつ高品質に作業できるハーネスの入口を作ること。
`AGENTS.md` は巨大なマニュアルではなく、リポジトリ内の知識・制約・検証ループへ案内する地図として最小限に保つ。

## 言語方針

- `AGENTS.md` と `CLAUDE.md` は、原則として日本語で書く。
- ユーザーが読めないため、説明文・判断基準・注意事項・完了報告は日本語にする。
- コマンド、ファイルパス、パッケージ名、API 名、識別子、エラー文、コード中の文字列は英語のままでよい。
- 英語の公式用語を使う場合は、必要に応じて短い日本語説明を添える。
- 既存ドキュメントが英語の場合でも、`AGENTS.md` には日本語で要約して参照を書く。
- 英語でしか意味が安定しない技術用語は無理に翻訳しない。

## 参考文献の優先順位

ハーネスエンジニアリングや AGENTS.md / CLAUDE.md / Skills の考え方を確認する場合は、個人記事だけに依存しない。
次の順で信頼度を置く。

1. 公式ドキュメント
2. 標準仕様・プロジェクト公式サイト
3. 査読前を含む研究論文・技術レポート
4. 著名な実務者・技術組織の記事
5. 個人ブログ・メモ・解説記事

参考にしてよい主な資料:

- OpenAI Codex: Custom instructions with AGENTS.md
  - `AGENTS.md` の探索順、階層的な指示、プロジェクト指示の扱いを確認する。

- OpenAI Codex: Agent Skills
  - 繰り返し使う専門手順を skill に分離する考え方を確認する。

- AGENTS.md 公式サイト
  - AGENTS.md を「エージェント向け README」として扱う考え方を確認する。

- Martin Fowler: Harness engineering for coding agent users
  - ハーネスを、フィードフォワードとフィードバックでエージェントを支える外側の仕組みとして捉える。

- AI Harness Engineering: A Runtime Substrate for Foundation-Model Software Agents
  - task specification、context selection、tool access、verification、permissions、observability などの責務を確認する。

- Context Engineering for AI Agents in Open-Source Software
  - AGENTS.md のようなエージェント向け設定ファイルの実利用を確認する。

- ユーザーの記事
  - 背景理解や思想の確認には使ってよい。
  - ただし、唯一の根拠にはしない。

## 事前に読む

まず、次の情報を確認する。

- 既存の `AGENTS.md`
- 既存の `CLAUDE.md`
- `README.md`
- `docs/`
- `.github/workflows/` などの CI 定義
- package manager / build tool / test runner の設定
- lint / format / typecheck / test の設定
- project-specific skill / command / agent 定義
  - 例: `.agents/skills/`, `.claude/commands/`, `.claude/agents/`

外部仕様やエージェントツールの仕様が関係する場合は、必要に応じて公式ドキュメントを確認する。
古くなりやすい情報を記憶だけで断定しない。

## 基本方針

- `AGENTS.md` には、作業開始時に必要な地図だけを書く。
- `AGENTS.md` は原則日本語で書く。
- 詳細な知識、長い運用ルール、設計経緯、ドメイン知識は `AGENTS.md` に詰め込まない。
- プロジェクト固有の知識は、できるだけ `docs/` か project-specific skill に置く。
- 繰り返し使う手順は skill / command に分ける。
- 判断材料や設計経緯は `docs/` に残す。
- 機械的に守るべき制約は、文章だけでなく lint / test / CI / hooks に寄せる。
- `CLAUDE.md` には `@AGENTS.md` を必ず残す。
- Claude 専用差分が必要な場合だけ、`@AGENTS.md` の下に短く追記する。
- 不明な点は推測で埋めず、リポジトリ内の根拠を優先する。
- 根拠が見つからない重要事項は、`AGENTS.md` に断定せず「要確認」または人間への確認境界として扱う。
- 参考文献そのものを `AGENTS.md` に長く列挙しすぎない。必要な場合は `docs/` に逃がし、`AGENTS.md` から参照する。

## 作業手順

### 1. リポジトリ構造を把握する

次を確認する。

- 主要なアプリ、パッケージ、サービス
- 主要ディレクトリ
- `docs/` の有無と内容
- `scripts/` の有無と内容
- CI 定義
- test / lint / format / typecheck の実行方法
- 既存の skill / command / agent 定義
- 生成物、ビルド成果物、触ってはいけないファイル
- `.env`, secrets, credentials, private key などの機密ファイル
- 自動生成ファイルや外部同期ファイル

必要に応じて、以下のようなコマンドで確認する。

```bash
pwd
find . -maxdepth 3 -type f | sort | sed 's#^\./##' | head -200
find . -maxdepth 3 \( -name 'AGENTS.md' -o -name 'CLAUDE.md' -o -name 'README.md' -o -name 'package.json' -o -name 'pnpm-lock.yaml' -o -name 'bun.lockb' -o -name 'Makefile' -o -name 'docker-compose.yml' -o -name 'compose.yml' \) -print
find . -maxdepth 4 \( -path './.git' -o -path './node_modules' -o -path './dist' -o -path './build' \) -prune -o -type f \( -path './docs/*' -o -path './.github/workflows/*' -o -path './scripts/*' -o -path './.agents/*' -o -path './.claude/*' \) -print
```

### 2. ハーネスの置き場をマッピングする

確認した情報を、次の置き場に分類する。

| 置き場                   | 役割                         | 入れるもの                                                              | 入れないもの                           |
| ------------------------ | ---------------------------- | ----------------------------------------------------------------------- | -------------------------------------- |
| `AGENTS.md`              | エージェントが最初に読む地図 | 概要、主要ディレクトリ、読むべき docs、代表コマンド、禁止事項、確認境界 | 長い設計経緯、網羅的な仕様、細かい手順 |
| `docs/`                  | 長期記憶                     | 設計判断、運用ルール、ドメイン知識、技術的経緯、ADR                     | 毎回必ず読む短い入口                   |
| project-specific skill   | 再利用する専門手順           | 調査フロー、レビュー観点、定型作業、移行手順                            | 一度きりのメモ                         |
| command                  | 短い定型操作                 | 初期化、検証、レビュー、リリース補助                                    | 長文の背景説明                         |
| lint / test / CI / hooks | 機械的フィードバック         | 命名規則、依存方向、型、整形、テスト、ビルド、危険操作検知              | 人間の判断が必要な設計方針             |

### 3. `AGENTS.md` に入れる情報を分類する

`AGENTS.md` に入れる候補を、次の基準でふるい分ける。

#### 入れる

- プロジェクトの一文概要
- 主要ディレクトリの地図
- 作業前に読むべき docs / skill / command
- よく使う開発・検証コマンド
- 触ってはいけないファイルや機密情報
- 生成物の扱い
- 人間に確認すべき判断境界
- 変更後に実行すべき最小検証
- このリポジトリでは日本語で説明を書く、という言語方針

#### 入れない

- 詳細な設計経緯
- 長いドメイン知識
- コーディング規約の全文
- API 仕様の全文
- 長いトラブルシューティング
- 古くなりやすい議事録
- 特定タスクだけで使う手順
- CI や lint で機械的に検証できるルールの長文説明
- 外部文献の長い引用や要約

入れないものを見つけた場合は、次のいずれかに分離する候補として扱う。

- `docs/architecture.md`
- `docs/decisions/`
- `docs/operations.md`
- `docs/domain.md`
- `docs/testing.md`
- `docs/agent-harness.md`
- `.agents/skills/<skill-name>/SKILL.md`
- `.claude/commands/<command-name>.md`
- lint / test / CI / hooks

### 4. `AGENTS.md` を最小構成で作る

`AGENTS.md` は、原則として次の構成にする。

```markdown
# AGENTS.md

## プロジェクト概要

<!-- このリポジトリが何をするものかを1〜3文で書く -->

## 言語方針

- 説明、作業メモ、完了報告、レビューコメントは原則日本語で書く。
- コード、コマンド、ファイル名、識別子、API 名は英語のままでよい。
- 英語の外部資料を参照した場合は、必要に応じて日本語で要点を書く。

## リポジトリ地図

<!-- 主要ディレクトリと役割だけを書く -->

## 作業前に読むもの

<!-- 作業前に読むべき docs / skill / command へのリンクを書く -->

## よく使うコマンド

<!-- install / dev / test / lint / typecheck / build など、代表コマンドを書く -->

## 安全上の注意と境界

<!-- 機密、生成物、触ってはいけないもの、破壊的操作の注意を書く -->

## 人間に確認すること

<!-- 仕様判断、セキュリティ、課金、データ削除、外部API変更など、人間確認が必要な境界を書く -->

## 完了前チェック

<!-- 変更後に最低限確認することを書く -->
```

必要に応じてセクションを増やしてよいが、`AGENTS.md` は「地図」であることを優先する。
長くなりすぎる場合は、詳細を `docs/` や skill に分離し、`AGENTS.md` から参照する。

### 5. `CLAUDE.md` を初期化または更新する

`CLAUDE.md` には、必ず先頭に `@AGENTS.md` を残す。

新規作成または Claude 専用差分が不要な場合は、次でよい。

```bash
printf '@AGENTS.md\n' > CLAUDE.md
```

Claude 専用差分が必要な場合だけ、下に短く追記する。

```markdown
@AGENTS.md

## Claude 専用メモ

- <!-- Claude Code だけに必要な差分がある場合のみ書く -->
```

`CLAUDE.md` に `AGENTS.md` と同じ内容を重複して書かない。
Claude 専用メモも原則日本語で書く。

### 6. 必要なら docs / skill / command の分離候補を作る

`AGENTS.md` から外すべきだが重要な情報を見つけた場合は、可能なら適切な置き場を作る。

例:

```bash
mkdir -p docs/decisions
mkdir -p .agents/skills
mkdir -p .claude/commands
```

ハーネス設計の背景や参考文献を残したい場合は、`AGENTS.md` に長く書かず、次のような docs に分離する。

```bash
mkdir -p docs
touch docs/agent-harness.md
```

ただし、既存のプロジェクト方針と衝突しそうな場合は勝手に大きく作り替えず、候補として記録する。

### 7. 検証する

作成後、次を確認する。

- `AGENTS.md` が巨大なマニュアルになっていない。
- `AGENTS.md` が日本語中心で書かれている。
- `AGENTS.md` から必要な docs / skill / command に辿れる。
- 開発・検証コマンドが実在する。
- 存在しないコマンドを断定していない。
- 機密情報や秘密鍵の扱いが明記されている。
- 生成物や自動生成ファイルの扱いが明記されている。
- 人間に確認すべき判断境界が明記されている。
- `CLAUDE.md` の先頭に `@AGENTS.md` がある。
- Claude 専用差分が必要最小限になっている。
- 機械的に守るべき制約が、可能な限り lint / test / CI / hooks に寄せられている。
- 外部仕様に関する断定がある場合、公式ドキュメントなど信頼できる根拠がある。

### 8. 完了報告する

完了時は、日本語で簡潔に報告する。

- 作成・更新したファイル
- `AGENTS.md` に残した情報
- `docs/` や skill に分離した、または分離候補にした情報
- 見つかった検証コマンド
- 実行した検証
- 未確認事項や人間に確認が必要な点
- 参照した外部資料がある場合、その種類
  - 例: 公式ドキュメント、標準仕様、論文、実務記事

## 判断基準

### 良い `AGENTS.md`

- 日本語で読める。
- 初回作業時に迷わない。
- 主要な知識へのリンクがある。
- よく使う検証コマンドがある。
- 危険な操作や機密の境界が分かる。
- 人間確認が必要な判断が分かる。
- 詳細は `docs/` や skill に逃がしている。
- 変更に強く、古くなりにくい。

### 悪い `AGENTS.md`

- 英語ばかりでユーザーが読めない。
- 長大なマニュアルになっている。
- すべてのルールを文章で守らせようとしている。
- docs / skill / CI への導線がない。
- 実在しないコマンドを書いている。
- 古い設計判断を断定している。
- 機密や生成物の扱いが曖昧。
- Claude 専用ルールと共通ルールが重複している。
- 個人記事や記憶だけを根拠に外部仕様を断定している。

## 重要な原則

AGENTS.md は、エージェントに知識を全部渡す場所ではない。
エージェントが必要な知識、制約、検証ループへ到達するための入口である。

このリポジトリでは、その入口をユーザーが読める日本語で保つ。

ハーネスとして本当に強いのは、長い指示ではなく、次の組み合わせである。

- 小さな `AGENTS.md`
- 整理された `docs/`
- 必要なときだけ読む skill / command
- 機械的に失敗を返す lint / test / CI / hooks
- 人間に戻すべき判断境界
- 信頼できる外部文献に基づく更新
