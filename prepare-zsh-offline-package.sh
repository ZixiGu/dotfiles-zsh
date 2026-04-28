#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="${PACKAGES_DIR:-$DOTFILES_DIR/packages/zsh}"
TARGET_FAMILY="${1:-source}"
ZSH_VERSION="${ZSH_VERSION:-5.9}"
ZSH_SOURCE_URL="https://www.zsh.org/pub/zsh-${ZSH_VERSION}.tar.xz"
SOURCE_OUT="$PACKAGES_DIR/source/zsh-${ZSH_VERSION}.tar.xz"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if ! have_cmd "$1"; then
    echo "Missing required command: $1"
    exit 1
  fi
}

download_file() {
  local url="$1"
  local out="$2"

  mkdir -p "$(dirname "$out")"

  if have_cmd curl; then
    curl -fL "$url" -o "$out"
    return 0
  fi

  if have_cmd wget; then
    wget -O "$out" "$url"
    return 0
  fi

  echo "Need curl or wget to download $url"
  exit 1
}

prepare_source() {
  echo "Preparing zsh ${ZSH_VERSION} source bundle"
  download_file "$ZSH_SOURCE_URL" "$SOURCE_OUT"
  echo "Prepared $SOURCE_OUT"
}

prepare_debian() {
  require_cmd apt-get
  require_cmd apt-cache

  local out_dir="$PACKAGES_DIR/debian"
  mkdir -p "$out_dir"

  echo "Preparing Debian/Ubuntu offline zsh package set"
  echo "Using apt to download binary packages into $out_dir"

  (
    cd "$out_dir"
    apt-get download zsh zsh-common libcap2 libtinfo6 libncursesw6 libc6
  )

  prepare_source

  echo "Prepared Debian/Ubuntu packages under $out_dir"
  echo "Review dependencies for your target release before shipping."
}

prepare_rhel() {
  local out_dir="$PACKAGES_DIR/rhel"
  mkdir -p "$out_dir"

  echo "Preparing RHEL/Rocky/CentOS offline zsh package set"

  if have_cmd dnf; then
    dnf download --destdir "$out_dir" zsh ncurses-libs glibc pcre2
  elif have_cmd yumdownloader; then
    yumdownloader --destdir "$out_dir" zsh ncurses-libs glibc pcre2
  else
    echo "Need dnf with the download plugin or yumdownloader."
    echo "Falling back to source bundle only."
  fi

  prepare_source

  echo "Prepared RHEL-family packages under $out_dir"
  echo "Review dependencies for your target release before shipping."
}

prepare_alpine() {
  local out_dir="$PACKAGES_DIR/alpine"
  mkdir -p "$out_dir"

  echo "Preparing Alpine offline zsh package set"

  if have_cmd apk; then
    apk fetch --output "$out_dir" zsh ncurses-libs musl
  else
    echo "apk not found. Falling back to source bundle only."
  fi

  prepare_source

  echo "Prepared Alpine packages under $out_dir"
}

case "$TARGET_FAMILY" in
  source)
    prepare_source
    ;;
  debian|ubuntu)
    prepare_debian
    ;;
  rhel|rocky|centos)
    prepare_rhel
    ;;
  alpine)
    prepare_alpine
    ;;
  *)
    echo "Unsupported target family: $TARGET_FAMILY"
    echo "Supported values: source, debian, ubuntu, rhel, rocky, centos, alpine"
    exit 1
    ;;
esac

echo
echo "zsh offline package preparation complete."
echo "Output directory: $PACKAGES_DIR"
