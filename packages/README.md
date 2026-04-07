# Offline packages

Put offline bundles here if the target server cannot access the network.

Supported inputs for each component:

- extracted directory
- `.tar.gz`
- `.tgz`
- `.tar`

Expected names:

- `oh-my-zsh`
- `dracula-zsh`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

Examples:

```bash
packages/
  oh-my-zsh.tar.gz
  dracula-zsh.tar.gz
  zsh-autosuggestions.tar.gz
  zsh-syntax-highlighting.tar.gz
```

or:

```bash
packages/
  oh-my-zsh/
  dracula-zsh/
  zsh-autosuggestions/
  zsh-syntax-highlighting/
```

Suggested source repositories:

- `https://github.com/ohmyzsh/ohmyzsh`
- `https://github.com/dracula/zsh`
- `https://github.com/zsh-users/zsh-autosuggestions`
- `https://github.com/zsh-users/zsh-syntax-highlighting`
