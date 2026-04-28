# Portable zsh dotfiles

This is a small, portable `oh-my-zsh` based setup meant to be synced to multiple servers.

## Layout

- `.zshrc`: main entrypoint
- `zsh/aliases.zsh`: aliases
- `zsh/exports.zsh`: environment variables
- `zsh/functions.zsh`: shell helpers
- `.gitignore`: excludes local-only files
- `bootstrap.sh`: installs prerequisites and then runs setup
- `bootstrap-offline.sh`: installs from local bundles without internet
- `check-offline-target.sh`: checks whether an offline target machine is ready
- `prepare-offline-packages.sh`: builds offline bundles on a machine with internet
- `prepare-zsh-offline-package.sh`: prepares distro-specific `zsh` offline assets
- `install-zsh-offline.sh`: builds and installs `zsh` from a local source archive
- `install.sh`: symlink installer for a new machine
- `packages/`: optional local bundles for offline setup

## Requirements

- `zsh`
- `oh-my-zsh`

This template uses the Dracula theme from the official repo and installs it to:

```bash
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/dracula
```

It also installs these oh-my-zsh custom plugins when missing:

```bash
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

## Usage

Clone this folder to `~/dotfiles` on the target server, then run:

```bash
./bootstrap.sh
```

Or if dependencies are already installed:

```bash
./install.sh
```

`bootstrap.sh` will:

- install `git` if missing
- install `zsh` if missing
- install `oh-my-zsh` if missing
- run `install.sh`

`install.sh` will:

- link your shared `zsh` config files
- install `oh-my-zsh` if it is missing
- auto-install the Dracula theme with `git clone` if it is missing
- auto-install `zsh-autosuggestions`
- auto-install `zsh-syntax-highlighting`
- keep the theme name as `dracula/dracula` so its bundled `lib/` files work correctly

## Offline Usage

To prepare the offline bundles on a machine with internet access:

```bash
./prepare-offline-packages.sh
```

That script will create `.tar.gz` bundles under `packages/` for:

- `oh-my-zsh`
- `dracula-zsh`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

To prepare offline `zsh` assets by target distro family:

```bash
./prepare-zsh-offline-package.sh debian
./prepare-zsh-offline-package.sh rhel
./prepare-zsh-offline-package.sh alpine
./prepare-zsh-offline-package.sh source
```

That script stores assets under [`packages/zsh/`](packages/zsh/README.md) and keeps a `zsh 5.9` source archive as a fallback.

`bootstrap-offline.sh` uses the source archive path automatically when `zsh` is missing. Distro-native packages under `packages/zsh/debian`, `packages/zsh/rhel`, or `packages/zsh/alpine` are prepared for manual install on matching target systems.

If the target server has no network access, put local bundles under [`packages/`](packages/README.md) and run:

```bash
./check-offline-target.sh
./bootstrap-offline.sh
```

`bootstrap-offline.sh` will:

- build and install `zsh 5.9` from the local source archive if `zsh` is missing
- install `oh-my-zsh` from a local bundle if needed
- install Dracula and the two plugins from local bundles
- run `install.sh` in offline mode

Supported offline bundle names:

- `oh-my-zsh`
- `dracula-zsh`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`

If you want to install `zsh` from the local source archive manually:

```bash
./install-zsh-offline.sh
```

If you want to verify the offline target machine first:

```bash
./check-offline-target.sh
```

Or create links manually:

```bash
ln -sf ~/dotfiles/.zshrc ~/.zshrc
mkdir -p ~/.config/zsh/custom
ln -sf ~/dotfiles/zsh/aliases.zsh ~/.config/zsh/custom/aliases.zsh
ln -sf ~/dotfiles/zsh/exports.zsh ~/.config/zsh/custom/exports.zsh
ln -sf ~/dotfiles/zsh/functions.zsh ~/.config/zsh/custom/functions.zsh
```

If you want to install Dracula manually:

```bash
git clone --depth=1 https://github.com/dracula/zsh.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/dracula
```

If you want to install the plugins manually:

```bash
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

## Notes

- Keep machine-specific values in `~/.zshrc.local` so they do not pollute the shared config.
- Put secrets, proxies, SSH-agent tweaks, and host-specific exports in `~/.zshrc.local`.
- Default theme is `dracula/dracula`.
- Default `DRACULA_TIME_FORMAT` is `%Y-%m-%d %H:%M:%S`.
- Default plugins are `git`, `sudo`, `colored-man-pages`, `zsh-autosuggestions`, and `zsh-syntax-highlighting`.
- If a command does not exist, this setup skips its init step.
- Offline mode supports extracted directories plus `.tar.gz`, `.tgz`, and `.tar` bundles.
- This repository may carry generated offline package contents under `packages/`; rerun the prepare scripts to refresh them.
- For offline `zsh` itself, prefer manually installing distro-native packages when the source and target OS families match; otherwise use the bundled `zsh 5.9` source archive with `bootstrap-offline.sh` or `install-zsh-offline.sh`.
- `check-offline-target.sh` verifies both local toolchain readiness and whether the required offline bundles are present.
- The prompt theme is separate from your terminal color scheme; for the full Dracula look, your terminal app should also use a Dracula color preset.
