# 必須スキルの自動読み込み

`agent/AGENTS.md` の「必須スキル」に列挙した `SKILL.md` の全文をモデルへ渡します。本文を要約せず、改行も保持します。任意のプロジェクトの `AGENTS.md` は読み込み対象の追加に使いません。

## 読み込むタイミング

| 対象 | 全文を渡すタイミング |
| --- | --- |
| Codex / Claude Code | 開始、再開、リセット、コンパクト後、fork、サブエージェント開始、各ユーザー依頼の開始 |
| Codex / Claude Code | ツール実行前にスキル本文や作業ディレクトリが変わった場合。全文を渡してその操作を一度拒否し、再試行を待つ |
| Codex / Claude Code | 直接の `git commit`、`git push`、`gh pr create`、`gh pr merge` を検出し、その依頼で必須スキルと `git-ops` の現在の全文をまだ渡していない場合。全文を渡して一度拒否する |
| Pi | `context` イベントで各モデル呼び出しの直前。自動圧縮後の再試行や会話の切り替えも含む |

開始時と依頼時は、既読状態にかかわらず全文を渡します。ツール実行前の重複抑制だけに、クライアント、会話、エージェント、作業ディレクトリ、分割番号ごとのハッシュを使います。親が読んだことを子の既読状態に流用しません。

Git 操作用の記録は、全文を渡したことを示します。拒否後に `Read` や `cat` でスキルを読んでも記録を消さず、同じ依頼内ではコマンドや引数を変えても再拒否しません。許可後も記録を保持するため、別の hook やコマンド自体が失敗した場合も再試行できます。スキルの参照先や本文が変わった場合と、新しい依頼や開始系イベントでは再び全文を渡します。読込エラーによる拒否は継続します。`references/` の読了を判定する処理はありません。

Pi はこの拡張自身が追加した過去の文書だけを取り除き、最新の全文を一つ追加します。直前のモデル入力後に本文が変わると、ツールを拒否して次のモデル呼び出しで読み込み直します。Pi の操作別 `git-ops` 追加は行いません。

## 導入と確認

```bash
./install.sh --hooks-only --dry-run
./install.sh --hooks-only
python3 -m unittest discover -s tests -p 'test_required_skills.py'
node tests/test_required_skills_pi.mjs
```

`--hooks-only` は依存パッケージ、dotfiles、スキル配置を変更しません。既存の `--skills-only` の動作も変えません。次のファイルへ、このスクリプトを指す hook だけを追加・更新します。

- `~/.codex/hooks.json`
- `~/.claude/settings.json`
- `~/.pi/agent/extensions/required-skills.ts` の symlink

JSON の他の設定と hook の位置を保持し、変更前の JSON を `~/.local/state/dotfiles/backups/` へ保存します。設定ファイルや設定ディレクトリが symlink の場合、または同名の無関係な Pi extension がある場合は停止します。削除時も他の hook の位置を変えないため、空の hook グループが残る場合があります。

```bash
# 一時ホームで確認する場合
DOTFILES_TARGET_HOME=/tmp/required-skills-home ./install.sh --hooks-only --dry-run

# この hook だけを取り除く場合
python3 agent/hooks/required-skills.py install --home "$HOME" --remove --dry-run
python3 agent/hooks/required-skills.py install --home "$HOME" --remove
```

Codex の hook 信頼設定は自動承認しません。追加したコマンドを確認して信頼を設定してください。反映には新しい Codex / Claude Code セッション、Pi では `/reload` または再起動が必要です。

## 全文と出力上限

`yomiyasu` などコロンを含まない名前は、各クライアントのユーザースキル配置、`~/.agents/skills`、このリポジトリの `agent/skills` の順で解決します。`CODEX_HOME`、`CLAUDE_CONFIG_DIR`、`PI_CODING_AGENT_DIR` がある場合は、その配置を使います。見つかったファイルが空・読取不可の場合や symlink の参照先がない場合は、後の候補へ置き換えず、エラーにします。

`pstack:poteto-mode` は公式 `pstack@cursor-plugins` の `skills/poteto-mode/SKILL.md` を参照します。この参照だけをプラグイン参照として扱います。別の名前空間やスキル名はエラーになり、ユーザースキルやリポジトリ内の同名スキルへ置き換えません。

- Claude Code は `CLAUDE_CONFIG_DIR` または `~/.claude` の `settings.json` で `enabledPlugins["pstack@cursor-plugins"]` が `true` であることを確認します。`plugins/installed_plugins.json` は version 2 が必要です。user scope の登録が1件のとき、その絶対パスの `installPath` を使います。旧版がキャッシュに残っていても、登録先を読み込みます。
- Codex は `CODEX_HOME` または `~/.codex` の `config.toml` で `plugins["pstack@cursor-plugins"].enabled` が `true` であることを確認します。TOML の読込には標準の `tomllib` を使うため、Python 3.11 以降が必要です。`plugins/cache/cursor-plugins/pstack` 直下の実ディレクトリのうち、名前が ASCII 英数字と `-`、`_`、`.`、`+` だけからなり、`.` と `..` ではないものが対象です。symlink と通常のファイルは除きます。対象が1件のときだけ読み込み、0件または複数件なら停止します。
- Pi はこのプラグイン参照に限り Codex の設定とキャッシュを使います。`CODEX_HOME` が優先され、`PI_CODING_AGENT_DIR` はこの参照には使いません。Claude Code への切り替えも行いません。Pi で使う場合も Codex 側で公式プラグインを有効にしてください。

両クライアントとも、選んだインストール先が公式の `plugins/cache/cursor-plugins/pstack` の範囲内にあることと、`.claude-plugin/plugin.json` の `name` が `pstack` であることを確認します。設定や登録情報の欠落・不正、無効化、範囲外への参照は読込エラーになります。設定、登録情報、本文は毎回読み直します。参照先や本文の更新は既存のハッシュ比較で検出します。

Codex 本体は複数の版から選べますが、この hook は版の比較を実装していません。更新中の一時的な重複と、正常な更新後でも旧版の削除に失敗して残る状態は、この hook では未対応です。複数件のエラーが出た場合は公式インストールを確認・修復してください。hook がキャッシュを削除したり、旧版へ切り替えたりすることはありません。

Codex は `additionalContextLimit: 0` で全文を渡します。スクリプト側では見出しやパスを含めて 128,000 UTF-16 units を上限とします。Claude Code は異なる16個のコマンドへ分割し、各出力を見出し込みで8,000 UTF-16 units 以下にします。長い一行や絵文字も途中の文字を失わず分割します。分割数を超えた場合は、一部分だけを成功として返しません。

全文を繰り返し渡すため、入力トークン数と文脈の使用量は増えます。各分割には文書全体のハッシュと番号が付いています。Claude の16個の処理は個別にファイルを読むため、処理の途中でスキルを編集すると異なる版が混ざる可能性があります。その場合は編集後に依頼を送り直してください。

読込失敗はユーザー依頼とツール実行を止めます。Claude Code の開始系イベントは停止できないため、エラーを表示し、次の依頼・ツール実行で停止します。Claude の `onFailure: "block"` は対応する版が必要です。Pi は読込失敗時に実行を中止し、ツールも拒否します。

検出対象の Git / GitHub コマンドは一般的な直接呼び出しです。任意のシェルプログラムや別名をすべて解析する制御ではありません。全文が入力に含まれることと、モデルが指示を守ることは別です。
