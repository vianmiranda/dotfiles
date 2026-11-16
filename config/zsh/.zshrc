# Runtime data lives under XDG dirs (set in .zshenv), not inside $ZDOTDIR.
ZIM_HOME=$XDG_DATA_HOME/zim
HISTFILE=$XDG_DATA_HOME/zsh/history
zstyle ':zim:completion' dumpfile $XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION

fpath=($XDG_CACHE_HOME/zsh/completions $fpath)

# Lazily regenerate sesh's completion (it's a build artifact, not tracked).
if [[ ! -f $XDG_CACHE_HOME/zsh/completions/_sesh ]] && command -v sesh >/dev/null; then
  sesh completion zsh > $XDG_CACHE_HOME/zsh/completions/_sesh
fi
# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source /opt/homebrew/opt/zimfw/share/zimfw.zsh init
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

# Force emacs line-editing mode (zsh otherwise picks vi mode because $EDITOR=vim)
bindkey -e
bindkey '\e[3~' delete-char  # fn+Delete (forward delete)

# Word characters: remove / . - so Ctrl+Backspace stops at path separators, dots, and hyphens
WORDCHARS='*?_[]~=&;!#$%^(){}<>'

# Aliases
alias gs='git status'
alias glp='git log --pretty=format:"%C(yellow)%h%Creset - %C(green)%an%Creset, %ar : %s"'
alias bu='brew update && brew upgrade && brew upgrade --cask && brew cleanup'
alias claude-dsp='claude --dangerously-skip-permissions'

# Start in tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# Zoxide
eval "$(zoxide init zsh)"
