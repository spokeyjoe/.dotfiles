# Joe's Dotfiles

upon zpy's request

## Bootstrap a fresh machine

One-liner (no sudo required; make sure network/proxy is configured first):

```bash
git clone https://github.com/spokeyjoe/.dotfiles.git ~/.dotfiles
~/.dotfiles/bootstrap.sh
```

The script is idempotent — anything already installed is skipped, so it is
safe to re-run. It will:

1. Find Homebrew, or install it to `~/.linuxbrew` (plain `git clone`, no sudo)
2. Install CLI tools: `fish tmux fzf` via brew; GNU stow via brew (GNU
   tarball fallback); neovim via the official prebuilt tarball on Linux
   (`~/.local/opt`), brew on macOS
3. `stow` every package into `$HOME` (pre-existing conflicting files are
   backed up to `~/.dotfiles-backup/<timestamp>/`)
4. Install TPM and all tmux plugins, headlessly
5. Install fisher and the fish plugins listed in `fish_plugins`
   (tide, fzf.fish, autopair, z, fish-lf-icons)
6. Migrate the tide prompt theme via `fish/.config/fish/tide_vars.fish`
7. Add a guarded `exec fish` block to `~/.bashrc` so interactive logins land
   in fish (no sudo / no `chsh`)
8. Headless `nvim +Lazy! sync` (best effort)

The script is defensive about weird environments: downloads retry and fall
back from `curl` to `wget` (useful behind proxies that kill OpenSSL
handshakes), broken brewed-perl stow bottles are detected via functional
checks, and a brewed-glibc locale/locpath quirk is worked around.

### Overrides

| Variable         | Default                                            | Purpose                     |
| ---------------- | -------------------------------------------------- | --------------------------- |
| `DOTFILES_DIR`   | `~/.dotfiles`                                      | repo location               |
| `STOW_PACKAGES`  | `fish tmux nvim lazygit clang-format kitty`        | packages to stow            |
| `BREW_PACKAGES`  | `fish tmux stow neovim fzf`                        | formulas to install         |
| `TIDE_FORCE=1`   | —                                                  | re-apply tide config        |
| `SKIP_*=1`       | —                                                  | `BREW`/`STOW`/`TMUX`/`FISH_PLUGINS`/`DEFAULT_SHELL`/`NVIM_SYNC` |

## Tide prompt config

The tide theme is stored as universal variables, so it lives in the
machine-specific `fish_variables` (gitignored). The tracked snapshot is
`fish/.config/fish/tide_vars.fish`, applied once by the bootstrap.

After tweaking the prompt interactively, regenerate the snapshot:

```bash
fish ~/.dotfiles/scripts/dump-tide.fish > ~/.dotfiles/fish/.config/fish/tide_vars.fish
```

## Default shell

The bootstrap appends a guarded block to `~/.bashrc` that `exec`s fish for
interactive shells — no sudo or `chsh` needed:

- plain bash when you need it: `bash --norc`
- skip fish for one ssh session: `NO_FISH=1 ssh <host>`

(The tmux config also auto-detects fish, so `tm` gives you fish either way.)
If you'd rather do it the classic way and have sudo:

```bash
echo "$HOME/.linuxbrew/bin/fish" | sudo tee -a /etc/shells
chsh -s "$HOME/.linuxbrew/bin/fish"
```
