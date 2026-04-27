#!/bin/sh
set -eu

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

# Brew formulae required by these dotfiles
FORMULAE="git tmux fzf sesh zoxide zimfw"

if command -v brew >/dev/null 2>&1; then
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
link .config/zsh/.zshenv "$HOME/.zshenv"

# .config directories
link .config/git     "$HOME/.config/git"
link .config/ghostty "$HOME/.config/ghostty"
link .config/tmux    "$HOME/.config/tmux"
link .config/vim     "$HOME/.config/vim"
link .config/zsh     "$HOME/.config/zsh"

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

# TPM (tmux plugin manager) — installed under $XDG_DATA_HOME so plugins
# don't land inside the dotfiles repo.
TPM_DIR="$XDG_DATA_HOME/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    printf 'installed TPM - run prefix + I inside tmux to install plugins\n'
fi

