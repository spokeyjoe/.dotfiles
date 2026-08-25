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
   tarball fallback); neovim >= 0.12 via the official prebuilt tarball on
   Linux (`~/.local/opt`), brew on macOS; `tree-sitter` CLI >= 0.26.1
   (needed by nvim-treesitter's main branch) via the official prebuilt
   binary, or `cargo install` with a user-local rustup toolchain on
   glibc < 2.39 systems (e.g. Ubuntu 22.04)
3. `stow` every package into `$HOME` (pre-existing conflicting files are
   backed up to `~/.dotfiles-backup/<timestamp>/`)
4. Install TPM and all tmux plugins, headlessly
5. Install fisher and the fish plugins listed in `fish_plugins`
   (tide, fzf.fish, autopair, z, fish-lf-icons)
6. Migrate the tide prompt theme via `fish/.config/fish/tide_vars.fish`
7. Add a guarded `exec fish` block to `~/.bashrc` so interactive logins land
   in fish (no sudo / no `chsh`)
8. Headless `nvim +Lazy! sync` (best effort)

The script is defensive where it counts: network operations retry, tools are
verified by actually running them (not just presence on PATH), broken
brewed-perl stow bottles fall back to the GNU tarball, and brewed-glibc
locale/CA quirks are worked around automatically.

## Proxy note (Loon / ALPN)

Some proxies (observed with Loon on iOS) kill curl's default TLS ClientHello
— the connection dies with `SSL routines::unexpected eof` before any data
flows, while GnuTLS-based tools (git, wget) pass. Disabling ALPN fixes it.
The stowed `curl/.curlrc` sets `no-alpn` for the curl CLI, and the bootstrap
points brew at an equivalent curlrc via `HOMEBREW_CURLRC` (fish config does
the same for interactive use). If this affects you, the real fix is on the
proxy side (check Loon's MITM list / node for `*.github.com`,
`*.githubusercontent.com`, `pypi.org`).

### Overrides

| Variable         | Default                                            | Purpose                     |
| ---------------- | -------------------------------------------------- | --------------------------- |
| `DOTFILES_DIR`   | `~/.dotfiles`                                      | repo location               |
| `STOW_PACKAGES`  | `fish tmux nvim lazygit clang-format kitty curl pi` | packages to stow          |
| `BREW_PACKAGES`  | `fish tmux stow neovim fzf`                        | formulas to install         |
| `TIDE_FORCE=1`   | —                                                  | re-apply tide config        |
| `SKIP_*=1`       | —                                                  | `BREW`/`STOW`/`TMUX`/`FISH_PLUGINS`/`DEFAULT_SHELL`/`NVIM_SYNC` |

## Syncing across machines

Git is the only sync channel — never rsync/cp the repo directory itself:
machine-specific state (`fish_variables`, `conf.d/*`, most of `functions/*`)
is gitignored on purpose, and copying the directory leaks it onto other
machines (stow will then happily symlink it into `$HOME`).

To propagate changes:

```bash
# on the machine where you changed something:
git -C ~/.dotfiles add -A && git -C ~/.dotfiles commit -m "..." && git -C ~/.dotfiles push

# on the other machines (re-stows + installs anything new, idempotently):
git -C ~/.dotfiles pull && ~/.dotfiles/bootstrap.sh
```

For pushing from servers without a GitHub key, either add the machine's key
to GitHub, or ssh in with agent forwarding (`ssh -A`) and use the SSH remote:
`git -C ~/.dotfiles remote set-url origin git@github.com:spokeyjoe/.dotfiles.git`

## Tide prompt config

The tide theme is stored as universal variables, so it lives in the
machine-specific `fish_variables` (gitignored). The tracked snapshot is
`fish/.config/fish/tide_vars.fish`, applied by the bootstrap.

NB: tide resets all its variables to defaults whenever it is freshly
(re)installed by fisher — the bootstrap detects that and re-applies the
snapshot automatically.

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
