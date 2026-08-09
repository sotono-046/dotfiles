#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
MODE="full"
DRY_RUN=0
PREPARE_REPLACING=0
SKILL_SOURCE="$SCRIPT_DIR/agent/skills"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--links-only | --agent-only] [--dry-run]

  --links-only  Skip dependency installation and install all managed links.
  --agent-only  Skip dependencies and install only agent configuration/skills.
  --dry-run     Print planned dependency/link operations without changing files.

Set DOTFILES_TARGET_HOME to test link installation outside the current HOME.
EOF
}

log() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

normalize_absolute_path() {
  local raw="$1"
  local part result
  local depth=0
  local -a parts=()
  local -a normalized=()

  IFS='/' read -r -a parts <<< "$raw"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) continue ;;
      ..)
        if [ "$depth" -gt 0 ]; then
          depth=$((depth - 1))
          unset "normalized[$depth]"
        fi
        ;;
      *)
        normalized[depth]="$part"
        depth=$((depth + 1))
        ;;
    esac
  done

  result="/"
  for part in "${normalized[@]}"; do
    if [ "$result" = "/" ]; then
      result="/$part"
    else
      result="$result/$part"
    fi
  done
  printf '%s\n' "$result"
}

canonicalize_directory_path() {
  local input="$1"
  local probe="$input"
  local leaf parent suffix=""
  local canonical_base

  # Parent traversal can change meaning across symlinked ancestors (for example,
  # macOS /tmp). Reject it instead of guessing which path a later write uses.
  case "$input" in
    */../*|*/..) return 1 ;;
  esac

  while [ "$probe" != "/" ] && [ "${probe%/}" != "$probe" ]; do
    probe="${probe%/}"
  done

  while ! path_exists "$probe"; do
    [ "$probe" != "/" ] || return 1
    leaf="${probe##*/}"
    parent="${probe%/*}"
    [ -n "$parent" ] || parent="/"
    if [ -n "$leaf" ]; then
      suffix="$leaf${suffix:+/$suffix}"
    fi
    probe="$parent"
    while [ "$probe" != "/" ] && [ "${probe%/}" != "$probe" ]; do
      probe="${probe%/}"
    done
  done

  canonical_base="$(cd -P -- "$probe" 2>/dev/null && pwd -P)" || return 1
  normalize_absolute_path "$canonical_base${suffix:+/$suffix}"
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'DRY-RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

parse_args() {
  local selected_mode=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --links-only)
        if [ -n "$selected_mode" ]; then
          printf 'Only one of --links-only and --agent-only may be used.\n' >&2
          exit 2
        fi
        selected_mode="links"
        MODE="links"
        ;;
      --agent-only)
        if [ -n "$selected_mode" ]; then
          printf 'Only one of --links-only and --agent-only may be used.\n' >&2
          exit 2
        fi
        selected_mode="agent"
        MODE="agent"
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  case "$DOTFILES_HOME" in
    /*) ;;
    *)
      printf 'DOTFILES_TARGET_HOME must be an absolute path: %s\n' "$DOTFILES_HOME" >&2
      exit 2
      ;;
  esac
  local canonical_home
  if ! canonical_home="$(canonicalize_directory_path "$DOTFILES_HOME")"; then
    printf 'DOTFILES_TARGET_HOME must resolve to a directory path: %s\n' "$DOTFILES_HOME" >&2
    exit 2
  fi
  if [ "$canonical_home" = "/" ]; then
    printf 'DOTFILES_TARGET_HOME must not resolve to /.\n' >&2
    exit 2
  fi
}

next_backup_path() {
  local path="$1"
  local base
  base="${path}.dotbackup.$(date +%Y%m%d%H%M%S)"
  local candidate="$base"
  local suffix=1
  while path_exists "$candidate"; do
    candidate="${base}.${suffix}"
    suffix=$((suffix + 1))
  done
  printf '%s\n' "$candidate"
}

backup_path() {
  local path="$1"
  if ! path_exists "$path"; then
    return 0
  fi
  local backup
  backup="$(next_backup_path "$path")"
  log "Backing up $path to $backup"
  run_cmd mv "$path" "$backup"
}

safe_unlink() {
  local path="$1"
  if [ ! -L "$path" ]; then
    return 0
  fi
  log "Unlinking managed symlink: $path"
  run_cmd unlink "$path"
}

link_path() {
  local src="$1"
  local dest="$2"
  if ! path_exists "$src"; then
    warn "Missing source: $src"
    return 0
  fi
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "Already linked: $dest"
    return 0
  fi
  if path_exists "$dest"; then
    backup_path "$dest"
  fi
  run_cmd mkdir -p "$(dirname "$dest")"
  run_cmd ln -s "$src" "$dest"
  log "Linked $dest -> $src"
}

remove_managed_link() {
  local dest="$1"
  local expected="$2"
  if [ ! -L "$dest" ]; then
    if path_exists "$dest"; then
      log "Preserving user-owned path: $dest"
    fi
    return 0
  fi
  if [ "$(readlink "$dest")" = "$expected" ]; then
    safe_unlink "$dest"
  else
    log "Preserving non-managed symlink: $dest"
  fi
}

prepare_real_directory() {
  local dest="$1"
  local managed_whole_link="$2"
  PREPARE_REPLACING=0
  if [ -L "$dest" ]; then
    PREPARE_REPLACING=1
    if [ "$(readlink "$dest")" = "$managed_whole_link" ]; then
      safe_unlink "$dest"
    else
      backup_path "$dest"
    fi
  elif path_exists "$dest" && [ ! -d "$dest" ]; then
    PREPARE_REPLACING=1
    backup_path "$dest"
  elif [ ! -d "$dest" ]; then
    PREPARE_REPLACING=1
  fi
  if [ "$PREPARE_REPLACING" -eq 1 ]; then
    run_cmd mkdir -p "$dest"
  fi
}

remove_stale_skill_links() {
  local skills_home="$1"
  local skip_scan="$2"
  if [ "$skip_scan" -eq 1 ]; then
    return 0
  fi
  local existing name target
  for existing in "$skills_home"/* "$skills_home"/.*; do
    path_exists "$existing" || continue
    name="$(basename "$existing")"
    case "$name" in
      .|..|.system) continue ;;
    esac
    [ -L "$existing" ] || continue
    target="$(readlink "$existing")"
    case "$target" in
      "$SKILL_SOURCE"/*)
        if [ ! -f "$SKILL_SOURCE/$name/SKILL.md" ]; then
          safe_unlink "$existing"
        fi
        ;;
    esac
  done
}

bootstrap_codex_system() {
  local skills_home="$1"
  local parent_replaced="$2"
  local source_system="$SKILL_SOURCE/.system"
  local dest_system="$skills_home/.system"
  if [ ! -d "$source_system" ]; then
    warn "Codex system skill snapshot is unavailable: $source_system"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ] && [ "$parent_replaced" -eq 1 ]; then
    run_cmd cp -R "$source_system" "$dest_system"
    return 0
  fi
  if [ -d "$dest_system" ] && [ ! -L "$dest_system" ]; then
    log "Preserving Codex-owned system skills: $dest_system"
    return 0
  fi
  if [ -L "$dest_system" ] && [ "$(readlink "$dest_system")" = "$source_system" ]; then
    safe_unlink "$dest_system"
  elif path_exists "$dest_system"; then
    backup_path "$dest_system"
  fi
  run_cmd cp -R "$source_system" "$dest_system"
  log "Bootstrapped Codex-owned system skills: $dest_system"
}

install_skill_links() {
  local skills_home="$1"
  local runtime="$2"
  prepare_real_directory "$skills_home" "$SKILL_SOURCE"
  local parent_replaced="$PREPARE_REPLACING"
  remove_stale_skill_links "$skills_home" "$parent_replaced"

  local skill_src name
  for skill_src in "$SKILL_SOURCE"/* "$SKILL_SOURCE"/.*; do
    [ -d "$skill_src" ] || continue
    [ -f "$skill_src/SKILL.md" ] || continue
    name="$(basename "$skill_src")"
    case "$name" in
      .|..|.system) continue ;;
    esac
    if [ "$DRY_RUN" -eq 1 ] && [ "$parent_replaced" -eq 1 ]; then
      run_cmd ln -s "$skill_src" "$skills_home/$name"
      continue
    fi
    link_path "$skill_src" "$skills_home/$name"
  done

  if [ "$runtime" = "codex" ]; then
    bootstrap_codex_system "$skills_home" "$parent_replaced"
  fi
}

install_dependencies() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ "$OS" = "Darwin" ]; then
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || true
  fi

  local brew_formulae=(starship tmux git gh jq fzf ripgrep fd bat eza zoxide node)
  local formula
  for formula in "${brew_formulae[@]}"; do
    if ! brew list --formula "$formula" >/dev/null 2>&1; then
      echo "Installing $formula..."
      brew install "$formula" || true
    fi
  done

  if ! command -v claude >/dev/null 2>&1; then
    echo "Installing Claude Code..."
    if command -v npm >/dev/null 2>&1; then
      npm install -g @anthropic-ai/claude-code || true
    else
      warn "npm not found, skipping Claude Code install"
    fi
  fi

  if ! command -v ccstatusline >/dev/null 2>&1; then
    echo "Installing ccstatusline..."
    if command -v npm >/dev/null 2>&1; then
      npm install -g ccstatusline || true
    else
      warn "npm not found, skipping ccstatusline install"
    fi
  fi

  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Installing tpm..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" || true
  fi
}

install_base_links() {
  local links=(
    ".zshrc:$DOTFILES_HOME/.zshrc"
    "starship.toml:$DOTFILES_HOME/.config/starship.toml"
    ".tmux.conf:$DOTFILES_HOME/.tmux.conf"
    "herdr/config.toml:$DOTFILES_HOME/.config/herdr/config.toml"
    "ccstatusline.json:$DOTFILES_HOME/.config/ccstatusline/settings.json"
  )
  local item
  for item in "${links[@]}"; do
    link_path "$SCRIPT_DIR/${item%%:*}" "${item#*:}"
  done
}

install_agent_links() {
  remove_managed_link "$DOTFILES_HOME/.claude/commands" "$SCRIPT_DIR/agent/commands"
  remove_managed_link "$DOTFILES_HOME/.codex/prompts" "$SCRIPT_DIR/agent/commands"

  local links=(
    "agent/CLAUDE.md:$DOTFILES_HOME/.claude/CLAUDE.md"
    "agent/AGENTS.md:$DOTFILES_HOME/.codex/AGENTS.md"
    "agent/AGENTS.md:$DOTFILES_HOME/.gemini/GEMINI.md"
    "agent/agents:$DOTFILES_HOME/.claude/agents"
    "agent/settings.json:$DOTFILES_HOME/.claude/settings.json"
    "agent/hooks:$DOTFILES_HOME/.claude/hooks"
  )
  local item
  for item in "${links[@]}"; do
    link_path "$SCRIPT_DIR/${item%%:*}" "${item#*:}"
  done

  install_skill_links "$DOTFILES_HOME/.claude/skills" claude
  install_skill_links "$DOTFILES_HOME/.codex/skills" codex
}

main() {
  parse_args "$@"
  log "mode=$MODE target_home=$DOTFILES_HOME dry_run=$DRY_RUN"

  if [ "$MODE" = "full" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      log "Would install Homebrew, CLI dependencies, oh-my-zsh, and tpm"
    else
      install_dependencies
    fi
  fi

  if [ "$MODE" != "agent" ]; then
    install_base_links
  fi
  install_agent_links

  log "Install completed"
  if [ "$MODE" != "agent" ]; then
    log "Restart your terminal or run: source $DOTFILES_HOME/.zshrc"
  fi
}

main "$@"
