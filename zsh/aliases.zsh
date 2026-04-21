# Ported from basecamp/omarchy: default/bash/aliases
# Linux-only bits removed (xdg-open, kitty-specific fzf preview, uwsm paths).

# File system
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

# fzf helpers (macOS uses Ghostty, not kitty, so bat-only preview)
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias eff='$EDITOR "$(ff)"'
sff() {
  if [ $# -eq 0 ]; then
    echo "Usage: sff <destination> (e.g. sff host:/tmp/)"
    return 1
  fi
  local file
  file=$(find . -type f -exec stat -f '%m %N' {} + | sort -rn | cut -d' ' -f2- | ff) \
    && [ -n "$file" ] && scp "$file" "$1"
}

# zoxide-enhanced cd
if command -v zoxide &> /dev/null; then
  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi
      printf "\U000F17A9 "
      pwd
    fi
  }
fi

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias c='opencode'
alias cx='printf "\033[2J\033[3J\033[H" && claude --dangerously-skip-permissions'
alias d='docker'
alias r='rails'
alias t='tmux attach || tmux new -s Work'
n() {
  if [ "$#" -eq 0 ]; then
    command nvim .
  else
    command nvim "$@"
  fi
}

# Git
alias g='git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

# Env
export BAT_THEME=ansi

# fzf keybindings / completion (Homebrew paths on macOS)
if command -v fzf &> /dev/null; then
  _fzf_prefix="$(brew --prefix 2>/dev/null)/opt/fzf/shell"
  [[ -f "$_fzf_prefix/completion.zsh" ]] && source "$_fzf_prefix/completion.zsh"
  [[ -f "$_fzf_prefix/key-bindings.zsh" ]] && source "$_fzf_prefix/key-bindings.zsh"
  unset _fzf_prefix
fi
