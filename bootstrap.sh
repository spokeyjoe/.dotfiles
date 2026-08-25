#!/usr/bin/env bash
#
# bootstrap.sh — set up Joe's dotfiles environment on a fresh machine.
#
#   * No sudo required: CLI tools come from a user-local Homebrew
#     (~/.linuxbrew on Linux); neovim uses the official prebuilt tarball.
#   * Idempotent: anything already installed/working is skipped.
#   * Safe to re-run at any time.
#
# Steps:
#   1. Locate (or install) Homebrew at ~/.linuxbrew
#   2. Install CLI tools: fish tmux fzf (brew), stow (brew, GNU tarball
#      fallback), neovim (prebuilt binary on Linux, brew on macOS)
#   3. Clone the dotfiles repo (if missing) and `stow` every package,
#      backing up pre-existing conflicting files
#   4. Install TPM (tmux plugin manager) + tmux plugins, headlessly
#   5. Install fisher + fish plugins (tide, fzf.fish, z, ...)
#   6. Migrate the tide prompt configuration (universal variables)
#   7. Headless `nvim` plugin sync (lazy.nvim) — best effort
#
# Assumes network access is already configured (e.g. https_proxy exported).
# Downloads use curl with a wget fallback (some proxies kill OpenSSL
# handshakes to github.com while GnuTLS-based clients still work).
#
# Useful overrides (environment variables):
#   DOTFILES_DIR   default: ~/.dotfiles
#   DOTFILES_REPO  default: https://github.com/spokeyjoe/.dotfiles.git
#   STOW_PACKAGES  default: "fish tmux nvim lazygit clang-format kitty"
#   BREW_PACKAGES  default: "fish tmux fzf"   (Linux; neovim added on macOS)
#   TIDE_FORCE=1   re-apply tide_vars.fish even if tide is already configured
#   SKIP_BREW=1 / SKIP_STOW=1 / SKIP_TMUX=1 / SKIP_FISH_PLUGINS=1 / SKIP_NVIM_SYNC=1

set -euo pipefail

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
OS="$(uname -s)"        # Linux | Darwin
ARCH="$(uname -m)"      # x86_64 | arm64/aarch64

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/spokeyjoe/.dotfiles.git}"
STOW_PACKAGES="${STOW_PACKAGES:-fish tmux nvim lazygit clang-format kitty}"
if [ "$OS" = "Darwin" ]; then
    BREW_PACKAGES="${BREW_PACKAGES:-fish tmux fzf neovim}"
else
    BREW_PACKAGES="${BREW_PACKAGES:-fish tmux fzf}"
fi
LINUXBREW_DIR="$HOME/.linuxbrew"
TPM_DIR="$HOME/.tmux/plugins/tpm"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LOCAL_OPT="$HOME/.local/opt"
LOCAL_BIN="$HOME/.local/bin"

export PATH="$LOCAL_BIN:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1

# Brewed glibc (present in user-local ~/.linuxbrew setups) ships no locale
# archive, which makes tmux refuse to start. Point it at the system locales.
if [ -d "$LINUXBREW_DIR/Cellar/glibc" ] && [ -d /usr/lib/locale ]; then
    export LOCPATH="${LOCPATH:-/usr/lib/locale}"
fi
export LANG="${LANG:-en_US.UTF-8}"
# Some machines export locales that were never generated (e.g. LC_NUMERIC=
# zh_CN.UTF-8 on a minimal en_US system) — every perl/tmux call then spews
# warnings or fails. Fall back to C.utf8 when the configured locale is broken.
if [ -z "${LC_ALL:-}" ] && locale 2>&1 | grep -q "Cannot set"; then
    if locale -a 2>/dev/null | grep -qi '^c\.utf8$'; then
        export LC_ALL=C.utf8
    fi
fi

# --------------------------------------------------------------------------
# Logging helpers
# --------------------------------------------------------------------------
if [ -t 1 ]; then
    C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_OFF=$'\033[0m'
else
    C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_OFF=''
fi
step() { printf '\n%s==> %s%s\n' "$C_BLUE" "$*" "$C_OFF"; }
ok()   { printf '%s  ✓ %s%s\n'  "$C_GREEN" "$*" "$C_OFF"; }
skip() { printf '%s  - %s (already done, skipping)%s\n' "$C_YELLOW" "$*" "$C_OFF"; }
warn() { printf '%s  ! %s%s\n' "$C_YELLOW" "$*" "$C_OFF" >&2; }
die()  { printf '%s  ✗ %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }

have()  { command -v "$1" >/dev/null 2>&1; }
works() { "$@" >/dev/null 2>&1; }

# Retry a command up to 3 times (flaky proxies, transient network errors).
retry() {
    local n=0
    until "$@"; do
        n=$((n + 1))
        [ "$n" -ge 3 ] && return 1
        warn "retrying ($n/3): $*"
        sleep 3
    done
}

# git clone with retries (proxies intermittently reset TLS handshakes).
# Removes the half-cloned destination before each retry.
git_clone() {
    local dest="${@: -1}" n=0
    until git clone "$@"; do
        n=$((n + 1))
        [ "$n" -ge 3 ] && return 1
        warn "retrying ($n/3): git clone $*"
        rm -rf "$dest"
        sleep 3
    done
}

# download <url> <dest> — curl first, wget fallback (GnuTLS vs OpenSSL
# handshake quirks behind some proxies).
download() {
    local url="$1" dest="$2"
    if have curl && curl -fsSL --retry 2 --connect-timeout 20 -o "$dest" "$url" 2>/dev/null; then
        return 0
    fi
    if have wget && wget -q --tries=2 --timeout=30 -O "$dest" "$url" 2>/dev/null; then
        return 0
    fi
    return 1
}

# --------------------------------------------------------------------------
# 1. Homebrew
# --------------------------------------------------------------------------
BREW=""
find_brew() {
    local candidate
    for candidate in \
        "$(command -v brew 2>/dev/null || true)" \
        "$LINUXBREW_DIR/bin/brew" \
        /home/linuxbrew/.linuxbrew/bin/brew \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            BREW="$candidate"
            return 0
        fi
    done
    return 1
}

install_brew() {
    # No-sudo install: git clone of Homebrew into ~/.linuxbrew.
    # (The official installer requires sudo on Linux for /home/linuxbrew.)
    step "Installing Homebrew to $LINUXBREW_DIR (no sudo)"
    have git || die "git is required to install Homebrew without sudo. Install git first."
    if [ -e "$LINUXBREW_DIR" ]; then
        die "$LINUXBREW_DIR exists but has no working bin/brew — please fix or remove it first."
    fi
    git_clone --depth 1 https://github.com/Homebrew/brew "$LINUXBREW_DIR"
    BREW="$LINUXBREW_DIR/bin/brew"
}

setup_brew() {
    step "Locating Homebrew"
    if find_brew; then
        skip "Homebrew found at $BREW"
    else
        case "$OS" in
            Linux) install_brew ;;
            Darwin) die "Homebrew not found. Install it from https://brew.sh (needs sudo on macOS), then re-run." ;;
            *) die "Unsupported OS: $OS" ;;
        esac
    fi
    eval "$("$BREW" shellenv)"
    # brew shellenv prepends $LINUXBREW_DIR/bin; keep ~/.local/bin first so
    # tarball-installed tools (e.g. stow) shadow broken brewed ones.
    export PATH="$LOCAL_BIN:$PATH"
    hash -r
    fix_brew_ca
    ok "brew: $("$BREW" --version | head -1)"
}

# User-local brew prefixes sometimes miss the openssl -> ca-certificates
# symlink, which breaks TLS verification for every brewed tool (git, curl).
fix_brew_ca() {
    [ -n "$BREW" ] || return 0
    local prefix ca ossl
    prefix="$($BREW --prefix 2>/dev/null)" || return 0
    ca="$prefix/etc/ca-certificates/cert.pem"
    [ -f "$ca" ] || return 0
    for ossl in "$prefix"/etc/openssl@3 "$prefix"/etc/openssl; do
        if [ -d "$ossl" ] && [ ! -e "$ossl/cert.pem" ]; then
            ln -sf "$ca" "$ossl/cert.pem"
            ok "linked $ossl/cert.pem → ca-certificates (fixed brewed TLS verification)"
        fi
    done
}

# --------------------------------------------------------------------------
# 2. CLI tools
# --------------------------------------------------------------------------

# Functional check: a binary must not only exist but actually run.
bin_works() {
    local bin="$1"; shift
    have "$bin" && works "$bin" "$@"
}

install_brew_packages() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "brew packages (SKIP_BREW=1)"; return; }
    step "Installing CLI tools via brew: $BREW_PACKAGES"
    local pkg bin
    for pkg in $BREW_PACKAGES; do
        bin="$pkg"
        [ "$pkg" = "neovim" ] && bin="nvim"
        local probe_args=(--version)
        [ "$bin" = "tmux" ] && probe_args=(-V)
        if bin_works "$bin" "${probe_args[@]}"; then
            skip "$pkg ($(command -v "$bin"))"
        else
            echo "  → brew install $pkg"
            retry "$BREW" install "$pkg" || warn "brew install $pkg failed"
            if bin_works "$bin" "${probe_args[@]}"; then
                ok "$pkg installed"
            else
                warn "$pkg installed but not working — continuing anyway"
            fi
        fi
    done
}

# stow needs special care: the brew bottle hardcodes brewed-perl paths and is
# broken whenever brewed perl version drifts. Fall back to the GNU tarball.
install_stow() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "stow (SKIP_BREW=1)"; return; }
    step "Installing GNU stow"
    if bin_works stow --version; then
        skip "stow ($(command -v stow))"
        return
    fi
    if [ -n "$BREW" ]; then
        echo "  → brew install stow"
        retry "$BREW" install stow || true
        if bin_works stow --version; then ok "stow installed (brew)"; return; fi
        warn "brewed stow is broken (known bottle/perl mismatch) — rebuilding from source"
        retry "$BREW" reinstall --build-from-source stow || true
        if bin_works stow --version; then ok "stow installed (brew, from source)"; return; fi
    fi
    if [ "$OS" = "Linux" ] && have perl && have make; then
        warn "falling back to GNU stow tarball → $LOCAL_BIN"
        local tmp; tmp="$(mktemp -d)"
        download "https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz" "$tmp/stow.tar.gz" \
            || die "could not download GNU stow"
        tar xzf "$tmp/stow.tar.gz" -C "$tmp"
        local perl_bin="perl"; [ -x /usr/bin/perl ] && perl_bin="/usr/bin/perl"
        (cd "$tmp"/stow-*/ && ./configure --prefix="$HOME/.local" PERL="$perl_bin" >/dev/null && make install >/dev/null)
        rm -rf "$tmp"
        bin_works stow --version && { ok "stow installed ($LOCAL_BIN/stow)"; return; }
    fi
    die "stow is not working and all install methods failed"
}

# neovim: official prebuilt tarball on Linux (brew bottles only work in
# /home/linuxbrew/.linuxbrew; a user-local prefix would mean a slow and
# fragile source build). brew on macOS.
install_neovim() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "neovim (SKIP_BREW=1)"; return; }
    step "Installing neovim"
    if bin_works nvim --version; then
        skip "neovim ($(command -v nvim))"
        return
    fi
    if [ "$OS" = "Darwin" ]; then
        retry "$BREW" install neovim || die "brew install neovim failed"
        ok "neovim installed (brew)"
        return
    fi
    local narch
    case "$ARCH" in
        x86_64)          narch="x86_64" ;;
        aarch64|arm64)   narch="arm64" ;;
        *) die "unsupported architecture for prebuilt neovim: $ARCH" ;;
    esac
    local tmp; tmp="$(mktemp -d)"
    download "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-$narch.tar.gz" "$tmp/nvim.tar.gz" \
        || die "could not download neovim release"
    mkdir -p "$LOCAL_OPT" "$LOCAL_BIN"
    rm -rf "$LOCAL_OPT/nvim-linux-$narch"
    tar xzf "$tmp/nvim.tar.gz" -C "$LOCAL_OPT"
    ln -sf "$LOCAL_OPT/nvim-linux-$narch/bin/nvim" "$LOCAL_BIN/nvim"
    rm -rf "$tmp"
    bin_works nvim --version || die "neovim installed but not running"
    ok "neovim installed ($LOCAL_BIN/nvim)"
}

# --------------------------------------------------------------------------
# 3. Dotfiles clone + stow
# --------------------------------------------------------------------------
clone_dotfiles() {
    step "Dotfiles repository"
    if [ -d "$DOTFILES_DIR/.git" ]; then
        skip "dotfiles repo at $DOTFILES_DIR"
    elif [ -e "$DOTFILES_DIR" ]; then
        die "$DOTFILES_DIR exists but is not a git checkout — move it aside first."
    else
        git_clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        ok "cloned $DOTFILES_REPO → $DOTFILES_DIR"
    fi
}

# Back up any real file / foreign symlink in $HOME that would block stow.
stow_backup_conflicts() {
    local pkg="$1" rel target
    while IFS= read -r rel; do
        rel="${rel#./}"
        target="$HOME/$rel"
        # Not present at all → no conflict
        [ -e "$target" ] || [ -L "$target" ] || continue
        # Resolves into the dotfiles repo (already stowed, possibly via a
        # folded directory symlink) → no conflict
        if [ -e "$target" ]; then
            case "$(readlink -f "$target")" in
                "$DOTFILES_DIR/"*) continue ;;
            esac
        fi
        mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
        mv "$target" "$BACKUP_DIR/$rel"
        warn "backed up conflicting ~/$rel → $BACKUP_DIR/$rel"
    done < <(cd "$DOTFILES_DIR/$pkg" && find . -mindepth 1 \( -type f -o -type l \))
}

stow_packages() {
    [ "${SKIP_STOW:-0}" = "1" ] && { skip "stow (SKIP_STOW=1)"; return; }
    step "Stowing packages into \$HOME"
    local pkg
    for pkg in $STOW_PACKAGES; do
        if [ ! -d "$DOTFILES_DIR/$pkg" ]; then
            warn "package '$pkg' has no directory in $DOTFILES_DIR — skipping"
            continue
        fi
        stow_backup_conflicts "$pkg"
        # --no-folding: symlink files, not directories — plugin managers
        # (fisher, tpm) must write into real dirs, not into the repo tree.
        stow --restow --no-folding --dir="$DOTFILES_DIR" --target="$HOME" "$pkg"
        ok "stowed $pkg"
    done
    if [ -d "$BACKUP_DIR" ]; then
        warn "pre-existing files were moved to $BACKUP_DIR"
    fi
}

# --------------------------------------------------------------------------
# 4. TPM + tmux plugins
# --------------------------------------------------------------------------
install_tpm() {
    [ "${SKIP_TMUX:-0}" = "1" ] && { skip "tpm (SKIP_TMUX=1)"; return; }
    bin_works tmux -V || { warn "tmux not working — skipping TPM"; return; }
    step "Tmux Plugin Manager (TPM)"
    if [ -d "$TPM_DIR" ]; then
        skip "TPM at $TPM_DIR"
    else
        git_clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
        ok "cloned TPM"
    fi

    step "Installing tmux plugins (headless)"
    # install_plugins reads @plugin options from a running tmux server,
    # so spin up a throwaway one with the stowed config first.
    tmux start-server \; new-session -d -s __bootstrap 2>/dev/null || true
    retry "$TPM_DIR/bin/install_plugins" && ok "tmux plugins installed" \
        || warn "tmux plugin install failed — run '<prefix> + I' inside tmux later"
    tmux kill-server 2>/dev/null || true
}

# --------------------------------------------------------------------------
# 5. Fisher + fish plugins (reads ~/.config/fish/fish_plugins)
# --------------------------------------------------------------------------
install_fish_plugins() {
    [ "${SKIP_FISH_PLUGINS:-0}" = "1" ] && { skip "fish plugins (SKIP_FISH_PLUGINS=1)"; return; }
    bin_works fish --version || { warn "fish not working — skipping fish plugins"; return; }
    step "Installing fisher + fish plugins"
    local fisher_src=""
    if ! fish -c 'functions -q fisher' 2>/dev/null; then
        local tmp; tmp="$(mktemp -d)"
        if download "https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish" "$tmp/fisher.fish"; then
            fisher_src="$tmp/fisher.fish"
        else
            warn "raw.githubusercontent.com unreachable — cloning fisher instead"
            git_clone --depth 1 -q https://github.com/jorgebucaran/fisher "$tmp/fisher"
            fisher_src="$tmp/fisher/functions/fisher.fish"
        fi
        # Source (not copy) fisher so `fisher install jorgebucaran/fisher`
        # below can install it cleanly as a managed plugin.
    fi
    # Install every plugin listed in fish_plugins (explicit args; bare
    # `fisher install` errors out on newer fisher versions).
    retry fish -c "${fisher_src:+source $fisher_src;} fisher install (cat ~/.config/fish/fish_plugins)" \
        && ok "fish plugins installed (see ~/.config/fish/fish_plugins)" \
        || warn "fisher failed — re-run 'fisher update' inside fish later"
    # Bulk install drops fisher itself when it is running from a sourced
    # (not yet installed) file — install it explicitly.
    if [ -n "${fisher_src:-}" ] && ! fish -c 'functions -q fisher' 2>/dev/null; then
        fish -c "source $fisher_src; fisher install jorgebucaran/fisher" \
            && ok "fisher installed" || warn "could not install fisher itself"
    fi
    [ -n "${fisher_src:-}" ] && rm -rf "$(dirname "$(dirname "$fisher_src")")" 2>/dev/null || true
}

# --------------------------------------------------------------------------
# 6. Tide prompt config migration
# --------------------------------------------------------------------------
migrate_tide() {
    bin_works fish --version || return 0
    step "Migrating tide prompt configuration"
    local vars_file="$HOME/.config/fish/tide_vars.fish"
    if [ ! -f "$vars_file" ]; then
        warn "$vars_file not found — skipping tide migration"
        return
    fi
    # NB: tide seeds its own universal-variable defaults on first load, so
    # 'set -q tide_*' can't distinguish defaults from a migrated config —
    # use our own marker variable instead.
    if [ "${TIDE_FORCE:-0}" != "1" ] && fish -c 'set -q _tide_dotfiles_migrated' 2>/dev/null; then
        skip "tide already configured (set TIDE_FORCE=1 to re-apply)"
        return
    fi
    if fish -c "source $vars_file; set -U _tide_dotfiles_migrated 1"; then
        ok "tide config applied (universal variables → ~/.config/fish/fish_variables)"
    else
        warn "failed to apply tide config"
    fi
}

# --------------------------------------------------------------------------
# 7. Default shell: exec fish from ~/.bashrc
# --------------------------------------------------------------------------
# No-sudo alternative to chsh: bash stays the login shell, and interactive
# sessions hand off to fish immediately. Escape hatches: `bash --norc`, or
# `NO_FISH=1 ssh ...`. The interactive guard is required because
# non-interactive ssh/scp/rsync shells also source ~/.bashrc.
setup_default_shell() {
    [ "${SKIP_DEFAULT_SHELL:-0}" = "1" ] && { skip "default shell (SKIP_DEFAULT_SHELL=1)"; return; }
    step "Making fish the default interactive shell (~/.bashrc)"
    local fish_bin="" candidate
    for candidate in \
        "$(command -v fish 2>/dev/null || true)" \
        "$LINUXBREW_DIR/bin/fish" \
        /usr/bin/fish /usr/local/bin/fish /opt/homebrew/bin/fish; do
        if [ -n "$candidate" ] && [ -x "$candidate" ]; then
            fish_bin="$candidate"
            break
        fi
    done
    [ -n "$fish_bin" ] || { warn "fish not found — skipping"; return; }
    if grep -q "dotfiles: exec fish" "$HOME/.bashrc" 2>/dev/null; then
        skip "fish exec block already in ~/.bashrc"
        return
    fi
    cat >>"$HOME/.bashrc" <<EOF

# >>> dotfiles: exec fish >>>
# Hand interactive sessions over to fish. Use \`bash --norc\` for a plain bash.
if [[ \$- == *i* ]] && [[ -z "\${NO_FISH:-}" ]] && [[ -x "$fish_bin" ]]; then
    exec "$fish_bin"
fi
# <<< dotfiles: exec fish <<<
EOF
    ok "~/.bashrc now execs $fish_bin for interactive shells"
}

# --------------------------------------------------------------------------
# 8. nvim plugin sync (best effort)
# --------------------------------------------------------------------------
sync_nvim() {
    [ "${SKIP_NVIM_SYNC:-0}" = "1" ] && { skip "nvim sync (SKIP_NVIM_SYNC=1)"; return; }
    bin_works nvim --version || return 0
    step "Installing neovim plugins (lazy.nvim restore from lockfile, headless)"
    # NB: `restore`, not `sync` — sync also *updates* past lazy-lock.json
    # (e.g. jumps nvim-treesitter to the incompatible new `main` branch).
    if timeout 600 nvim --headless "+Lazy! restore" +qa </dev/null >/dev/null 2>&1; then
        ok "neovim plugins restored from lazy-lock.json"
    else
        warn "headless lazy.nvim restore failed — open nvim once and run :Lazy restore"
    fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
    echo "Bootstrapping dotfiles environment"
    echo "  os/arch:   $OS/$ARCH"
    echo "  dotfiles:  $DOTFILES_DIR"
    echo "  stow pkgs: $STOW_PACKAGES"
    echo "  brew pkgs: $BREW_PACKAGES"

    setup_brew
    install_brew_packages
    install_stow
    install_neovim
    clone_dotfiles
    stow_packages
    install_tpm
    install_fish_plugins
    migrate_tide
    setup_default_shell
    sync_nvim

    step "Done!"
    local fish_path
    fish_path="$(command -v fish 2>/dev/null || echo "$LINUXBREW_DIR/bin/fish")"
    cat <<EOF

Next steps:
  • Log in again — interactive bash now hands off to fish automatically
    (plain bash: \`bash --norc\`; skip once: \`NO_FISH=1 ssh <host>\`)
  • Or start right away:              $fish_path
  • Tmux with everything loaded:      tm
EOF
}

main "$@"
