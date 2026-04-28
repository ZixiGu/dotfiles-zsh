# Offline zsh packages

This directory is for offline `zsh` installation assets.

## Recommended strategy

Use a distro-native package when the target system matches your source machine family.

- Debian/Ubuntu: download `.deb` packages
- RHEL/Rocky/CentOS: download `.rpm` packages
- Alpine: download `.apk` packages

Also keep a `zsh 5.9` source archive here as a fallback.

## Prepare packages

Run on a machine with internet access:

```bash
./prepare-zsh-offline-package.sh debian
./prepare-zsh-offline-package.sh rhel
./prepare-zsh-offline-package.sh alpine
./prepare-zsh-offline-package.sh source
```

The default version target is `5.9`.

You can override it:

```bash
ZSH_VERSION=5.9 ./prepare-zsh-offline-package.sh source
```

## Layout

Examples:

```bash
packages/zsh/
  source/
    zsh-5.9.tar
    zsh-5.9.tar.xz
  debian/
    zsh_*.deb
    zsh-common_*.deb
  rhel/
    zsh-*.rpm
  alpine/
    zsh-*.apk
```

## Install notes

- Native packages are preferred because they integrate with the system package database.
- The exact dependency set can vary by target release.
- If native packages do not match the target OS release, use the `source/` archive and build `zsh 5.9` locally.
- The repo includes [`install-zsh-offline.sh`](../../install-zsh-offline.sh), which builds from the local source archive into `~/.local/zsh-5.9` by default.
- `bootstrap-offline.sh` calls that source-build path automatically when `zsh` is missing. Native `.deb`, `.rpm`, and `.apk` assets are for manual install on matching target systems.
