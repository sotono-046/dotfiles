---
name: playwright-cli
description: ターミナルで Playwright を使うとき — `npx playwright test`（テストランナー）、`codegen`（操作からコード生成）、`screenshot` / `pdf`（一回撮り）、CI 用シャーディング。エージェント主導のリアルタイムブラウザ操作には使わない（その場合は `claude-in-chrome` 等の MCP を使う）。
---

# Playwright CLI

`npx playwright` による**ターミナル上の**ブラウザ自動化。このスキルは **CLI 周り**に限る: テスト実行、`codegen` によるテストコード生成、スクリーンショート／PDF、CI 向け `--shard` など。

## 他との境界

| やりたいこと                                                            | 使うもの                                                                               |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| E2E テストを走らせる                                                    | `npx playwright test`（このスキル）                                                    |
| ブラウザ操作を記録 → テストコードにする                                 | `npx playwright codegen`（このスキル）                                                 |
| 特定 URL から一回だけスクショ／PDF                                      | `npx playwright screenshot` / `pdf`（このスキル）                                      |
| テストスイートの執筆・レビュー・調整                                    | `playwright-test` スキル                                                               |
| **エージェント主導のリアルタイム操作**（遷移 → クリック → 読取 → 検証） | `mcp__claude-in-chrome__*` 等（このスキルではない）                                    |
| インタラクティブなスクレイピングや SPA 探索                             | `claude-in-chrome` の MCP、または `npx playwright test` で動かす Playwright スクリプト |

DOM をプログラムで辿る、「もっと読む」をクリックして JSON を抜く等の**スクレイピング／フロー**は、`tests/*.spec.ts` を書いて `npx playwright test` で実行する。執筆パターンは `playwright-test` スキル参照。

## 早見表

```bash
# 対話的 codegen（操作からテストコードを生成）
npx playwright codegen https://example.com

# 全テスト
npx playwright test

# 特定ファイル
npx playwright test tests/login.spec.ts

# タイトルで指定
npx playwright test -g "should login"

# デバッグ（Playwright Inspector）
npx playwright test --debug

# UI モード（ビジュアル＋時間移動）
npx playwright test --ui

# ヘッド付き（ブラウザ表示）
npx playwright test --headed

# ブラウザ指定
npx playwright test --project=chromium

# トレース
npx playwright test --trace on

# レポート表示
npx playwright show-report

# ブラウザインストール
npx playwright install
npx playwright install chromium --with-deps  # CI 向け
```

## CI 用シャーディング

```bash
npx playwright test --shard=1/3
npx playwright test --shard=2/3
npx playwright test --shard=3/3
```

## スクリーンショット / PDF

```bash
# CLI からスクショ
npx playwright screenshot --browser=chromium https://example.com screenshot.png

# PDF（Chromium のみ）
npx playwright pdf https://example.com page.pdf
```

## 補足: npm パッケージ `playwright-cli`

`npx playwright test` とは別の、対話型 `playwright-cli` のスナップショット／ref 系ワークフローは [references/playwright-cli-npm-tool.md](references/playwright-cli-npm-tool.md) を参照。
