#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_PACKAGE_DIR="${ZSH_PACKAGE_DIR:-$DOTFILES_DIR/packages/zsh}"
SOURCE_DIR="$ZSH_PACKAGE_DIR/source"
BUILD_DIR="${BUILD_DIR:-$DOTFILES_DIR/.build-zsh}"
PREFIX="${PREFIX:-$HOME/.local/zsh-5.9}"
TARGET_VERSION="${TARGET_VERSION:-5.9}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

version_ge() {
  local current="$1"
  local target="$2"
  [ "$(printf '%s\n%s\n' "$target" "$current" | sort -V | head -n1)" = "$target" ]
}

current_zsh_version() {
  if have_cmd zsh; then
    zsh --version | awk '{print $2}'
  fi
}

find_source_archive() {
  for archive in \
    "$SOURCE_DIR/zsh-${TARGET_VERSION}.tar.xz" \
    "$SOURCE_DIR/zsh-${TARGET_VERSION}.tar.gz" \
    "$SOURCE_DIR/zsh-${TARGET_VERSION}.tgz" \
    "$SOURCE_DIR/zsh-${TARGET_VERSION}.tar"
  do
    if [[ -f "$archive" ]]; then
      printf '%s\n' "$archive"
      return 0
    fi
  done

  return 1
}

extract_source() {
  local archive="$1"
  local dest="$2"

  rm -rf "$dest"
  mkdir -p "$dest"

  case "$archive" in
    *.tar.xz)
      tar -xJf "$archive" -C "$dest" --strip-components=1
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$archive" -C "$dest" --strip-components=1
      ;;
    *.tar)
      tar -xf "$archive" -C "$dest" --strip-components=1
      ;;
    *)
      echo "Unsupported source archive: $archive"
      exit 1
      ;;
  esac
}

require_cmd() {
  if ! have_cmd "$1"; then
    echo "Missing required build command: $1"
    exit 1
  fi
}

CURRENT_VERSION="$(current_zsh_version || true)"
if [[ -n "$CURRENT_VERSION" ]] && version_ge "$CURRENT_VERSION" "$TARGET_VERSION"; then
  echo "zsh $CURRENT_VERSION is already installed."
  echo "No offline build needed."
  exit 0
fi

ARCHIVE="$(find_source_archive || true)"
if [[ -z "$ARCHIVE" ]]; then
  echo "No zsh source archive found under $SOURCE_DIR"
  echo "Expected one of:"
  echo "  zsh-${TARGET_VERSION}.tar.xz"
  echo "  zsh-${TARGET_VERSION}.tar.gz"
  echo "  zsh-${TARGET_VERSION}.tgz"
  echo "  zsh-${TARGET_VERSION}.tar"
  exit 1
fi

require_cmd tar
require_cmd make
require_cmd awk
require_cmd sed
require_cmd install

if have_cmd gcc; then
  CC_BIN="gcc"
elif have_cmd cc; then
  CC_BIN="cc"
elif have_cmd clang; then
  CC_BIN="clang"
else
  echo "Missing C compiler. Need one of: gcc, cc, clang"
  exit 1
fi

SRC_BUILD_DIR="$BUILD_DIR/src"
extract_source "$ARCHIVE" "$SRC_BUILD_DIR"

cd "$SRC_BUILD_DIR"

chmod +x ./configure

CC="$CC_BIN" ./configure --prefix="$PREFIX"
make -j"${MAKE_JOBS:-2}"
make install

echo
echo "Installed zsh to $PREFIX"
echo "Binary path: $PREFIX/bin/zsh"
echo
echo "Add it to PATH in ~/.zshrc.local if needed:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""
echo
echo "If your system allows it, you can switch login shell with:"
echo "  chsh -s \"$PREFIX/bin/zsh\""
