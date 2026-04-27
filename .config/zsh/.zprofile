# Homebrew shellenv (path differs by arch — pick whichever exists)
if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv zsh)"
fi
