#!/bin/sh
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Safe to re-run at any time: links and dirs are idempotent, and everything
# installed here (formulae, TPM, tmux/vim/zim plugins) is upgraded to latest.

# Brew formulae required by these dotfiles
FORMULAE="git tmux fzf sesh zoxide zimfw"

if command -v brew >/dev/null 2>&1; then
    # brew install also upgrades formulae that are already installed but
    # outdated (unless HOMEBREW_NO_INSTALL_UPGRADE is set).
    # shellcheck disable=SC2086
    brew install $FORMULAE
else
    printf 'warning: brew not found, skipping formula installs: %s\n' "$FORMULAE" >&2
fi

# Symlink $1 (relative to $DOTFILES) to $2 (absolute target).
# - Idempotent: no-op when $2 already points to $1
# - Safe: refuses to clobber existing .bak; uses timestamped suffix
# - Validates $1 exists before creating the link
link() {
    src="$DOTFILES/$1"
    dst="$2"

    if [ ! -e "$src" ] && [ ! -L "$src" ]; then
        printf 'error: source missing: %s\n' "$src" >&2
        return 1
    fi

    mkdir -p "$(dirname "$dst")"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        return 0
    fi

    if [ ! -L "$dst" ] && [ -e "$dst" ]; then
        bak="$dst.$(date +%Y%m%d-%H%M%S).bak"
        mv "$dst" "$bak"
        printf 'backed up %s -> %s\n' "$dst" "$bak"
    fi

    ln -sfn "$src" "$dst"
    printf 'linked %s -> %s\n' "$dst" "$src"
}

# Top-level files
# .zshenv lives inside $ZDOTDIR so every zsh re-reads it; ~/.zshenv is just a
# bootstrap pointer for the first shell where ZDOTDIR isn't set yet.
link config/zsh/.zshenv "$HOME/.zshenv"
link .ideavimrc          "$HOME/.ideavimrc"

# config directories -> ~/.config
link config/git     "$HOME/.config/git"
link config/ghostty "$HOME/.config/ghostty"
link config/tmux    "$HOME/.config/tmux"
link config/vim     "$HOME/.config/vim"
link config/zsh     "$HOME/.config/zsh"

# >>> BEGIN claudeteam >>>
# Opt-in agent-teams config for Claude Code.
# Deliberately NOT ~/.claude: that is Claude Code's own config dir and holds
# sessions, projects, history and a machine-managed settings.json. Nothing
# here is auto-discovered - every file is reached by an explicit path from
# the claudeteam() function in .zshrc, so it can live under XDG.
link config/claude "$HOME/.config/claude"
# <<< END claudeteam <<<

# Runtime data dirs — kept out of the dotfiles tree so they don't pollute
# the symlinked $ZDOTDIR / $XDG_CONFIG_HOME paths.
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p \
    "$XDG_DATA_HOME/zsh" \
    "$XDG_CACHE_HOME/zsh/completions" \
    "$XDG_DATA_HOME/zim" \
    "$XDG_DATA_HOME/tmux/plugins" \
    "$XDG_DATA_HOME/vim/backup" \
    "$XDG_DATA_HOME/vim/swap" \
    "$XDG_DATA_HOME/vim/undo"

# Clone $1 into $2, or fast-forward it if it's already there.
# --ff-only so local edits to a plugin surface as a warning instead of a merge.
sync() {
    if [ -d "$2/.git" ]; then
        printf '==> %s\n' "$2"
        git -C "$2" pull --ff-only || printf 'warning: could not fast-forward %s\n' "$2" >&2
    else
        git clone "$1" "$2"
    fi
}

# Plugins live under $XDG_DATA_HOME, not in the repo; the repo only holds
# config. Versions float: every run pulls upstream HEAD.

# TPM (tmux plugin manager). tmux.conf points TMUX_PLUGIN_MANAGER_PATH here.
TPM_DIR="$XDG_DATA_HOME/tmux/plugins/tpm"
sync https://github.com/tmux-plugins/tpm "$TPM_DIR"

# TPM's scripts talk to a running tmux server, so they only work inside tmux.
if [ -n "${TMUX:-}" ]; then
    "$TPM_DIR/bin/install_plugins"
    "$TPM_DIR/bin/update_plugins" all
else
    printf 'skipped tmux plugins: rerun inside tmux, or use prefix + I / prefix + U\n' >&2
fi

# Vim plugins (native packages). vimrc prepends $XDG_DATA_HOME/vim to packpath.
# Add a plugin: one sync line, into pack/<group>/start/<name>.
VIM_PACK="$XDG_DATA_HOME/vim/pack"
sync https://github.com/airblade/vim-gitgutter "$VIM_PACK/git/start/vim-gitgutter"

# zim modules. zimfw is a function defined by zim's init.zsh, so it needs an
# interactive zsh (which also installs any modules newly added to .zimrc).
zsh -ic 'zimfw update' || printf 'warning: zimfw update failed\n' >&2

