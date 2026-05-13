#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BUNDLE_DIR="${LOCAL_BUNDLE_DIR:-$DOTFILES_DIR/packages}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

if [[ ! -d "$LOCAL_BUNDLE_DIR" ]]; then
  echo "Local package directory not found: $LOCAL_BUNDLE_DIR"
  echo "Put the offline bundles under that directory and rerun."
  exit 1
fi

if ! have_cmd zsh; then
  bash "$DOTFILES_DIR/install-zsh-offline.sh"
  export PATH="$HOME/.local/zsh-5.9/bin:$PATH"
fi

if ! have_cmd zsh; then
  echo "zsh is still not available after offline install."
  exit 1
fi

OFFLINE=1 LOCAL_BUNDLE_DIR="$LOCAL_BUNDLE_DIR" bash "$DOTFILES_DIR/install.sh"

echo
echo "Offline bootstrap complete."
echo "If needed, set zsh as your login shell with:"
echo "  chsh -s \"$(command -v zsh)\""
echo "Then restart the terminal or run:"
echo "  exec zsh"
