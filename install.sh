#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
CUSTOM_DIR="$CONFIG_DIR/custom"
ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
OHMY_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
DRACULA_DIR="$OHMY_CUSTOM_DIR/themes/dracula"
DRACULA_REPO="https://github.com/dracula/zsh.git"
PLUGIN_DIR="$OHMY_CUSTOM_DIR/plugins"
AUTOSUGGESTIONS_DIR="$PLUGIN_DIR/zsh-autosuggestions"
AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions"
SYNTAX_HIGHLIGHTING_DIR="$PLUGIN_DIR/zsh-syntax-highlighting"
SYNTAX_HIGHLIGHTING_REPO="https://github.com/zsh-users/zsh-syntax-highlighting.git"
OFFLINE="${OFFLINE:-0}"
LOCAL_BUNDLE_DIR="${LOCAL_BUNDLE_DIR:-$DOTFILES_DIR/packages}"

mkdir -p "$CUSTOM_DIR"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

extract_archive() {
  local archive_path="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  case "$archive_path" in
    *.tar.gz|*.tgz)
      tar -xzf "$archive_path" -C "$dest_dir" --strip-components=1
      ;;
    *.tar)
      tar -xf "$archive_path" -C "$dest_dir" --strip-components=1
      ;;
    *)
      echo "Unsupported archive format: $archive_path"
      return 1
      ;;
  esac
}

is_nonempty_dir() {
  local dir="$1"
  [[ -d "$dir" ]] && [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]
}

install_from_bundle_or_git() {
  local label="$1"
  local bundle_name="$2"
  local repo_url="$3"
  local dest_dir="$4"

  if is_nonempty_dir "$dest_dir"; then
    return 0
  fi

  if [[ -e "$dest_dir" && ! -d "$dest_dir" ]]; then
    echo "Cannot install $label: target exists and is not a directory: $dest_dir"
    return 1
  fi

  if [[ -d "$LOCAL_BUNDLE_DIR/$bundle_name" ]]; then
    mkdir -p "$dest_dir"
    cp -R "$LOCAL_BUNDLE_DIR/$bundle_name"/. "$dest_dir"/
    echo "Installed $label from local directory bundle"
    return 0
  fi

  for archive in \
    "$LOCAL_BUNDLE_DIR/$bundle_name.tar.gz" \
    "$LOCAL_BUNDLE_DIR/$bundle_name.tgz" \
    "$LOCAL_BUNDLE_DIR/$bundle_name.tar"
  do
    if [[ -f "$archive" ]]; then
      mkdir -p "$(dirname "$dest_dir")"
      extract_archive "$archive" "$dest_dir"
      echo "Installed $label from local archive bundle"
      return 0
    fi
  done

  if [[ "$OFFLINE" = "1" ]]; then
    echo "Missing offline bundle for $label under $LOCAL_BUNDLE_DIR"
    return 1
  fi

  if have_cmd git; then
    mkdir -p "$(dirname "$dest_dir")"
    git clone --depth=1 "$repo_url" "$dest_dir"
    echo "Installed $label from network"
    return 0
  fi

  echo "git not found, cannot install $label automatically"
  echo "Provide a local bundle under $LOCAL_BUNDLE_DIR or clone manually:"
  echo "  git clone $repo_url $dest_dir"
  return 1
}

if [[ ! -d "$ZSH_DIR" || ! -f "$ZSH_DIR/oh-my-zsh.sh" ]]; then
  install_from_bundle_or_git "oh-my-zsh" "oh-my-zsh" "https://github.com/ohmyzsh/ohmyzsh" "$ZSH_DIR"
fi

mkdir -p "$OHMY_CUSTOM_DIR/themes"
mkdir -p "$PLUGIN_DIR"

install_from_bundle_or_git "Dracula theme" "dracula-zsh" "$DRACULA_REPO" "$DRACULA_DIR"

install_from_bundle_or_git "zsh-autosuggestions" "zsh-autosuggestions" "$AUTOSUGGESTIONS_REPO" "$AUTOSUGGESTIONS_DIR"

install_from_bundle_or_git "zsh-syntax-highlighting" "zsh-syntax-highlighting" "$SYNTAX_HIGHLIGHTING_REPO" "$SYNTAX_HIGHLIGHTING_DIR"

ln -snf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -snf "$DOTFILES_DIR/zsh/aliases.zsh" "$CUSTOM_DIR/aliases.zsh"
ln -snf "$DOTFILES_DIR/zsh/exports.zsh" "$CUSTOM_DIR/exports.zsh"
ln -snf "$DOTFILES_DIR/zsh/functions.zsh" "$CUSTOM_DIR/functions.zsh"

echo "Installed zsh dotfiles from $DOTFILES_DIR"
