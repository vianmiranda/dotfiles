#!/usr/bin/env zsh
# Rename a just-created session so unnamed (default-numeric) sessions
# use the lowest available integer >= 1. User-named sessions are left alone.
set -euo pipefail

session_name="${1:-}"
[[ -n "$session_name" ]] || exit 0
[[ "$session_name" =~ ^[0-9]+$ ]] || exit 0

existing=()
while IFS= read -r line; do existing+=("$line"); done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -E '^[0-9]+$' | sort -n)

n=1
for s in "${existing[@]}"; do
  if [[ "$s" == "$n" ]]; then
    n=$((n + 1))
  elif (( s > n )); then
    break
  fi
done

[[ "$session_name" == "$n" ]] || tmux rename-session -t "$session_name" "$n"
