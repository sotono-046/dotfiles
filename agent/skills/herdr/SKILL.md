---
name: herdr
description: Herdrのworkspace・tab・pane・agentをCLIで操作する。別エージェントへの指示、タブでの分担、人事とPMによる担当編成、Workboardでのタスク可視化、進捗更新、成果回収、担当交代に使う。「Herdrでオーケストレーション」「人事とPMを置く」「タブでworkerを回す」「P-Aで」などの依頼を扱う。
---

# Herdr

Herdrの操作とチーム運用をこのスキルで扱う。人間は人事にもPMにも直接相談できる。人事が担当を用意し、PMが実行役を束ねて仕事を進める。タスクは原則herdr-workboardで可視化する。

## 短い起動指示

Piでは `/herdr [仕事の内容]`、Codexでは `$herdr start [仕事の内容]` で [共通の起動手順](references/start.md) を実行する。`/skill:herdr start` や「herdrスキルのstartを実行して」も同じ。仕事の指定がなければ体制とWorkboardを準備する。

## 依頼に応じて読む

- 既存paneの確認・送信・出力読み取りだけなら [CLI操作](references/cli.md) を使う。チームを新設しない。
- チームの編成・実行なら [役割とpacket](references/roles.md) と [起動・台帳・回収](references/operations.md)、[Workboard連携](references/workboard.md) を使う。
- `Helix`、`P-A`〜`P-F`、`M-#` が指定されたら、上記に加えて [編成プリセット](references/pipelines.md) を読む。
- 設計やスキル整理だけの依頼では、実agentを起動しない。

## 基本の役割分担

| 役割 | 人間との相談 | 担当すること |
| --- | --- | --- |
| 人事 | 必要な専門性、担当の構成・交代 | 担当の設計・作成・配置。使える担当と能力を記録する |
| PM | 目標・方針の壁打ち、進捗・成果の確認 | 仕事の分解、実行役への指示、依存関係の管理、成果の採否 |
| 実行役 | 通常の作業報告はPMへ返す | 割り当てられた調査・実装・検証などを行う |

実行役への作業指示はPMに一本化する。人事はroleの設定までを担当し、taskを配信しない。PMは足りない能力と理由を人事へ伝え、人事が用意した担当を使う。人間の直接指示は優先し、関係する方針・担当範囲をPMと共有して二重指示を防ぐ。

```text
相談タブ       [ 人事 | PM ]
Workboard     [ todo | doing | review | done ]
状態別タブ     各カードに結びついた実行役のpaneを配置
人間           ↔ 人事 / PM
PM             → 仕事の指示 → 実行役 → 成果・進捗 → PM
PM             → 担当の補充・交代依頼 → 人事
```

既存のPM paneを利用できれば再利用する。人事は編成・交代・相談時に動き、待機中の定期推論は不要。Workboardでは1カードに1作業paneを結び、状態別タブへ配置する。人事・PMは相談タブに置く。Workboardを使わない明示指定時だけ1担当1タブなどの配置を使う。

複数の仕事を扱う場合は共通の人事と仕事別PMを置く。仕事間の優先順位や編集範囲の調整が必要な場合だけ全体調整役を追加する。単一の仕事に全体調整役と仕事別PMを重ねない。

## 進め方

1. 目標・完了条件・repo・認可範囲を確認し、PMがWorkboardにカードを用意する。
2. 人事が既存担当・スキルの活用を優先して必要な担当を配置する。作成後に実IDと役割の理解を確認する。
3. PMが依存条件を満たす仕事を、担当範囲と検証条件付きで実行役へ送る。
4. PMは人間との相談を続け、結果や質問を回収してWorkboardのカードを更新する。採用済み成果だけを次の仕事の前提にする。
5. PMが実物と必要な検証で完了条件を確認する。担当不足や交代は人事へ戻す。

Workboardを進捗の正本とし、カードに「依頼・理由・担当・状態・成果・確認待ち事項」を残す。自動同期はOFFにし、PMの採用後にだけdoneへ進める。Markdownには指示・成果・引き継ぎの詳細を保存し、進捗を二重管理しない。会話履歴やHerdrのidle表示だけで進捗・完了を判断しない。

## 操作と権限

- CLIの構文はインストール済みのversion・helpで確認する。IDは応答JSONから取得し、番号から作らない。
- 実操作の前に `HERDR_ENV=1` とworkspaceを確認する。管理外ならpacket・dry-run準備まで進め、実起動は未実施と伝える。
- agentへの指示は `agent prompt`、shellへのコマンドは `pane run`。working中に別taskを重ねず、timeoutやstalledでは状態と結果を読んでから判断する。
- 担当追加は権限拡張ではない。ユーザーの認可・Git owner・対象pathを引き継ぐ。共有index操作は指定ownerに限定する。
- 各台帳の書き手は一人にする。同じpathの編集は直列化するか独立checkoutへ分ける。独立レビュー担当は実装担当と分ける。
- 認可済みチーム内の連絡だけを行う。外部送信・定期監視・通知を自動で追加しない。
- 作成していないtab・pane・sessionを閉じない。途中交代は旧担当の停止と成果回収を確認する。

## 補助スクリプトと検証

- [create-pair.zsh](scripts/create-pair.zsh) は相談タブを左右に分割し、実IDと途中状態を保存する。`--dry-run` は管理外でも使える。agent起動・task送信は行わない。
- [wait-workers.zsh](scripts/wait-workers.zsh) は複数担当の状態変化を監視する。`ALL_SETTLED` は成果の合格を意味しない。

```zsh
zsh -n <skill-dir>/scripts/create-pair.zsh
zsh -n <skill-dir>/scripts/wait-workers.zsh
python3 <skill-dir>/scripts/test_create_pair.py
```

stub検証、実Herdrでの配置・起動、仕事の完走は別々に報告する。
