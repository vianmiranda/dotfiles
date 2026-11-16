#!/usr/bin/env bash
# Installed by claudeteam setup. Remove with ~/.config/claude/claudeteam-uninstall.sh
set -euo pipefail

# Not a tmux pane -> not a tmux teammate. Emit nothing, exit clean.
[ -n "${TMUX_PANE:-}" ] || exit 0

name=$(tmux display-message -p -t "${TMUX_PANE}" '#{pane_title}' 2>/dev/null || true)

# The leader's own pane is titled "team-lead" (var ry="team-lead" in the bundle).
case "$name" in
  ""|"team-lead") exit 0 ;;
esac

ctx="${HOME}/.config/claude/team-context/${name}.md"
[ -f "$ctx" ] || exit 0

jq -n --arg c "$(cat "$ctx")" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
