#!/usr/bin/env bash
set -euo pipefail

# Docker/Linux friendly installer for this dotfiles repo.
# The original install.sh is macOS/Homebrew oriented. This script avoids root/sudo
# and installs the small set of tools needed by this Docker environment under
# /opt/data by default.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DATA_DIR:-/opt/data}"
HOME_DIR="${HOME_DIR:-$DATA_DIR/home}"
PREFIX="${PREFIX:-$DATA_DIR/local}"
BIN_DIR="${BIN_DIR:-$DATA_DIR/bin}"
TMP_DIR="${TMP_DIR:-$DATA_DIR/.local/tmp-docker-install}"
DRY_RUN=0
LINKS_ONLY=0
PREPARE_REPLACING=0
SKILL_SOURCE="$SCRIPT_DIR/agent/skills"

export PATH="$BIN_DIR:$HOME_DIR/bin:$PATH"

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

  # Parent traversal can change meaning across symlinked ancestors. Reject it
  # instead of guessing which path a later write uses.
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
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --links-only) LINKS_ONLY=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h|--help)
        printf 'Usage: ./install_for_docker.sh [--links-only] [--dry-run]\n'
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n' "$1" >&2
        exit 2
        ;;
    esac
    shift
  done
  case "$HOME_DIR" in
    /*) ;;
    *)
      printf 'HOME_DIR must be an absolute path: %s\n' "$HOME_DIR" >&2
      exit 2
      ;;
  esac
  local canonical_home
  if ! canonical_home="$(canonicalize_directory_path "$HOME_DIR")"; then
    printf 'HOME_DIR must resolve to a directory path: %s\n' "$HOME_DIR" >&2
    exit 2
  fi
  if [ "$canonical_home" = "/" ]; then
    printf 'HOME_DIR must not resolve to /.\n' >&2
    exit 2
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

machine_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *)
      printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
      exit 1
      ;;
  esac
}

latest_github_version() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | python3 -c 'import sys,json; print(json.load(sys.stdin)["tag_name"].lstrip("v"))'
}

install_gh() {
  if need_cmd gh; then
    log "gh already available: $(command -v gh)"
    return
  fi

  local arch version asset url work
  arch="$(machine_arch)"
  version="$(latest_github_version cli/cli)"
  asset="gh_${version}_linux_${arch}.tar.gz"
  url="https://github.com/cli/cli/releases/download/v${version}/${asset}"
  work="$TMP_DIR/gh"

  log "Installing gh ${version} to ${BIN_DIR}"
  prepare_work_directory "$work"
  curl -fL --retry 3 -o "$work/$asset" "$url"
  tar -xzf "$work/$asset" -C "$work"
  cp "$work/gh_${version}_linux_${arch}/bin/gh" "$BIN_DIR/gh"
  chmod +x "$BIN_DIR/gh"
}

install_starship() {
  if need_cmd starship; then
    log "starship already available: $(command -v starship)"
    return
  fi

  local arch target version asset url work
  arch="$(machine_arch)"
  case "$arch" in
    amd64) target="x86_64-unknown-linux-gnu" ;;
    arm64) target="aarch64-unknown-linux-musl" ;;
  esac
  version="$(latest_github_version starship/starship)"
  asset="starship-${target}.tar.gz"
  url="https://github.com/starship/starship/releases/download/v${version}/${asset}"
  work="$TMP_DIR/starship"

  log "Installing starship ${version} to ${BIN_DIR}"
  prepare_work_directory "$work"
  curl -fL --retry 3 -o "$work/$asset" "$url"
  tar -xzf "$work/$asset" -C "$work"
  cp "$work/starship" "$BIN_DIR/starship"
  chmod +x "$BIN_DIR/starship"
}

install_zsh_userland() {
  if [ -x "$BIN_DIR/zsh" ] && "$BIN_DIR/zsh" -c 'zmodload zsh/zle' >/dev/null 2>&1; then
    log "zsh already available: $BIN_DIR/zsh"
    return
  fi

  if ! need_cmd apt-get || ! need_cmd dpkg-deb; then
    warn "apt-get/dpkg-deb not found; skipping userland zsh install"
    return
  fi

  log "Installing zsh under ${PREFIX} without sudo"
  local work
  work="$TMP_DIR/zsh"
  prepare_work_directory "$work"
  (
    cd "$work"
    apt-get download zsh zsh-common
    for deb in zsh-common_*.deb zsh_*.deb; do
      dpkg-deb -x "$deb" "$PREFIX"
    done
  )

  cat > "$BIN_DIR/zsh" <<EOF
#!/bin/sh
export ZDOTDIR="$HOME_DIR"
export PATH="$BIN_DIR:$HOME_DIR/bin:\$PATH"
exec "$PREFIX/usr/bin/zsh" "\$@"
EOF
  chmod +x "$BIN_DIR/zsh"
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
  path_exists "$path" || return 0
  local backup
  backup="$(next_backup_path "$path")"
  log "Backing up $path to $backup"
  run_cmd mv "$path" "$backup"
}

prepare_work_directory() {
  local work="$1"
  backup_path "$work"
  run_cmd mkdir -p "$work"
}

safe_unlink() {
  local path="$1"
  [ -L "$path" ] || return 0
  log "Unlinking managed symlink: $path"
  run_cmd unlink "$path"
}

link_file() {
  local src="$1"
  local dest="$2"

  if [ ! -e "$src" ]; then
    warn "Missing source: $src"
    return
  fi

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    log "Already linked: $dest"
    return
  fi
  backup_path "$dest"
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
  PREPARE_REPLACING=0
  if [ -L "$dest" ]; then
    PREPARE_REPLACING=1
    if [ "$(readlink "$dest")" = "$SKILL_SOURCE" ]; then
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
  [ "$skip_scan" -eq 0 ] || return 0
  local existing name target
  for existing in "$skills_home"/* "$skills_home"/.*; do
    path_exists "$existing" || continue
    name="$(basename "$existing")"
    case "$name" in .|..|.system) continue ;; esac
    [ -L "$existing" ] || continue
    target="$(readlink "$existing")"
    case "$target" in
      "$SKILL_SOURCE"/*)
        [ -f "$SKILL_SOURCE/$name/SKILL.md" ] || safe_unlink "$existing"
        ;;
    esac
  done
}

bootstrap_codex_system() {
  local skills_home="$1"
  local parent_replaced="$2"
  local source_system="$SKILL_SOURCE/.system"
  local dest_system="$skills_home/.system"
  [ -d "$source_system" ] || return 0
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
  prepare_real_directory "$skills_home"
  local parent_replaced="$PREPARE_REPLACING"
  remove_stale_skill_links "$skills_home" "$parent_replaced"

  local skill_src name
  for skill_src in "$SKILL_SOURCE"/* "$SKILL_SOURCE"/.*; do
    [ -d "$skill_src" ] || continue
    [ -f "$skill_src/SKILL.md" ] || continue
    name="$(basename "$skill_src")"
    case "$name" in .|..|.system) continue ;; esac
    if [ "$DRY_RUN" -eq 1 ] && [ "$parent_replaced" -eq 1 ]; then
      run_cmd ln -s "$skill_src" "$skills_home/$name"
    else
      link_file "$skill_src" "$skills_home/$name"
    fi
  done

  if [ "$runtime" = "codex" ]; then
    bootstrap_codex_system "$skills_home" "$parent_replaced"
  fi
}

write_docker_shell_bootstrap() {
  log "Writing Docker shell bootstrap: $DATA_DIR/env.sh"
  cat > "$DATA_DIR/env.sh" <<EOF
# Source this after Docker restart to expose userland tools installed under ${DATA_DIR}.
export PATH="${BIN_DIR}:${HOME_DIR}/bin:\$PATH"
export ZDOTDIR="${HOME_DIR}"
EOF

  log "Writing Docker profile bootstrap: $HOME_DIR/.profile"
  cat > "$HOME_DIR/.profile" <<EOF
# Generated by install_for_docker.sh.
. "$DATA_DIR/env.sh"
EOF

  log "Writing Docker zsh bootstrap: $HOME_DIR/.zshenv"
  cat > "$HOME_DIR/.zshenv" <<EOF
# Generated by install_for_docker.sh.
# Userland zsh is installed under ${PREFIX}; make modules/functions discoverable.
module_path=(${PREFIX}/usr/lib/aarch64-linux-gnu/zsh/5.9 ${PREFIX}/usr/lib/x86_64-linux-gnu/zsh/5.9 \$module_path)
fpath=(${PREFIX}/usr/share/zsh/functions/* \$fpath)
export PATH="${BIN_DIR}:${HOME_DIR}/bin:\$PATH"
EOF
}

maybe_set_default_shell() {
  if [ "${SET_DEFAULT_SHELL:-0}" != "1" ]; then
    return
  fi

  local shell_path="${DEFAULT_SHELL_PATH:-$BIN_DIR/zsh}"
  local target_user="${DEFAULT_SHELL_USER:-${USER:-root}}"

  if [ "$(id -u)" != "0" ]; then
    warn "SET_DEFAULT_SHELL=1 requested, but current user is not root; run as root to change login shell"
    return
  fi

  if [ ! -x "$shell_path" ]; then
    warn "Default shell path is not executable: $shell_path"
    return
  fi

  if [ -w /etc/shells ] && ! grep -qxF "$shell_path" /etc/shells; then
    log "Adding $shell_path to /etc/shells"
    printf '%s\n' "$shell_path" >> /etc/shells
  fi

  if command -v chsh >/dev/null 2>&1; then
    log "Setting default shell for $target_user to $shell_path"
    chsh -s "$shell_path" "$target_user"
  else
    warn "chsh not found; edit /etc/passwd manually or install passwd utilities"
  fi
}

install_tpm() {
  if ! need_cmd git; then
    warn "git not found; skipping tmux plugin manager"
    return
  fi

  local tpm_dir="$HOME_DIR/.tmux/plugins/tpm"
  if [ -d "$tpm_dir" ]; then
    log "tpm already installed: $tpm_dir"
    return
  fi

  log "Installing tmux plugin manager"
  git clone https://github.com/tmux-plugins/tpm "$tpm_dir" || warn "tpm clone failed"
}

link_dotfiles() {
  remove_managed_link "$HOME_DIR/.claude/commands" "$SCRIPT_DIR/agent/commands"
  remove_managed_link "$HOME_DIR/.codex/prompts" "$SCRIPT_DIR/agent/commands"

  link_file "$SCRIPT_DIR/.zshrc" "$HOME_DIR/.zshrc"
  link_file "$SCRIPT_DIR/starship.toml" "$HOME_DIR/.config/starship.toml"
  link_file "$SCRIPT_DIR/.tmux.conf" "$HOME_DIR/.tmux.conf"
  link_file "$SCRIPT_DIR/ccstatusline.json" "$HOME_DIR/.config/ccstatusline/settings.json"
  link_file "$SCRIPT_DIR/agent/CLAUDE.md" "$HOME_DIR/.claude/CLAUDE.md"
  link_file "$SCRIPT_DIR/agent/AGENTS.md" "$HOME_DIR/.codex/AGENTS.md"
  link_file "$SCRIPT_DIR/agent/AGENTS.md" "$HOME_DIR/.gemini/GEMINI.md"
  link_file "$SCRIPT_DIR/agent/agents" "$HOME_DIR/.claude/agents"
  link_file "$SCRIPT_DIR/agent/settings.json" "$HOME_DIR/.claude/settings.json"
  install_skill_links "$HOME_DIR/.claude/skills" claude
  install_skill_links "$HOME_DIR/.codex/skills" codex
  if [ -e "$SCRIPT_DIR/agent/statusline-command.sh" ]; then
    link_file "$SCRIPT_DIR/agent/statusline-command.sh" "$HOME_DIR/.claude/statusline-command.sh"
  fi
}

main() {
  parse_args "$@"
  log "Docker dotfiles install"
  log "SCRIPT_DIR=$SCRIPT_DIR"
  log "HOME_DIR=$HOME_DIR"
  log "PREFIX=$PREFIX"
  log "BIN_DIR=$BIN_DIR"

  if [ "$LINKS_ONLY" -eq 1 ]; then
    run_cmd mkdir -p "$HOME_DIR"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "Would install userland tools and write Docker shell bootstrap"
  else
    mkdir -p "$HOME_DIR" "$PREFIX" "$BIN_DIR" "$TMP_DIR"
    if ! need_cmd curl || ! need_cmd python3 || ! need_cmd tar; then
      warn "curl, python3, and tar are required for tool downloads"
    else
      install_zsh_userland
      install_gh
      install_starship
    fi
    write_docker_shell_bootstrap
    install_tpm
    maybe_set_default_shell
  fi

  link_dotfiles

  log "Install completed"
  log "Run: export PATH=\"$BIN_DIR:$HOME_DIR/bin:\$PATH\" && zsh"
}

main "$@"
