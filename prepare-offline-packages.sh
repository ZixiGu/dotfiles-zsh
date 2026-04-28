#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-$DOTFILES_DIR/packages}"
WORK_DIR="${WORK_DIR:-$DOTFILES_DIR/.build-offline}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! have_cmd "$1"; then
    echo "Missing required command: $1"
    exit 1
  fi
}

fetch_repo_archive() {
  local url="$1"
  local out_name="$2"
  local tmp_dir="$WORK_DIR/$out_name"
  local archive_path="$PACKAGES_DIR/$out_name.tar.gz"

  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"

  git clone --depth=1 "$url" "$tmp_dir/repo"
  tar -czf "$archive_path" -C "$tmp_dir/repo" .

  echo "Prepared $archive_path"
}

require_cmd git
require_cmd tar

mkdir -p "$PACKAGES_DIR"
mkdir -p "$WORK_DIR"

fetch_repo_archive "https://github.com/ohmyzsh/ohmyzsh" "oh-my-zsh"
fetch_repo_archive "https://github.com/dracula/zsh.git" "dracula-zsh"
fetch_repo_archive "https://github.com/zsh-users/zsh-autosuggestions" "zsh-autosuggestions"
fetch_repo_archive "https://github.com/zsh-users/zsh-syntax-highlighting.git" "zsh-syntax-highlighting"

echo
echo "Offline packages are ready in: $PACKAGES_DIR"
echo "Copy the whole packages directory to the offline machine, then run:"
echo "  ./bootstrap-offline.sh"
