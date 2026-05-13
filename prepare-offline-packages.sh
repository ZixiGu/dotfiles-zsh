#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-$DOTFILES_DIR/packages}"
WORK_DIR="${WORK_DIR:-$HOME/.build-offline}"

REFRESH=0
if [[ "${1:-}" == "--refresh" ]]; then
  REFRESH=1
fi

BUNDLES=(
  "oh-my-zsh|https://github.com/ohmyzsh/ohmyzsh"
  "dracula-zsh|https://github.com/dracula/zsh.git"
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

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

check_bundle_exists() {
  local name="$1"
  [[ -d "$PACKAGES_DIR/$name" ]] || [[ -f "$PACKAGES_DIR/$name.tar.gz" ]] || [[ -f "$PACKAGES_DIR/$name.tar" ]]
}

if [[ "$REFRESH" -eq 0 ]]; then
  all_ok=1
  for entry in "${BUNDLES[@]}"; do
    name="${entry%%|*}"
    if ! check_bundle_exists "$name"; then
      all_ok=0
      break
    fi
  done

  if [[ "$all_ok" -eq 1 ]]; then
    echo "All offline bundles already exist under $PACKAGES_DIR"
    echo "Run with --refresh to re-download from network."
    exit 0
  fi
fi

echo "This script requires internet access to download packages from GitHub."
echo

require_cmd git
require_cmd tar

mkdir -p "$PACKAGES_DIR"
mkdir -p "$WORK_DIR"

for entry in "${BUNDLES[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  fetch_repo_archive "$url" "$name"
done

echo
echo "Offline packages are ready in: $PACKAGES_DIR"
echo "Copy the whole packages directory to the offline machine, then run:"
echo "  ./bootstrap-offline.sh"
