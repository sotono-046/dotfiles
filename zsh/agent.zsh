# Read-only launchers for local agent CLIs.

typeset -g _DOTFILES_AGENT_ROOT="${${(%):-%N}:A:h:h}"

_agent_ro_reject_claude_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --|--permission-mode|--permission-mode=*|--tools|--tools=*|--settings|--settings=*|\
      --setting-sources|--setting-sources=*|--allowedTools|--allowedTools=*|\
      --allowed-tools|--allowed-tools=*|--disallowedTools|--disallowedTools=*|\
      --disallowed-tools|--disallowed-tools=*|--mcp-config|--mcp-config=*|\
      --plugin-dir|--plugin-dir=*|--plugin-url|--plugin-url=*|--agent|--agent=*|\
      --agents|--agents=*|--add-dir|--add-dir=*|--dangerously-skip-permissions|\
      --allow-dangerously-skip-permissions|--worktree|--worktree=*|--tmux|--tmux=*|\
      --chrome|--cloud|--cloud=*|--environment|--environment=*)
        print -u2 -- "claude-ro: unsafe or conflicting option is not allowed: $arg"
        return 2
        ;;
    esac
  done
}

_agent_ro_reject_codex_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --|--sandbox|--sandbox=*|-s|-s=*|-s?*|--ask-for-approval|--ask-for-approval=*|-a|-a=*|-a?*|\
      --config|--config=*|-c|-c=*|-c?*|--profile|--profile=*|-p|-p=*|-p?*|--add-dir|\
      --add-dir=*|--remote|--remote=*|--dangerously-bypass-approvals-and-sandbox|\
      --dangerously-bypass-hook-trust|--yolo|--full-auto)
        print -u2 -- "codex-ro: unsafe or conflicting option is not allowed: $arg"
        return 2
        ;;
    esac
  done
}

claude-ro() {
  _agent_ro_reject_claude_args "$@" || return $?
  command claude "$@" \
    --permission-mode dontAsk \
    --tools "Read,Grep,Glob,WebFetch,WebSearch" \
    --strict-mcp-config \
    --setting-sources "" \
    --settings "$_DOTFILES_AGENT_ROOT/agent/readonly-settings.json"
}

codex-ro() {
  _agent_ro_reject_codex_args "$@" || return $?
  command codex "$@" \
    --sandbox read-only \
    --ask-for-approval never
}
