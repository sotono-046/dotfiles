---
name: claude-skill-creator
description: Claude用スキルを作成・更新し、必要な場合に配布用.skillを作る。Codex用はCodex標準のskill-creatorを使う。
license: Complete terms in LICENSE.txt
---

# Claude Skill Creator

Claude向けの知識・workflowを必要な範囲で再利用できるスキルにする。Codex用の作成依頼は利用可能なCodex標準skill-creatorへ渡す。対象runtimeが文脈で分かれば聞き直さない。

## 作成・更新

- 明示された対象と保存先を使い、作業範囲・完了条件・非自明な制約を先に整理する。小さな編集に用例収集や固定フェーズを要求しない。
- descriptionは能力と発火条件を短く記す。広いキーワード列挙、ALWAYS、他スキルと競合する呼び込みを避ける。
- 本文には判断を変える情報、必要な権限境界、利用するtool/referenceだけを書く。一般知識やモデルの能力についての決めつけを追加しない。
- 多モードの詳細は参照へ分け、どの状況で読むかを示す。短い自己完結スキルにrouterや余計なファイルを増やさない。
- スクリプトは反復する処理や壊れやすい操作を安定化する場合に追加する。ユーザーの承認済み作業を止める架空の承認段階を追加しない。
- 既存のユーザー指定・安全境界・未関連のメタデータを保つ。

## 検証と完了

`python3 scripts/quick_validate.py <skill-directory>` でfrontmatterを確認し、参照先と変更した動作を検証する。複雑な判断境界や高リスクの変更は、代表的な依頼と最小の資料を渡した独立レビューで確認する。期待する答えを先に教えず、任意の表現改善だけで反復しない。

ローカル利用なら更新ファイルと検証結果で完了する。配布用 `.skill` が依頼された場合だけ、含めるファイルに秘密・cache・過去の成果物がないことを確認し、次を実行する。

```bash
python3 scripts/package_skill.py <skill-directory> <output-directory>
```

output-directoryはskill-directoryの外にする。生成したアーカイブの中身を確認し、パスを返す。公開・アップロードは依頼に含まれる場合のみ行う。
