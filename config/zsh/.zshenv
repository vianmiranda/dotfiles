export ZDOTDIR="$HOME/.config/zsh"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export EDITOR=/usr/bin/vim
export TMUX_AGENT_INDICATOR_DIR="$XDG_DATA_HOME/tmux/plugins/tmux-agent-indicator"
export PATH="$HOME/.local/bin:$PATH"
# Terminal.app's session restore writes to $ZDOTDIR/.zsh_sessions (hard-coded,
# not relocatable), which would land inside the dotfiles repo.
export SHELL_SESSIONS_DISABLE=1
