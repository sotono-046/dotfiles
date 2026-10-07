@AGENTS.md

# Claude 固有の運用方針

このファイルは `~/.claude/CLAUDE.md` に配信される Claude 専用の追加指示です。共通方針は `@AGENTS.md`（`agent/AGENTS.md`）を参照すること。

## Claude Code でのモデル分担

- Codex（Sol・Luna・Astra、Codex worker、外部 Codex CLI）は、ユーザーが今回の依頼で明示した場合だけ使う。`AGENTS.md` や `adaptive-orchestration` にある「Codexを主な実行エージェントにする」「定型作業はLuna」は、明示がなければ以下で読み替える。
- 実行役は、指定がなければ Haiku 5.5 を使う。対象は仕様・path・手順が確定した実装、機械的な置換、テスト実行、範囲の決まった調査。Agent tool では `model: "haiku"`、CLI では `claude --model haiku` で起動し、起動時に Haiku 5.5 へ解決されることを確認する。
- 司令塔・判断を伴う実装・独立レビューは Opus が担う。Haiku が仕様の不足や未確定の判断を見つけたら、推測で埋めず司令塔へ返させる。
- モデル・agent・effort の明示指定はこの既定より優先する。
