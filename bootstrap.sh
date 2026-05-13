#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_pkg() {
  if have_cmd apt-get; then
    sudo apt-get update
    sudo apt-get install -y "$@"
    return
  fi

  if have_cmd dnf; then
    sudo dnf install -y "$@"
    return
  fi

  if have_cmd yum; then
    sudo yum install -y "$@"
    return
  fi

  if have_cmd pacman; then
    sudo pacman -Sy --noconfirm "$@"
    return
  fi

  if have_cmd brew; then
    brew install "$@"
    return
  fi

  echo "No supported package manager found. Please install manually: $*"
  return 1
}

if ! have_cmd git; then
  install_pkg git
fi

if ! have_cmd zsh; then
  install_pkg zsh
fi

if [[ ! -d "${ZSH:-$HOME/.oh-my-zsh}" ]]; then
  if have_cmd curl; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  elif have_cmd wget; then
    RUNZSH=no CHSH=no sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "Need curl or wget to install oh-my-zsh automatically."
    exit 1
  fi
fi

bash "$DOTFILES_DIR/install.sh"

echo
echo "Bootstrap complete."
echo "If needed, set zsh as your login shell with:"
echo "  chsh -s \"$(command -v zsh)\""
echo "Then restart the terminal or run:"
echo "  exec zsh"
