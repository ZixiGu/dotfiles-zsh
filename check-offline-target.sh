#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BUNDLE_DIR="${LOCAL_BUNDLE_DIR:-$DOTFILES_DIR/packages}"
ZSH_SOURCE_DIR="${ZSH_SOURCE_DIR:-$LOCAL_BUNDLE_DIR/zsh/source}"
TARGET_VERSION="${TARGET_VERSION:-5.9}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

print_result() {
  local status="$1"
  local label="$2"
  local detail="${3:-}"
  printf '[%s] %s' "$status" "$label"
  if [[ -n "$detail" ]]; then
    printf ' - %s' "$detail"
  fi
  printf '\n'
}

check_source_archive() {
  local found=""
  for archive in \
    "$ZSH_SOURCE_DIR/zsh-${TARGET_VERSION}.tar.xz" \
    "$ZSH_SOURCE_DIR/zsh-${TARGET_VERSION}.tar.gz" \
    "$ZSH_SOURCE_DIR/zsh-${TARGET_VERSION}.tgz" \
    "$ZSH_SOURCE_DIR/zsh-${TARGET_VERSION}.tar"
  do
    if [[ -f "$archive" ]]; then
      found="$archive"
      break
    fi
  done

  if [[ -n "$found" ]]; then
    print_result "OK" "zsh source archive" "$found"
  else
    print_result "MISS" "zsh source archive" "expected under $ZSH_SOURCE_DIR"
  fi
}

check_plugin_bundle() {
  local name="$1"
  if [[ -d "$LOCAL_BUNDLE_DIR/$name" ]] || [[ -f "$LOCAL_BUNDLE_DIR/$name.tar.gz" ]] || [[ -f "$LOCAL_BUNDLE_DIR/$name.tgz" ]] || [[ -f "$LOCAL_BUNDLE_DIR/$name.tar" ]]; then
    print_result "OK" "$name bundle"
  else
    print_result "MISS" "$name bundle" "expected under $LOCAL_BUNDLE_DIR"
  fi
}

echo "Offline target readiness check"
echo "Workspace: $DOTFILES_DIR"
echo

if have_cmd zsh; then
  print_result "OK" "zsh" "$(zsh --version)"
else
  print_result "WARN" "zsh" "not installed; offline source build will be needed"
fi

if have_cmd gcc; then
  print_result "OK" "C compiler" "gcc"
elif have_cmd cc; then
  print_result "OK" "C compiler" "cc"
elif have_cmd clang; then
  print_result "OK" "C compiler" "clang"
else
  print_result "MISS" "C compiler" "need gcc, cc, or clang for source build"
fi

for cmd in tar make awk sed install; do
  if have_cmd "$cmd"; then
    print_result "OK" "$cmd"
  else
    print_result "MISS" "$cmd"
  fi
done

if have_cmd chsh; then
  print_result "OK" "chsh" "login shell can likely be switched"
else
  print_result "WARN" "chsh" "you may need to change the login shell manually"
fi

echo
echo "Bundle check"
check_source_archive
check_plugin_bundle "oh-my-zsh"
check_plugin_bundle "dracula-zsh"
check_plugin_bundle "zsh-autosuggestions"
check_plugin_bundle "zsh-syntax-highlighting"

echo
echo "Suggested next step:"
echo "  ./bootstrap-offline.sh"
