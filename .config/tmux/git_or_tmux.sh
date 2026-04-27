#!/usr/bin/env zsh
# Status-bar indicator: current git branch if the active pane's $PWD is in a
# git repo, else the literal string "tmux".
set -euo pipefail

pane_path=$(tmux display-message -p -F '#{pane_current_path}' 2>/dev/null || true)
cd "${pane_path:-$HOME}" 2>/dev/null || cd "$HOME"

if branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
  printf '%s' "$branch"
elif sha=$(git rev-parse --short HEAD 2>/dev/null); then
  printf '%s' "$sha"
else
  printf 'tmux'
fi
