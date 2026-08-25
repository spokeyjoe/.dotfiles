#!/usr/bin/env bash
#
# bootstrap.sh — set up Joe's dotfiles environment on a fresh machine.
#
#   * No sudo required: CLI tools come from a user-local Homebrew
#     (~/.linuxbrew on Linux); neovim/tree-sitter use official binaries
#     or user-local builds.
#   * Idempotent: anything already installed/working is skipped.
#   * Safe to re-run at any time.
#
# Steps:
#   1. Locate (or install) Homebrew at ~/.linuxbrew
#   2. CLI tools: fish tmux fzf (brew), stow (brew, GNU tarball fallback),
#      neovim (prebuilt tarball on Linux, brew on macOS), tree-sitter CLI
#      (prebuilt binary, or cargo build on glibc < 2.39)
#   3. Clone the dotfiles repo (if missing) and `stow` every package,
#      backing up pre-existing conflicting files
#   4. Install TPM (tmux plugin manager) + tmux plugins, headlessly
#   5. Install fisher + fish plugins (tide, fzf.fish, z, ...)
#   6. Migrate the tide prompt configuration (universal variables)
#   7. Make fish the default interactive shell via ~/.bashrc
#   8. Headless lazy.nvim restore from lockfile + treesitter parser build
#
# Assumes network access is already configured (e.g. https_proxy exported).
# Network note: some proxies (Loon) kill curl's default TLS ClientHello;
# --no-alpn fixes it. The curl/.curlrc package carries this for interactive
# use; brew gets it via HOMEBREW_CURLRC below.
#
# Useful overrides (environment variables):
#   DOTFILES_DIR   default: ~/.dotfiles
#   DOTFILES_REPO  default: https://github.com/spokeyjoe/.dotfiles.git
#   STOW_PACKAGES  default: "fish tmux nvim lazygit clang-format kitty curl pi"
#   BREW_PACKAGES  default: "fish tmux fzf"
#   TIDE_FORCE=1   re-apply tide_vars.fish even if tide is already configured
#   SKIP_BREW=1 / SKIP_STOW=1 / SKIP_TMUX=1 / SKIP_FISH_PLUGINS=1 / \
#   SKIP_DEFAULT_SHELL=1 / SKIP_NVIM_SYNC=1

set -euo pipefail

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
OS="$(uname -s)"        # Linux | Darwin
ARCH="$(uname -m)"      # x86_64 | arm64/aarch64
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/spokeyjoe/.dotfiles.git}"
STOW_PACKAGES="${STOW_PACKAGES:-fish tmux nvim lazygit clang-format kitty curl pi}"
BREW_PACKAGES="${BREW_PACKAGES:-fish tmux fzf}"
LINUXBREW_DIR="$HOME/.linuxbrew"
TPM_DIR="$HOME/.tmux/plugins/tpm"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LOCAL_OPT="$HOME/.local/opt"
LOCAL_BIN="$HOME/.local/bin"

NVIM_MIN_VERSION="0.12"     # required by nvim-treesitter's main branch
TS_MIN_VERSION="0.26.1"     # required by nvim-treesitter's main branch
TS_PREBUILD_GLIBC_MIN="2.39" # official tree-sitter binaries need this glibc

export PATH="$LOCAL_BIN:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1
# brew ignores ~/.curlrc; give it the repo's (no-alpn) explicitly.
[ -f "$SCRIPT_DIR/curl/.curlrc" ] && export HOMEBREW_CURLRC="$SCRIPT_DIR/curl/.curlrc"

# Brewed glibc (user-local ~/.linuxbrew) ships no locale archive, which makes
# tmux refuse to start — point it at the system locales.
if [ -d "$LINUXBREW_DIR/Cellar/glibc" ] && [ -d /usr/lib/locale ]; then
    export LOCPATH="${LOCPATH:-/usr/lib/locale}"
fi
export LANG="${LANG:-en_US.UTF-8}"
# Some machines export locales that were never generated (e.g. LC_NUMERIC=
# zh_CN.UTF-8) — every perl/tmux call then spews warnings. Fall back to C.utf8.
if [ -z "${LC_ALL:-}" ] && locale 2>&1 | grep -q "Cannot set" \
    && locale -a 2>/dev/null | grep -qi '^c\.utf8$'; then
    export LC_ALL=C.utf8
fi

# --------------------------------------------------------------------------
# Helpers
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
# Functional check: a binary must not only exist but actually run.
bin_works() { local bin="$1"; shift; have "$bin" && works "$bin" "$@"; }
# version_ge <have> <want> — true if $have >= $want (dot-separated numbers)
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# Retry a command up to 3 times (the proxy flaps when iOS suspends Loon).
retry() {
    local n=0
    until "$@"; do
        n=$((n + 1))
        [ "$n" -ge 3 ] && return 1
        warn "retrying ($n/3): $*"
        sleep 3
    done
}

# git clone with retries; removes the half-cloned destination before retrying.
git_clone() {
    local dest="${*: -1}" n=0
    until timeout 300 git clone "$@"; do
        n=$((n + 1))
        [ "$n" -ge 3 ] && return 1
        warn "retrying ($n/3): git clone $*"
        rm -rf "$dest"
        sleep 3
    done
}

# download <url> <dest> — --no-alpn is required behind ALPN-killing proxies.
# The speed-limit flags kill stalled transfers (a connected-but-frozen proxy
# would otherwise hang forever); curl then retries per --retry.
download() {
    curl -fsSL --no-alpn --retry 3 --connect-timeout 20 \
        --speed-limit 1024 --speed-time 30 -o "$2" "$1"
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

setup_brew() {
    step "Locating Homebrew"
    if find_brew; then
        skip "Homebrew found at $BREW"
    else
        [ "$OS" = "Linux" ] || die "Homebrew not found — install it from https://brew.sh first."
        # No-sudo install: git clone of Homebrew into ~/.linuxbrew (the
        # official installer needs sudo on Linux for /home/linuxbrew).
        have git || die "git is required to install Homebrew without sudo."
        [ -e "$LINUXBREW_DIR" ] && die "$LINUXBREW_DIR exists but has no working bin/brew — fix or remove it first."
        step "Installing Homebrew to $LINUXBREW_DIR (no sudo)"
        git_clone --depth 1 https://github.com/Homebrew/brew "$LINUXBREW_DIR"
        BREW="$LINUXBREW_DIR/bin/brew"
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
    local prefix ca ossl
    prefix="$("$BREW" --prefix 2>/dev/null)" || return 0
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
install_brew_packages() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "brew packages (SKIP_BREW=1)"; return; }
    step "Installing CLI tools via brew: $BREW_PACKAGES"
    local pkg probe
    for pkg in $BREW_PACKAGES; do
        probe="--version"; [ "$pkg" = "tmux" ] && probe="-V"
        if bin_works "$pkg" "$probe"; then
            skip "$pkg ($(command -v "$pkg"))"
        else
            echo "  → brew install $pkg"
            retry "$BREW" install "$pkg" || warn "brew install $pkg failed"
            bin_works "$pkg" "$probe" && ok "$pkg installed" \
                || warn "$pkg installed but not working — continuing anyway"
        fi
    done
}

# stow needs special care: the brew bottle hardcodes brewed-perl paths and is
# broken whenever brewed perl version drifts — fall back to the GNU tarball.
install_stow() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "stow (SKIP_BREW=1)"; return; }
    step "Installing GNU stow"
    if bin_works stow --version; then
        skip "stow ($(command -v stow))"
        return
    fi
    retry "$BREW" install stow || true
    if bin_works stow --version; then ok "stow installed (brew)"; return; fi
    if [ "$OS" = "Linux" ] && have perl && have make; then
        warn "brewed stow broken (bottle/perl mismatch) — using the GNU tarball"
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
# /home/linuxbrew/.linuxbrew; a user-local prefix means a slow, fragile
# source build). brew on macOS.
nvim_version_ok() {
    bin_works nvim --version || return 1
    local ver
    ver="$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    [ -n "$ver" ] && version_ge "$ver" "$NVIM_MIN_VERSION"
}

install_neovim() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "neovim (SKIP_BREW=1)"; return; }
    step "Installing neovim (>= $NVIM_MIN_VERSION)"
    if nvim_version_ok; then
        skip "neovim ($(command -v nvim))"
        return
    fi
    bin_works nvim --version \
        && warn "nvim ($(command -v nvim)) is older than $NVIM_MIN_VERSION — installing a newer one"
    if [ "$OS" = "Darwin" ]; then
        retry "$BREW" install neovim || die "brew install neovim failed"
        ok "neovim installed (brew)"
        return
    fi
    local narch
    case "$ARCH" in
        x86_64)        narch="x86_64" ;;
        aarch64|arm64) narch="arm64" ;;
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
    hash -r
    bin_works nvim --version || die "neovim installed but not running"
    ok "neovim installed ($LOCAL_BIN/nvim)"
}

# tree-sitter CLI: required (not from npm) by nvim-treesitter's main branch
# to compile parsers. Prebuilt binaries need glibc >= 2.39; on older systems
# (e.g. Ubuntu 22.04) build it with a user-local rustup toolchain instead.
install_treesitter_cli() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "tree-sitter CLI (SKIP_BREW=1)"; return; }
    step "Installing tree-sitter CLI (>= $TS_MIN_VERSION)"
    if bin_works tree-sitter --version; then
        local v
        v="$(tree-sitter --version | grep -oE '[0-9.]+' | head -1)"
        if [ -n "$v" ] && version_ge "$v" "$TS_MIN_VERSION"; then
            skip "tree-sitter CLI $v ($(command -v tree-sitter))"
            return
        fi
        warn "tree-sitter CLI $v is older than $TS_MIN_VERSION — upgrading"
    fi
    if [ "$OS" = "Darwin" ]; then
        retry "$BREW" install tree-sitter-cli || die "brew install tree-sitter-cli failed"
        ok "tree-sitter CLI installed (brew)"
        return
    fi
    local glibc
    glibc="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1)"
    if [ -n "$glibc" ] && version_ge "$glibc" "$TS_PREBUILD_GLIBC_MIN"; then
        local tarch tmp
        case "$ARCH" in
            x86_64)        tarch="x64" ;;
            aarch64|arm64) tarch="arm64" ;;
            *) die "unsupported architecture for prebuilt tree-sitter: $ARCH" ;;
        esac
        tmp="$(mktemp -d)"
        download "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$tarch.gz" "$tmp/ts.gz" \
            || die "could not download tree-sitter CLI"
        mkdir -p "$LOCAL_BIN"
        gunzip -c "$tmp/ts.gz" > "$LOCAL_BIN/tree-sitter"
        chmod +x "$LOCAL_BIN/tree-sitter"
        rm -rf "$tmp"
    else
        warn "system glibc $glibc < $TS_PREBUILD_GLIBC_MIN — building tree-sitter CLI from source"
        ensure_rust
        # --no-default-features skips qjs-rt (QuickJS/bindgen, needs libclang);
        # nvim-treesitter only needs `tree-sitter build`.
        echo "  → cargo install tree-sitter-cli (a few minutes, one time)"
        retry cargo install tree-sitter-cli --locked --no-default-features \
            || die "cargo install tree-sitter-cli failed"
        ln -sf "$HOME/.cargo/bin/tree-sitter" "$LOCAL_BIN/tree-sitter"
    fi
    hash -r
    bin_works tree-sitter --version || die "tree-sitter CLI installed but not running"
    ok "tree-sitter CLI $(tree-sitter --version | grep -oE '[0-9.]+' | head -1) installed"
}

ensure_rust() {
    # User-local Rust toolchain via rustup (no sudo, no mirrors).
    if [ -x "$HOME/.cargo/bin/cargo" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"; hash -r
    fi
    bin_works cargo --version && return 0
    step "Installing Rust toolchain (rustup, minimal)"
    local tmp; tmp="$(mktemp -d)"
    download "https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init" "$tmp/rustup-init" \
        || die "could not download rustup-init"
    chmod +x "$tmp/rustup-init"
    "$tmp/rustup-init" -y --quiet --profile minimal --default-toolchain stable
    rm -rf "$tmp"
    export PATH="$HOME/.cargo/bin:$PATH"; hash -r
    bin_works cargo --version || die "rustup installed but cargo not working"
    ok "rust $(rustc --version | grep -oE '[0-9.]+' | head -1) installed"
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
        [ -e "$target" ] || [ -L "$target" ] || continue
        # Resolves into the dotfiles repo (already stowed) → no conflict
        if [ -e "$target" ]; then
            case "$(readlink -f "$target")" in
                "$DOTFILES_DIR/"*) continue ;;
            esac
        fi
        # Real file with identical content (e.g. fisher rewrote the stowed
        # file in place) → just remove it, no backup needed
        if [ -f "$target" ] && [ ! -L "$target" ] && cmp -s "$target" "$DOTFILES_DIR/$pkg/$rel"; then
            rm -f "$target"
            continue
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
    # Read the plugin manifest from the REPO, not the (symlinked) live file:
    # fisher treats ~/.config/fish/fish_plugins as mutable state and deletes
    # it outright when its own state (universal vars) is wiped.
    local manifest="$DOTFILES_DIR/fish/.config/fish/fish_plugins"
    [ -f "$manifest" ] || { warn "$manifest not found — skipping fish plugins"; return; }
    local tmp=""
    if ! fish -c 'functions -q fisher' 2>/dev/null; then
        tmp="$(mktemp -d)"
        download "https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish" "$tmp/fisher.fish" \
            || { warn "could not download fisher — skipping fish plugins"; rm -rf "$tmp"; return; }
        # Source (not copy) so `fisher install jorgebucaran/fisher` below can
        # install it cleanly as a managed plugin.
    fi
    local out status
    set +e
    out="$(timeout 600 fish -c "${tmp:+source $tmp/fisher.fish;} fisher install (cat $manifest)" 2>&1)"
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        # fisher refuses to overwrite files it has no record of (stale plugin
        # files from a wiped/lost fisher state). Remove exactly the files it
        # complains about — all under ~/.config/fish — and retry once.
        local conflicts
        conflicts="$(printf '%s\n' "$out" | awk '/^fisher: Cannot install/{flag=1; next} /^fisher:/{flag=0} flag && /^[[:space:]]+\//{print $1}' | grep "^$HOME/.config/fish/" | sort -u)"
        if [ -n "$conflicts" ]; then
            warn "removing stale plugin files fisher refuses to overwrite:"
            printf '%s\n' "$conflicts" | while IFS= read -r f; do
                warn "  rm -rf $f"
                rm -rf "$f"
            done
            out="$(retry timeout 600 fish -c "${tmp:+source $tmp/fisher.fish;} fisher install (cat $manifest)" 2>&1)" \
                && status=0 || status=1
        fi
    fi
    [ "$status" -eq 0 ] && ok "fish plugins installed (see $manifest)" \
        || { warn "fisher failed — re-run 'fisher update' inside fish later"; printf '%s\n' "$out" | tail -5 >&2; }
    # Bulk install drops fisher itself when it is running from a sourced
    # (not yet installed) file — install it explicitly.
    if [ -n "$tmp" ] && ! fish -c 'functions -q fisher' 2>/dev/null; then
        fish -c "source $tmp/fisher.fish; fisher install jorgebucaran/fisher" \
            && ok "fisher installed" || warn "could not install fisher itself"
    fi
    if [ -n "$tmp" ]; then rm -rf "$tmp"; fi
    FISHER_OUTPUT="$out"   # migrate_tide checks whether tide was (re)installed
    # Restore the stowed fish_plugins link if fisher removed/replaced it.
    if [ ! -L "$HOME/.config/fish/fish_plugins" ]; then
        stow_backup_conflicts fish
        stow --restow --no-folding --dir="$DOTFILES_DIR" --target="$HOME" fish >/dev/null
    fi
}

# --------------------------------------------------------------------------
# 6. Tide prompt config migration
# --------------------------------------------------------------------------
FISHER_OUTPUT=""   # install_fish_plugins records its output here
migrate_tide() {
    bin_works fish --version || return 0
    step "Migrating tide prompt configuration"
    local vars_file="$HOME/.config/fish/tide_vars.fish"
    if [ ! -f "$vars_file" ]; then
        warn "$vars_file not found — skipping tide migration"
        return
    fi
    # NB: tide seeds its own universal-variable defaults on first load, and
    # `_tide_init_install` resets them again on every fresh tide install —
    # so 'set -q tide_*' can't distinguish defaults from a migrated config.
    # Apply when: TIDE_FORCE=1, our marker is missing, or fisher just
    # (re)installed tide this run.
    if [ "${TIDE_FORCE:-0}" != "1" ] \
        && ! printf '%s' "$FISHER_OUTPUT" | grep -q 'Installing.*tide' \
        && fish -c 'set -q _tide_dotfiles_migrated' 2>/dev/null; then
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
    ok "added fish exec block to $HOME/.bashrc"
}

# --------------------------------------------------------------------------
# 8. nvim plugin restore (best effort)
# --------------------------------------------------------------------------
sync_nvim() {
    [ "${SKIP_NVIM_SYNC:-0}" = "1" ] && { skip "nvim sync (SKIP_NVIM_SYNC=1)"; return; }
    bin_works nvim --version || return 0
    step "Installing neovim plugins (lazy.nvim restore from lockfile, headless)"
    # NB: `restore`, not `sync` — sync also *updates* past lazy-lock.json.
    if ! timeout 600 nvim --headless "+Lazy! restore" +qa </dev/null >/dev/null 2>&1; then
        warn "headless lazy.nvim restore failed — open nvim once and run :Lazy restore"
        return
    fi
    # Second headless run: lets the treesitter config build parsers (it waits
    # when headless) and acts as a startup sanity check.
    if timeout 600 nvim --headless +qa </dev/null >/dev/null 2>&1; then
        ok "neovim plugins restored from lazy-lock.json, treesitter parsers built"
    else
        warn "neovim restored, but a plain headless startup failed — check :checkhealth"
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
    install_treesitter_cli
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
