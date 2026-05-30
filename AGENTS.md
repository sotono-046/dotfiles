# Repository Guidelines

## Project Structure & Module Organization

This repository stores personal dotfiles and agent configuration. Root files are user-facing configs: `.zshrc`, `.tmux.conf`, `starship.toml`, `zellij.conf`, `zellij.kdl`, `ccstatusline.json`, `Brewfile`, and `install.sh`. `raycast/` contains Raycast helper scripts. `agent/` contains Codex/Claude configuration, with `agent/skills/` for skill packages, `agent/commands/` for slash-command prompts, `agent/agents/` for subagent definitions, and `agent/settings.json` for tool permissions and hooks. Follow `agent/AGENTS.md` when changing files under `agent/`.

## Build, Test, and Development Commands

- `./install.sh`: symlinks dotfiles into their expected locations and installs/configures local tooling.
- `brew bundle --file Brewfile`: installs Homebrew dependencies declared by this repo.
- `zsh -n .zshrc install.sh raycast/*.sh`: checks shell syntax without executing scripts.
- `git diff --check`: detects whitespace errors before committing.

There is no single build step. Validate the specific config you touched, then run the lightweight checks above.

## Coding Style & Naming Conventions

Use shell scripts for setup and automation, with `#!/usr/bin/env zsh` or the existing interpreter style. Prefer two-space indentation in shell control blocks and keep commands readable over clever. Quote paths and variables unless intentional word splitting is required. Use lowercase, hyphenated names for new command or skill directories when possible, matching `agent/skills/git-ops` and `agent/skills/green-loop`. Markdown files should use concise headings, examples, and direct instructions.

## Testing Guidelines

Test changes with the narrowest safe command. For shell edits, run `zsh -n` on the changed script and, when practical, execute the command in a temporary environment before touching real dotfiles. For agent skills and commands, inspect the rendered Markdown and verify referenced paths, scripts, and trigger phrases exist. For install changes, prefer a dry review of symlink targets before running `./install.sh`.

## Commit & Pull Request Guidelines

Git history uses Conventional Commit style such as `feat(starship): ...`, `fix(zshrc): ...`, `docs(skills): ...`, and `chore(plugin-creator): ...`. Keep commits focused by area. Pull requests should explain the affected config or agent workflow, list validation commands run, and call out any local-machine side effects such as symlink changes, package installs, or permission updates.

## Security & Configuration Tips

Do not commit machine-local secrets, private tokens, generated caches, or decrypted environment files. Keep permission changes in `agent/settings.json` minimal and explain why broader tool access is needed.
