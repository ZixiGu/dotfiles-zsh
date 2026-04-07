export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"

# Prefer user-local binaries across servers.
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"

case "$(uname -s)" in
  Darwin)
    export PATH="/opt/homebrew/bin:$PATH"
    ;;
  Linux)
    export PATH="/usr/local/bin:$PATH"
    ;;
esac
