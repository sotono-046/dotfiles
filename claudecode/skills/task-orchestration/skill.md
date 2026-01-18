---
name: task-orchestration
description: "Taskツールを使用したサブエージェントの効率的な並列運用を提供するスキル。調査・実装・検証の各フェーズでサブエージェントを並列起動し、タスクを効率的に処理。対象：(1) 複数観点からの並列調査、(2) 独立サブタスクの同時実行、(3) バックグラウンドタスクの管理。"
---

# タスクオーケストレーション

サブエージェントを効率的に並列運用し、複雑なタスクを分割・実行する。

## トリガー条件

- 複数観点からの調査が必要なとき
- 独立した複数のサブタスクを実行するとき
- 長時間タスクをバックグラウンドで実行するとき

---

## 1. 利用可能なサブエージェント

| サブエージェント       | 役割                         | 主な用途                           |
| ---------------------- | ---------------------------- | ---------------------------------- |
| pre-task-investigator  | 事前調査・コンテキスト収集   | 実装前の現状把握、依存関係の調査   |
| task-splitter-executor | タスク分割・実装実行         | 複雑なタスクの分割と段階的実装     |
| code-quality-reviewer  | コードレビュー・品質チェック | 実装後の品質検証                   |
| Explore                | コードベース探索・検索       | ファイル検索、コード構造の理解     |
| Plan                   | 実装計画の設計               | アーキテクチャ設計、実装戦略の立案 |

---

## 2. 並列実行の原則

### フェーズ1: 調査（Investigation）

複数の `pre-task-investigator` を並列起動し、異なる観点から情報を収集する。

```
# 並列調査の例
Task ツールを複数回並列で呼び出し:

1. subagent_type: pre-task-investigator
   prompt: "認証システムの現状実装を調査してください"

2. subagent_type: pre-task-investigator
   prompt: "関連するAPIエンドポイントの構造を調査してください"

3. subagent_type: Explore
   prompt: "設定ファイルとスキーマ定義を探索してください"
```

### フェーズ2: 実装（Execution）

独立したサブタスクを `task-splitter-executor` で同時実行する。

```
# 並列実装の例
Task ツールを複数回並列で呼び出し:

1. subagent_type: task-splitter-executor
   prompt: "ユーザー認証モジュールを実装してください"

2. subagent_type: task-splitter-executor
   prompt: "データベーススキーマを作成してください"
```

### フェーズ3: 検証（Verification）

`code-quality-reviewer` で品質をチェックし、問題があれば修正する。

```
# 品質検証の例
Task ツールを呼び出し:

subagent_type: code-quality-reviewer
prompt: "実装したコードの品質をチェックしてください"
```

---

## 3. バックグラウンド実行

長時間かかるタスクは `run_in_background: true` を指定する。

### バックグラウンド起動

```
Task ツールを呼び出し:

subagent_type: task-splitter-executor
prompt: "全テストスイートを実行してください"
run_in_background: true
```

### 結果の取得

```
TaskOutput ツールを呼び出し:

task_id: [起動時に返されたID]
block: false  # 完了を待たない場合
```

### 開発サーバーの起動

ユーザーに動作確認させる場合：

```
Bash ツールを呼び出し:

command: "npm run dev"
run_in_background: true
```

---

## 4. 注意事項

### 競合の回避

- **同一ファイルの同時編集禁止**: 複数エージェントが同じファイルを編集しない
- **依存関係の考慮**: 依存するタスクは順次実行する
- **フェーズの分離**: 調査→実装→検証の順序を守る

### エージェント間の連携

- 各エージェントの完了を確認してから次フェーズへ進む
- 調査結果は実装エージェントに適切に引き継ぐ
- 検証で発見された問題は該当する実装エージェントで修正

### リソース管理

- 同時起動するエージェント数は必要最小限に
- バックグラウンドタスクは完了後に適切に処理
- 不要なエージェントは起動しない

---

## 5. 実行パターン例

### パターンA: 機能追加

```
1. [並列調査]
   - pre-task-investigator: 既存実装の調査
   - pre-task-investigator: 関連するテストの調査
   - Explore: ディレクトリ構造の確認

2. [計画]
   - Plan: 実装計画の策定

3. [並列実装]
   - task-splitter-executor: コア機能の実装
   - task-splitter-executor: テストの実装

4. [検証]
   - code-quality-reviewer: 品質チェック
```

### パターンB: バグ修正

```
1. [調査]
   - pre-task-investigator: バグの原因調査
   - Explore: 関連コードの探索

2. [実装]
   - task-splitter-executor: 修正の実装

3. [検証]
   - code-quality-reviewer: 修正の検証
```

### パターンC: リファクタリング

```
1. [並列調査]
   - pre-task-investigator: 対象コードの依存関係調査
   - pre-task-investigator: 影響範囲の調査

2. [計画]
   - Plan: リファクタリング計画

3. [段階的実装]
   - task-splitter-executor: 段階1の実装
   - [検証後]
   - task-splitter-executor: 段階2の実装

4. [最終検証]
   - code-quality-reviewer: 全体の品質チェック
```

---

## チェックリスト

### 並列実行前

- [ ] タスク間の依存関係を確認した
- [ ] 同一ファイルへの同時アクセスがないか確認した
- [ ] 適切なサブエージェントを選択した

### 各フェーズ完了時

- [ ] 全エージェントの完了を確認した
- [ ] 結果を次フェーズに適切に引き継いだ
- [ ] エラーや問題がないか確認した

### タスク完了時

- [ ] 全フェーズが正常に完了した
- [ ] バックグラウンドタスクを適切に処理した
- [ ] 最終的な品質検証を実施した
