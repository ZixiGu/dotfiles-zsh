# Shared zsh config with oh-my-zsh

export ZDOTDIR="${ZDOTDIR:-$HOME}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ZSH_CUSTOM_DIR="$XDG_CONFIG_HOME/zsh/custom"
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

setopt AUTO_CD
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

ZSH_THEME="${ZSH_THEME:-dracula/dracula}"
plugins=(
  git
  sudo
  colored-man-pages
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Load shared environment first so oh-my-zsh sees the final PATH.
for file in \
  "$ZSH_CUSTOM_DIR/exports.zsh" \
  "$ZSH_CUSTOM_DIR/aliases.zsh" \
  "$ZSH_CUSTOM_DIR/functions.zsh"
do
  [[ -f "$file" ]] && source "$file"
done

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  autoload -Uz compinit
  compinit
fi

# Common tool inits, guarded so migration stays portable.
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Keep machine-only overrides out of the shared repo.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
