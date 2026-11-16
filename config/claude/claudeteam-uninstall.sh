#!/usr/bin/env bash
# Reverts the claudeteam setup completely (symlink, shell block, repo files).
# Everything it touches in the dotfiles repo is git-tracked, so `git checkout`
# undoes this script itself.
set -uo pipefail

# Repo root, resolved through the ~/.config/claude symlink (script is config/claude/*).
D="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
Z="$D/config/zsh/.zshrc"
I="$D/install.sh"
T="$HOME/.config/claude"

echo "1. Removing symlink $T"
if [ -L "$T" ]; then rm -f "$T" && echo "   unlinked"; else echo "   not a symlink, skipping"; fi

echo "2. Removing claudeteam block from .zshrc"
if grep -q 'BEGIN claudeteam' "$Z" 2>/dev/null; then
  perl -0pi -e 's/\n# >>> BEGIN claudeteam >>>.*?# <<< END claudeteam <<<\n//s' "$Z"
  echo "   removed"
else
  echo "   not present, skipping"
fi

echo "3. Removing link line from install.sh"
if grep -q 'BEGIN claudeteam' "$I" 2>/dev/null; then
  perl -0pi -e 's/\n# >>> BEGIN claudeteam >>>.*?# <<< END claudeteam <<<\n//s' "$I"
  echo "   removed"
else
  echo "   not present, skipping"
fi

echo "4. Removing repo files"
rm -rf "$D/config/claude"

echo
echo "Done. ~/.claude and its managed settings.json were never touched."
echo "Review:  git -C $D status --short && git -C $D diff"
echo "Undo the uninstall entirely:  git -C $D checkout . "
