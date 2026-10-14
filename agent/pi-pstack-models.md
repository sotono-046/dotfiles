# pstack model configuration

共通AGENTS.mdのpstack試験運用に従う。pi本体の既定モデルはこのファイルでは変更しない。
役割のモデルはCodexと同じ分担を、piのprovider/model-id形式で指定する。

feature, refactoring: openai-codex/gpt-6.1-sol
bug-fix: openai-codex/gpt-6-astra
perf-issue: openai-codex/gpt-6-astra
hillclimb: openai-codex/gpt-6-astra
judgment and prose: openai-codex/gpt-6.1-sol
strongest judgment: openai-codex/gpt-6-astra
how explorer: openai-codex/gpt-6.1-sol
how explainer: openai-codex/gpt-6.1-sol
why investigators: openai-codex/gpt-6-astra
why synthesizer: openai-codex/gpt-6.1-sol
reflect tooling: openai-codex/gpt-6.1-sol
reflect judgment, divergent, synthesizer: openai-codex/gpt-6.1-sol
arena runners: openai-codex/gpt-6.1-sol, openai-codex/gpt-6-astra
arena cross-judge pool: openai-codex/gpt-6.1-sol, openai-codex/gpt-6-astra
swarm workers: openai-codex/gpt-6.1-sol
architect runners: openai-codex/gpt-6.1-sol, openai-codex/gpt-6-astra
interrogate reviewers: openai-codex/gpt-6.1-sol, openai-codex/gpt-6-astra

default effort: high
session hook: off
