export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(
    git
)

source $ZSH/oh-my-zsh.sh

# eval "$(op signin)"
eval "$(zoxide init zsh)"
colima start

# Use python 3.14 from brew
# alias py=/opt/homebrew/bin/python3
# alias python=/opt/homebrew/bin/python3

# Use python 3.9 from system installation
# alias py=/usr/bin/python3
# alias python=/usr/bin/python3

# Created by `pipx` on 2026-03-25 03:48:43
export PATH="$HOME/.local/bin:$PATH"

alias lg='lazygit'
alias lg-patch='~/.config/lazygit/fix-untracked-marker.sh'
alias ld='lazydocker'
alias lc='just card'
alias lcg='VISUAL=nvim cards-gh'

# Replace ls with eza
alias ls='eza -lh --icons --group-directories-first'
alias ll='eza -lh --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lla='eza -lah --icons --group-directories-first'

# Quick
alias zshrc="nvim ~/.zshrc"
alias reload="source ~/.zshrc"
alias clauderc="nvim ~/.claude"
alias paint="textual-paint"

# Run Pending Commands
alias rn="sh ~/.local/lib/cards/checks.local.sh"
alias rny="sh ~/.local/lib/cards/checks.local.sh -y"

# Projects
alias source-atlas="source ~/dev/Atlas/backend/.venv/bin/activate"

# RipGrep
alias ff="rg --files | rg "
alias ffa="sudo rg --files | rg "

# Git Identities -- gh's account (pushes, PRs: machine-wide) + this repo's commit author
git-josh() {
    gh auth switch --hostname github.com --user JoshCunningHum || return
    git rev-parse --git-dir >/dev/null 2>&1 &&
        git config --local user.name "joshcunninghum" &&
        git config --local user.email "<jkdimpas@gmail.com>"
}
git-kenshi() {
    gh auth switch --hostname github.com --user ops-kenshi || return
    git rev-parse --git-dir >/dev/null 2>&1 &&
        git config --local user.name "ops-kenshi" &&
        git config --local user.email "jk.dimpas@opswerks.com"
}

alias aws-dev="export AWS_PROFILE='Dev'; aws sso login"
alias aws-prod="export AWS_PROFILE='Prod'; aws sso login"

# Quit nvim in every tmux pane (:qa, so unsaved buffers keep their pane open).
# -f: kill every nvim process instead (SIGTERM; unsaved work survives only in swap files)
nvim-kill-all() {
  # pane_id -> session:window.pane (window name) for every pane running nvim
  local -A targets
  local id loc cmd
  tmux list-panes -a -F '#{pane_id}|#{session_name}:#{window_index}.#{pane_index} (#{window_name})|#{pane_current_command}' 2>/dev/null |
    while IFS='|' read -r id loc cmd; do
      [[ $cmd == nvim ]] && targets[$id]=$loc
    done

  if [[ $1 == -f ]]; then
    pkill -TERM -x nvim || { echo "No nvim running"; return; }
    echo "Killed nvim (SIGTERM) in ${#targets} tmux pane(s):"
    for id in ${(k)targets}; do echo "  ${targets[$id]}"; done
    return
  fi

  (( ${#targets} )) || { echo "No nvim running in tmux"; return; }
  for id in ${(k)targets}; do
    tmux send-keys -t "$id" C-\\ C-n Escape ':qa' Enter
  done
  sleep 0.5

  local closed=() left=()
  for id in ${(k)targets}; do
    if [[ $(tmux display-message -p -t "$id" '#{pane_current_command}' 2>/dev/null) == nvim ]]; then
      left+=("${targets[$id]}")
    else
      closed+=("${targets[$id]}")
    fi
  done
  (( ${#closed} )) && print -l "Closed nvim in:" "${(@)closed/#/  }"
  (( ${#left} )) && print -l "Still open (unsaved changes?):" "${(@)left/#/  }" "Use 'nvim-kill-all -f' to force."
}

# touch, but makes missing parent dirs (trailing / = just make the dir)
touch() {
  local f
  for f in "$@"; do
    [[ $f == -* ]] && continue
    [[ $f == */ ]] && mkdir -p "$f" || mkdir -p "${f:h}"
  done
  local files=("${@:#*/}")
  (( $#files )) && command touch "${files[@]}"
}

function y() {
	local tmp cwd; tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd" || builtin true
	command rm -f -- "$tmp"
}

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

. "$HOME/.local/bin/env"

# Claude Code Auto Update
export CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1

# Vi mode — must stay at the end, after oh-my-zsh's `bindkey -e`,
# so it survives `reload` too.
bindkey -v
KEYTIMEOUT=15

# Block cursor in normal mode, beam in insert
zle-keymap-select() { print -n "${${KEYMAP/vicmd/\e[2 q}/(main|viins)/\e[6 q}"; }
zle-line-init() { print -n '\e[6 q'; }
zle -N zle-keymap-select
zle -N zle-line-init

# fzf binds after `bindkey -v` so Ctrl-R/Ctrl-T survive
source <(fzf --zsh)
export PATH="$HOME/.cargo/bin:$PATH"

# clauth completions
source "/Users/joshkenshidimpas/.clauth/completions/clauth.zsh"


# Clear the OpenCode TUI's "recent models" list (~/.local/state/opencode/model.json).
# Usage: opencode-clear-recent [-f]  (-f skips the confirmation prompt)
opencode-clear-recent() {
  local file="$HOME/.local/state/opencode/model.json"
  if [[ ! -f "$file" ]]; then
    echo "No model.json found at $file" >&2
    return 1
  fi
  if pgrep -x opencode >/dev/null 2>&1; then
    echo "Warning: opencode appears to be running and may overwrite this file on exit." >&2
    echo "Quit all OpenCode windows first, or run 'opencode service restart' afterwards." >&2
  fi
  if [[ "$1" != "-f" ]]; then
    printf "Clear %s recent model(s)? [y/N] " "$(jq '.recent | length' "$file")"
    local reply; read -r reply
    [[ "$reply" == y* ]] || { echo "Aborted."; return 1; }
  fi
  cp "$file" "$file.bak" || return 1
  if jq '.recent = []' "$file" > "$file.tmp" && mv "$file.tmp" "$file"; then
    echo "Cleared. Favorites and variants kept. Backup at $file.bak"
  else
    echo "Failed to update $file" >&2
    rm -f "$file.tmp"
    return 1
  fi
}
