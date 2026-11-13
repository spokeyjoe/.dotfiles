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
#   7. Make fish the default interactive shell via the login shell's rc file
#      (~/.bashrc or ~/.zshrc)
#   8. Headless lazy.nvim restore from lockfile + treesitter parser build
#
# Assumes network access is already configured (e.g. https_proxy exported).
#
# Useful overrides (environment variables):
#   DOTFILES_DIR   default: ~/.dotfiles
#   DOTFILES_REPO  default: https://github.com/spokeyjoe/.dotfiles.git
#   STOW_PACKAGES  default: "fish tmux nvim lazygit clang-format kitty pi"
#   BREW_PACKAGES  default: "fish tmux fzf" (+ coreutils on macOS)
#   TIDE_FORCE=1   re-apply tide_vars.fish even if tide is already configured
#   SKIP_BREW=1    skip ALL tool installation (steps 1-2: Homebrew, brew
#                  packages, stow, neovim, tree-sitter); an existing brew is
#                  still put on PATH
#   SKIP_STOW=1 / SKIP_TMUX=1 / SKIP_FISH_PLUGINS=1 / \
#   SKIP_DEFAULT_SHELL=1 / SKIP_NVIM_SYNC=1

set -euo pipefail

# --------------------------------------------------------------------------
# Config
# --------------------------------------------------------------------------
OS="$(uname -s)"        # Linux | Darwin
ARCH="$(uname -m)"      # x86_64 | arm64/aarch64

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/spokeyjoe/.dotfiles.git}"
STOW_PACKAGES="${STOW_PACKAGES:-fish tmux nvim lazygit clang-format kitty pi}"
DEFAULT_BREW_PACKAGES="fish tmux fzf"
# GNU coreutils provide gtimeout/greadlink on stock macOS.
if [ "$OS" = "Darwin" ]; then
    DEFAULT_BREW_PACKAGES="$DEFAULT_BREW_PACKAGES coreutils"
fi
BREW_PACKAGES="${BREW_PACKAGES:-$DEFAULT_BREW_PACKAGES}"
LINUXBREW_DIR="$HOME/.linuxbrew"
TPM_DIR="$HOME/.tmux/plugins/tpm"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
LOCAL_OPT="$HOME/.local/opt"
LOCAL_BIN="$HOME/.local/bin"

NVIM_MIN_VERSION="0.12"     # required by nvim-treesitter's main branch
TS_MIN_VERSION="0.26.1"     # required by nvim-treesitter's main branch
TS_PREBUILD_GLIBC_MIN="2.39" # official tree-sitter binaries need this glibc

SHELL_BLOCK_BEGIN="# >>> dotfiles: exec fish >>>"
SHELL_BLOCK_END="# <<< dotfiles: exec fish <<<"

# Mutable state shared between steps.
BREW=""              # path to the brew executable (setup_brew)
TMP_ROOT=""          # scratch directory, removed on exit (main)
TIDE_REINSTALLED=0   # install_fish_plugins sets this when tide was wiped

export PATH="$LOCAL_BIN:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ANALYTICS=1

# Never export LOCPATH globally: it makes system glibc programs use the
# wrong locale database. fix_brew_glibc_locale generates a proper archive
# inside the Homebrew glibc prefix instead.
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

# first_version — print the first dotted version number found on stdin.
# Never fails (safe in `v="$(cmd | first_version)"` under set -e/pipefail).
first_version() { grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true; }

# version_ge <have> <want> — true if $have >= $want (dot-separated numbers).
# Pure Bash so it works on stock macOS (BSD sort has no GNU -V).
version_ge() {
    local have="$1" want="$2" i max h w
    local -a have_parts want_parts
    IFS=. read -r -a have_parts <<<"$have"
    IFS=. read -r -a want_parts <<<"$want"
    max=${#have_parts[@]}
    if [ "${#want_parts[@]}" -gt "$max" ]; then max=${#want_parts[@]}; fi
    for ((i = 0; i < max; i++)); do
        h="${have_parts[i]:-0}"
        w="${want_parts[i]:-0}"
        if [[ ! $h =~ ^[0-9]+$ || ! $w =~ ^[0-9]+$ ]]; then return 1; fi
        h=$((10#$h))
        w=$((10#$w))
        if [ "$h" -gt "$w" ]; then return 0; fi
        if [ "$h" -lt "$w" ]; then return 1; fi
    done
    return 0
}

# canonical_path <path> — GNU readlink -f with a stock-macOS fallback.
canonical_path() {
    local path="$1" dir base
    if have readlink && readlink -f "$path" 2>/dev/null; then return 0; fi
    if have greadlink && greadlink -f "$path" 2>/dev/null; then return 0; fi
    if have realpath && realpath "$path" 2>/dev/null; then return 0; fi
    [ -e "$path" ] || return 1
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
}

# in_dotfiles <path> — true if <path> resolves to something inside the repo.
# Relies on $DOTFILES_DIR being canonical (see clone_dotfiles).
in_dotfiles() {
    local resolved
    resolved="$(canonical_path "$1" 2>/dev/null)" || return 1
    case "$resolved" in
        "$DOTFILES_DIR"/*) return 0 ;;
    esac
    return 1
}

# new_tmp — create a scratch directory that is removed when the script exits.
new_tmp() { mktemp -d "$TMP_ROOT/XXXXXX"; }

# run_with_timeout <seconds> <command...> — timeout(1) or coreutils' gtimeout.
run_with_timeout() {
    local seconds="$1"
    shift
    if have timeout; then
        timeout "$seconds" "$@"
    elif have gtimeout; then
        gtimeout "$seconds" "$@"
    else
        warn "timeout is unavailable; running without a timeout: $*"
        "$@"
    fi
}

# Retry a command up to 3 times (the proxy flaps when iOS suspends Loon).
retry() {
    local n=1
    until "$@"; do
        if [ "$n" -ge 3 ]; then return 1; fi
        warn "retrying ($n/3): $*"
        n=$((n + 1))
        sleep 3
    done
}

# git clone with retries; never leaves a half-cloned destination behind.
# The destination (last argument) must not exist beforehand.
git_clone() {
    local dest="${*: -1}" n=1
    until run_with_timeout 300 git clone "$@"; do
        rm -rf "$dest"
        if [ "$n" -ge 3 ]; then return 1; fi
        warn "retrying ($n/3): git clone $*"
        n=$((n + 1))
        sleep 3
    done
}

# download <url> <dest> — retries + a stall detector so a frozen proxy
# connection can't hang the script forever.
download() {
    curl -fsSL --retry 3 --connect-timeout 20 \
        --speed-limit 1024 --speed-time 30 -o "$2" "$1"
}

# --------------------------------------------------------------------------
# 0. Preflight
# --------------------------------------------------------------------------
preflight() {
    local cmd missing=""
    for cmd in git curl tar gzip; do
        have "$cmd" || missing="$missing $cmd"
    done
    [ -z "$missing" ] || die "required commands not found:$missing — install them first."
    if [ "$OS" = "Linux" ] && [ "${SKIP_BREW:-0}" != "1" ]; then
        if ! have make || ! { have cc || have gcc; }; then
            warn "no C compiler and/or make found — source builds (brew, stow, tree-sitter) may fail"
        fi
    fi
    mkdir -p "$LOCAL_BIN" "$LOCAL_OPT"
}

# --------------------------------------------------------------------------
# 1. Homebrew
# --------------------------------------------------------------------------
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
    elif [ "${SKIP_BREW:-0}" = "1" ]; then
        skip "Homebrew not found, not installing it (SKIP_BREW=1)"
        return
    else
        [ "$OS" = "Linux" ] || die "Homebrew not found — install it from https://brew.sh first."
        # No-sudo install: git clone of Homebrew into ~/.linuxbrew (the
        # official installer needs sudo on Linux for /home/linuxbrew).
        [ ! -e "$LINUXBREW_DIR" ] || die "$LINUXBREW_DIR exists but has no working bin/brew — fix or remove it first."
        step "Installing Homebrew to $LINUXBREW_DIR (no sudo)"
        git_clone --depth 1 https://github.com/Homebrew/brew "$LINUXBREW_DIR" \
            || die "could not clone Homebrew into $LINUXBREW_DIR"
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

# User-local Homebrew glibc installations do not include a locale archive.
# Generate one inside its own prefix instead of exporting LOCPATH globally
# (LOCPATH would also affect programs linked against the system glibc).
fix_brew_glibc_locale() {
    [ "$OS" = "Linux" ] || return 0
    [ -n "$BREW" ] || return 0
    local glibc_opt glibc_prefix locale_dir archive
    glibc_opt="$("$BREW" --prefix glibc 2>/dev/null)" || return 0
    glibc_prefix="$(canonical_path "$glibc_opt")" || return 0
    [ -x "$glibc_prefix/bin/localedef" ] || return 0
    locale_dir="$glibc_prefix/lib/locale"
    archive="$locale_dir/locale-archive"
    [ ! -s "$archive" ] || return 0
    mkdir -p "$locale_dir"
    if "$glibc_prefix/bin/localedef" -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1; then
        ok "created Homebrew glibc locale archive (no global LOCPATH needed)"
    else
        warn "could not create Homebrew glibc locale archive"
    fi
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
# brew_pkg_works <formula> — does the formula's main binary actually run?
# Formulas without a same-named binary count as working once brew lists them.
brew_pkg_works() {
    case "$1" in
        tmux)      bin_works tmux -V ;;
        coreutils) bin_works gtimeout --version ;;   # only g-prefixed binaries
        *)         bin_works "$1" --version || works "$BREW" list --versions "$1" ;;
    esac
}

install_brew_packages() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "brew packages (SKIP_BREW=1)"; return; }
    step "Installing CLI tools via brew: $BREW_PACKAGES"
    local pkg
    for pkg in $BREW_PACKAGES; do
        if brew_pkg_works "$pkg"; then
            skip "$pkg"
            continue
        fi
        echo "  → brew install $pkg"
        retry "$BREW" install "$pkg" || warn "brew install $pkg failed"
        hash -r
        if brew_pkg_works "$pkg"; then
            ok "$pkg installed"
        else
            warn "$pkg is not working after install — continuing anyway"
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
    hash -r
    if bin_works stow --version; then ok "stow installed (brew)"; return; fi
    if [ "$OS" = "Linux" ] && have perl && have make; then
        warn "brewed stow broken (bottle/perl mismatch) — using the GNU tarball"
        local tmp perl_bin="perl"
        tmp="$(new_tmp)"
        [ -x /usr/bin/perl ] && perl_bin="/usr/bin/perl"
        download "https://ftp.gnu.org/gnu/stow/stow-latest.tar.gz" "$tmp/stow.tar.gz" \
            || die "could not download GNU stow"
        tar xzf "$tmp/stow.tar.gz" -C "$tmp" || die "could not unpack GNU stow"
        (cd "$tmp"/stow-*/ \
            && ./configure --prefix="$HOME/.local" PERL="$perl_bin" >/dev/null \
            && make install >/dev/null) \
            || die "building GNU stow from the tarball failed"
        hash -r
        if bin_works stow --version; then ok "stow installed ($LOCAL_BIN/stow)"; return; fi
    fi
    die "stow is not working and all install methods failed"
}

# neovim: official prebuilt tarball on Linux (brew bottles only work in
# /home/linuxbrew/.linuxbrew; a user-local prefix means a slow, fragile
# source build). brew on macOS.
nvim_version_ok() {
    bin_works nvim --version || return 1
    local ver
    ver="$(nvim --version | first_version)"
    [ -n "$ver" ] && version_ge "$ver" "$NVIM_MIN_VERSION"
}

install_neovim() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "neovim (SKIP_BREW=1)"; return; }
    step "Installing neovim (>= $NVIM_MIN_VERSION)"
    if nvim_version_ok; then
        skip "neovim ($(command -v nvim))"
        return
    fi
    if bin_works nvim --version; then
        warn "nvim ($(command -v nvim)) is older than $NVIM_MIN_VERSION — installing a newer one"
    fi
    if [ "$OS" = "Darwin" ]; then
        retry "$BREW" install neovim || die "brew install neovim failed"
    else
        local narch tmp
        case "$ARCH" in
            x86_64)        narch="x86_64" ;;
            aarch64|arm64) narch="arm64" ;;
            *) die "unsupported architecture for prebuilt neovim: $ARCH" ;;
        esac
        tmp="$(new_tmp)"
        download "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-$narch.tar.gz" "$tmp/nvim.tar.gz" \
            || die "could not download neovim release"
        rm -rf "$LOCAL_OPT/nvim-linux-$narch"
        tar xzf "$tmp/nvim.tar.gz" -C "$LOCAL_OPT" || die "could not unpack neovim"
        ln -sf "$LOCAL_OPT/nvim-linux-$narch/bin/nvim" "$LOCAL_BIN/nvim"
    fi
    hash -r
    bin_works nvim --version || die "neovim installed but not running"
    nvim_version_ok \
        || die "installed neovim ($(command -v nvim)) is still older than $NVIM_MIN_VERSION"
    ok "neovim $(nvim --version | first_version) installed ($(command -v nvim))"
}

# tree-sitter CLI: required (not from npm) by nvim-treesitter's main branch
# to compile parsers. Prebuilt binaries need glibc >= 2.39; on older systems
# (e.g. Ubuntu 22.04) build it with a user-local rustup toolchain instead.
treesitter_version() { tree-sitter --version 2>/dev/null | first_version; }

treesitter_version_ok() {
    bin_works tree-sitter --version || return 1
    local ver
    ver="$(treesitter_version)"
    [ -n "$ver" ] && version_ge "$ver" "$TS_MIN_VERSION"
}

# Version of the SYSTEM glibc (empty on musl & co). Absolute paths first so
# a brewed glibc on PATH can't answer instead.
system_glibc_version() {
    local tool out
    for tool in /usr/bin/getconf getconf; do
        out="$("$tool" GNU_LIBC_VERSION 2>/dev/null | first_version)"
        if [ -n "$out" ]; then echo "$out"; return 0; fi
    done
    for tool in /usr/bin/ldd ldd; do
        out="$("$tool" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | tail -1 || true)"
        if [ -n "$out" ]; then echo "$out"; return 0; fi
    done
    return 0
}

install_treesitter_prebuilt() {
    local tarch tmp
    case "$ARCH" in
        x86_64)        tarch="x64" ;;
        aarch64|arm64) tarch="arm64" ;;
        *) die "unsupported architecture for prebuilt tree-sitter: $ARCH" ;;
    esac
    tmp="$(new_tmp)"
    download "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$tarch.gz" "$tmp/ts.gz" \
        || die "could not download tree-sitter CLI"
    gunzip -c "$tmp/ts.gz" >"$tmp/tree-sitter" || die "could not unpack tree-sitter CLI"
    chmod +x "$tmp/tree-sitter"
    # rm first: $LOCAL_BIN/tree-sitter may be a symlink into ~/.cargo/bin.
    rm -f "$LOCAL_BIN/tree-sitter"
    mv "$tmp/tree-sitter" "$LOCAL_BIN/tree-sitter"
}

install_treesitter_cargo() {
    ensure_rust
    # --no-default-features skips qjs-rt (QuickJS/bindgen, needs libclang);
    # nvim-treesitter only needs `tree-sitter build`.
    echo "  → cargo install tree-sitter-cli (a few minutes, one time)"
    retry cargo install tree-sitter-cli --locked --no-default-features \
        || die "cargo install tree-sitter-cli failed"
    ln -sf "$HOME/.cargo/bin/tree-sitter" "$LOCAL_BIN/tree-sitter"
}

install_treesitter_cli() {
    [ "${SKIP_BREW:-0}" = "1" ] && { skip "tree-sitter CLI (SKIP_BREW=1)"; return; }
    step "Installing tree-sitter CLI (>= $TS_MIN_VERSION)"
    if treesitter_version_ok; then
        skip "tree-sitter CLI $(treesitter_version) ($(command -v tree-sitter))"
        return
    fi
    if bin_works tree-sitter --version; then
        warn "tree-sitter CLI $(treesitter_version) is older than $TS_MIN_VERSION — upgrading"
    fi
    if [ "$OS" = "Darwin" ]; then
        retry "$BREW" install tree-sitter-cli || die "brew install tree-sitter-cli failed"
    else
        local glibc
        glibc="$(system_glibc_version)"
        if [ -n "$glibc" ] && version_ge "$glibc" "$TS_PREBUILD_GLIBC_MIN"; then
            install_treesitter_prebuilt
        else
            warn "system glibc ${glibc:-<unknown>} < $TS_PREBUILD_GLIBC_MIN — building tree-sitter CLI from source"
            install_treesitter_cargo
        fi
    fi
    hash -r
    bin_works tree-sitter --version || die "tree-sitter CLI installed but not running"
    treesitter_version_ok \
        || die "installed tree-sitter CLI ($(command -v tree-sitter)) is still older than $TS_MIN_VERSION"
    ok "tree-sitter CLI $(treesitter_version) installed"
}

ensure_rust() {
    # User-local Rust toolchain via rustup (no sudo, no mirrors).
    if [ -x "$HOME/.cargo/bin/cargo" ]; then
        export PATH="$HOME/.cargo/bin:$PATH"; hash -r
    fi
    bin_works cargo --version && return 0
    step "Installing Rust toolchain (rustup, minimal)"
    local rarch tmp
    case "$ARCH" in
        x86_64)        rarch="x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) rarch="aarch64-unknown-linux-gnu" ;;
        *) die "unsupported architecture for rustup: $ARCH" ;;
    esac
    tmp="$(new_tmp)"
    download "https://static.rust-lang.org/rustup/dist/$rarch/rustup-init" "$tmp/rustup-init" \
        || die "could not download rustup-init"
    chmod +x "$tmp/rustup-init"
    "$tmp/rustup-init" -y --quiet --profile minimal --default-toolchain stable \
        || die "rustup-init failed"
    export PATH="$HOME/.cargo/bin:$PATH"; hash -r
    bin_works cargo --version || die "rustup installed but cargo not working"
    ok "rust $(rustc --version | first_version) installed"
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
        git_clone "$DOTFILES_REPO" "$DOTFILES_DIR" \
            || die "could not clone $DOTFILES_REPO"
        ok "cloned $DOTFILES_REPO → $DOTFILES_DIR"
    fi
    # Canonicalise (symlinked $HOME, relative path, trailing slash, ...):
    # in_dotfiles compares resolved paths against this prefix.
    DOTFILES_DIR="$(canonical_path "$DOTFILES_DIR")" \
        || die "could not resolve the dotfiles directory"
}

# Back up any real file / foreign symlink in $HOME that would block stow.
stow_backup_conflicts() {
    local pkg="$1" rel target
    while IFS= read -r rel; do
        rel="${rel#./}"
        target="$HOME/$rel"
        [ -e "$target" ] || [ -L "$target" ] || continue
        # Resolves into the dotfiles repo (already stowed) → no conflict
        if [ -e "$target" ] && in_dotfiles "$target"; then continue; fi
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

# stow_pkg <package> — move conflicts aside, then (re)stow.
stow_pkg() {
    stow_backup_conflicts "$1"
    # --no-folding: symlink files, not directories — plugin managers
    # (fisher, tpm) must write into real dirs, not into the repo tree.
    stow --restow --no-folding --dir="$DOTFILES_DIR" --target="$HOME" "$1"
}

stow_packages() {
    [ "${SKIP_STOW:-0}" = "1" ] && { skip "stow (SKIP_STOW=1)"; return; }
    step "Stowing packages into \$HOME"
    bin_works stow --version || die "stow is not installed/working — install GNU stow or set SKIP_STOW=1"
    local pkg
    for pkg in $STOW_PACKAGES; do
        if [ ! -d "$DOTFILES_DIR/$pkg" ]; then
            warn "package '$pkg' has no directory in $DOTFILES_DIR — skipping"
            continue
        fi
        stow_pkg "$pkg" || die "stow failed for package '$pkg'"
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
    elif git_clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
        ok "cloned TPM"
    else
        warn "could not clone TPM — skipping tmux plugins"
        return
    fi

    step "Installing tmux plugins (headless)"
    # Use a private socket directory AND drop $TMUX so starting or stopping
    # this throwaway server never touches the user's active tmux server.
    # ($TMUX alone ignores TMUX_TMPDIR: when set, tmux resolves its socket
    # from $TMUX, so a bootstrap re-run from inside tmux would kill-server
    # the very session it runs in.)
    local tmux_tmpdir
    tmux_tmpdir="$(new_tmp)"
    env -u TMUX TMUX_TMPDIR="$tmux_tmpdir" tmux start-server \; new-session -d -s __bootstrap 2>/dev/null || true
    if retry env -u TMUX TMUX_TMPDIR="$tmux_tmpdir" "$TPM_DIR/bin/install_plugins"; then
        ok "tmux plugins installed"
    else
        warn "tmux plugin install failed — run '<prefix> + I' inside tmux later"
    fi
    env -u TMUX TMUX_TMPDIR="$tmux_tmpdir" tmux kill-server 2>/dev/null || true
}

# --------------------------------------------------------------------------
# 5. Fisher + fish plugins (reads ~/.config/fish/fish_plugins)
# --------------------------------------------------------------------------
# fish_plugins_in_sync <manifest> — fisher works and its installed set
# matches the manifest.
fish_plugins_in_sync() {
    fish -c 'functions -q fisher; and fisher list' 2>/dev/null | grep -v '^$' | sort -f \
        | cmp -s - <(grep -vE '^[[:space:]]*(#|$)' "$1" | sort -f)
}

# fisher treats ~/.config/fish/fish_plugins as mutable state and may delete
# or replace the stowed symlink — put it back.
restore_fish_plugins_link() {
    [ "${SKIP_STOW:-0}" = "1" ] && return 0
    [ -L "$HOME/.config/fish/fish_plugins" ] && return 0
    stow_pkg fish >/dev/null || warn "could not re-stow fish (fish_plugins link)"
}

# Last resort: forget fisher's ownership state and move every plugin file
# aside, so that a clean install cannot hit "conflicting files" errors.
wipe_fish_plugin_state() {
    fish -c 'set -e _fisher_plugins; for v in (set --universal --names | string match "_fisher_*_files"); set -e $v; end' 2>/dev/null || true
    # Plugin files = anything in these dirs NOT symlinked from the repo. Keep
    # repo-owned links; everything else goes to this run's backup directory
    # (fisher's state is gone, so plugin files and machine-local files can
    # no longer be told apart).
    local sub f backup_target moved=0
    for sub in functions conf.d completions themes; do
        [ -d "$HOME/.config/fish/$sub" ] || continue
        while IFS= read -r f; do
            in_dotfiles "$f" && continue          # stowed repo file — keep
            backup_target="$BACKUP_DIR/fish/.config/fish/$sub/$(basename "$f")"
            mkdir -p "$(dirname "$backup_target")"
            mv "$f" "$backup_target"
            moved=$((moved + 1))
        done < <(find "$HOME/.config/fish/$sub" -mindepth 1 -maxdepth 1)
    done
    if [ "$moved" -gt 0 ]; then
        warn "moved $moved file(s) from ~/.config/fish/{functions,conf.d,completions,themes}"
        warn "to $BACKUP_DIR/fish/.config/fish — plugins get reinstalled; restore any machine-local files by hand"
    fi
    TIDE_REINSTALLED=1   # tide was moved aside too → migrate_tide must re-apply
}

install_fish_plugins() {
    [ "${SKIP_FISH_PLUGINS:-0}" = "1" ] && { skip "fish plugins (SKIP_FISH_PLUGINS=1)"; return; }
    bin_works fish --version || { warn "fish not working — skipping fish plugins"; return; }
    step "Installing fisher + fish plugins"
    # Read the plugin manifest from the REPO, not the (symlinked) live file:
    # fisher treats ~/.config/fish/fish_plugins as mutable state and deletes
    # it outright when its own state (universal vars) is wiped.
    local manifest="$DOTFILES_DIR/fish/.config/fish/fish_plugins"
    [ -f "$manifest" ] || { warn "$manifest not found — skipping fish plugins"; return; }

    # Fast path: fisher works and the installed set matches the manifest.
    if fish_plugins_in_sync "$manifest"; then
        skip "fish plugins up to date"
        return
    fi

    # Gentle path: fisher itself works, the set merely differs (e.g. a plugin
    # was added to the manifest) — `fisher update` syncs with fish_plugins.
    if works fish -c 'functions -q fisher'; then
        restore_fish_plugins_link
        echo "  → fisher update (syncing with $manifest)"
        retry run_with_timeout 600 fish -c 'fisher update' >/dev/null || true
        restore_fish_plugins_link
        if fish_plugins_in_sync "$manifest"; then
            ok "fish plugins synced (fisher update)"
            return
        fi
        warn "fisher update did not converge — falling back to a clean reinstall"
    fi

    # Clean reinstall. Fetch fisher BEFORE wiping anything, so a flaky
    # network can't leave fish without plugins.
    local tmp fisher_src
    tmp="$(new_tmp)"
    fisher_src="$tmp/fisher.fish"
    if ! download "https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish" "$fisher_src"; then
        warn "could not download fisher — leaving fish plugins untouched"
        return
    fi

    # fisher keeps its ownership state in universal variables and refuses to
    # touch files it has no record of. Don't negotiate: wipe that state and
    # every plugin file, then do one clean install.
    warn "fisher state missing/stale — backing up and reinstalling plugins"
    wipe_fish_plugin_state

    # Source (not copy) fisher so it can install itself as a managed plugin.
    # Paths travel via the environment, so spaces in them are harmless.
    if retry run_with_timeout 600 env FISHER_SRC="$fisher_src" FISHER_MANIFEST="$manifest" \
        fish -c 'source $FISHER_SRC; fisher install (string match -rv "^\s*(#|\$)" <$FISHER_MANIFEST)'; then
        ok "fish plugins installed (see $manifest)"
    else
        warn "fisher failed — re-run 'fisher install (cat $manifest)' inside fish"
    fi
    # Bulk install drops fisher itself when it is running from a sourced
    # (not yet installed) file — install it explicitly.
    if ! works fish -c 'functions -q fisher'; then
        if FISHER_SRC="$fisher_src" fish -c 'source $FISHER_SRC; fisher install jorgebucaran/fisher'; then
            ok "fisher installed"
        else
            warn "could not install fisher itself"
        fi
    fi
    restore_fish_plugins_link
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
    # NB: tide seeds its own universal-variable defaults on first load, and
    # resets them again on every fresh tide install — so 'set -q tide_*'
    # can't distinguish defaults from a migrated config. Apply when:
    # TIDE_FORCE=1, our marker is missing, or tide was just reinstalled.
    if [ "${TIDE_FORCE:-0}" != "1" ] && [ "$TIDE_REINSTALLED" != "1" ] \
        && fish -c 'set -q _tide_dotfiles_migrated' 2>/dev/null; then
        skip "tide already configured (set TIDE_FORCE=1 to re-apply)"
        return
    fi
    if TIDE_VARS_FILE="$vars_file" fish -c 'source $TIDE_VARS_FILE; set -U _tide_dotfiles_migrated 1'; then
        ok "tide config applied (universal variables → ~/.config/fish/fish_variables)"
    else
        warn "failed to apply tide config"
    fi
}

# --------------------------------------------------------------------------
# 7. Default shell: exec fish from the login shell's rc file
# --------------------------------------------------------------------------
# No-sudo alternative to chsh: bash/zsh stays the login shell, and
# interactive sessions hand off to fish immediately. Escape hatches:
# `bash --norc` / `zsh -f` (over ssh: `ssh -t <host> bash --norc`), or
# NO_FISH=1 in the environment (NB: ssh does not forward local variables,
# so `NO_FISH=1 ssh <host>` does NOT work). The interactive guard is
# required because non-interactive ssh/scp/rsync shells also source ~/.bashrc.

# The account's real login shell ($SHELL lies inside tmux/fish sessions).
login_shell() {
    local sh=""
    if [ "$OS" = "Darwin" ]; then
        sh="$(dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $NF}' || true)"
    elif have getent; then
        sh="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7 || true)"
    fi
    printf '%s\n' "${sh:-${SHELL:-}}"
}

setup_default_shell() {
    [ "${SKIP_DEFAULT_SHELL:-0}" = "1" ] && { skip "default shell (SKIP_DEFAULT_SHELL=1)"; return; }
    step "Making fish the default interactive shell"
    local fish_bin="" candidate
    for candidate in \
        "$(command -v fish 2>/dev/null || true)" \
        "$LINUXBREW_DIR/bin/fish" \
        /usr/bin/fish /usr/local/bin/fish /opt/homebrew/bin/fish; do
        # Must actually run: exec-ing a broken fish would lock you out.
        if [ -n "$candidate" ] && [ -x "$candidate" ] && works "$candidate" --version; then
            fish_bin="$candidate"
            break
        fi
    done
    [ -n "$fish_bin" ] || { warn "no working fish found — skipping"; return; }

    local shell_name rc
    shell_name="$(basename "$(login_shell)")"
    case "$shell_name" in
        fish) skip "fish is already the login shell"; return ;;
        bash) rc="$HOME/.bashrc" ;;
        zsh)  rc="$HOME/.zshrc" ;;
        *)
            warn "unsupported login shell '${shell_name:-unknown}' — add 'exec $fish_bin' to its rc file by hand"
            return
            ;;
    esac

    if grep -qF "$SHELL_BLOCK_BEGIN" "$rc" 2>/dev/null; then
        if grep -qF "exec \"$fish_bin\"" "$rc"; then
            skip "fish exec block already in $rc"
            return
        fi
        # Block points at a different fish (path changed) — replace it.
        if ! grep -qF "$SHELL_BLOCK_END" "$rc"; then
            warn "$rc has a damaged fish exec block — fix it by hand"
            return
        fi
        local tmp
        tmp="$(new_tmp)"
        awk -v b="$SHELL_BLOCK_BEGIN" -v e="$SHELL_BLOCK_END" \
            '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$rc" >"$tmp/rc"
        cat "$tmp/rc" >"$rc"   # cat, not mv: keep symlink/permissions of $rc
        warn "replacing stale fish exec block in $rc"
    fi
    cat >>"$rc" <<EOF

$SHELL_BLOCK_BEGIN
# Hand interactive sessions over to fish. Plain shell: \`bash --norc\` / \`zsh -f\`.
if [[ \$- == *i* ]] && [[ -z "\${NO_FISH:-}" ]] && [[ -x "$fish_bin" ]]; then
    exec "$fish_bin"
fi
$SHELL_BLOCK_END
EOF
    ok "added fish exec block to $rc"
    # bash login shells (ssh, macOS Terminal) only read ~/.bashrc when a
    # profile file sources it.
    if [ "$shell_name" = "bash" ] \
        && ! grep -qs 'bashrc' "$HOME/.bash_profile" "$HOME/.bash_login" "$HOME/.profile"; then
        warn "no ~/.bash_profile or ~/.profile sources ~/.bashrc — login shells will not reach fish"
        warn "add to ~/.bash_profile:  [ -f ~/.bashrc ] && . ~/.bashrc"
    fi
}

# --------------------------------------------------------------------------
# 8. nvim plugin restore (best effort)
# --------------------------------------------------------------------------
sync_nvim() {
    [ "${SKIP_NVIM_SYNC:-0}" = "1" ] && { skip "nvim sync (SKIP_NVIM_SYNC=1)"; return; }
    bin_works nvim --version || return 0
    step "Installing neovim plugins (lazy.nvim restore from lockfile, headless)"
    # NB: `restore`, not `sync` — sync also *updates* past lazy-lock.json.
    if ! run_with_timeout 600 nvim --headless "+Lazy! restore" +qa </dev/null >/dev/null 2>&1; then
        warn "headless lazy.nvim restore failed — open nvim once and run :Lazy restore"
        return
    fi
    # Second headless run: lets the treesitter config build parsers (it waits
    # when headless) and acts as a startup sanity check.
    # NB: nvim exits 0 on most plugin errors, so this is only a smoke test.
    if run_with_timeout 600 nvim --headless +qa </dev/null >/dev/null 2>&1; then
        ok "neovim plugin restore ran (lazy-lock.json) — check :Lazy / :checkhealth if anything looks off"
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

    TMP_ROOT="$(mktemp -d)"
    trap 'rm -rf "$TMP_ROOT"' EXIT

    preflight

    # 1-2. Tools
    setup_brew
    install_brew_packages
    install_stow
    fix_brew_glibc_locale
    install_neovim
    install_treesitter_cli

    # 3. Dotfiles
    clone_dotfiles
    stow_packages

    # 4-8. Per-tool setup
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
  • Log in again — interactive shells now hand off to fish automatically
    (plain bash: \`bash --norc\`; over ssh: \`ssh -t <host> bash --norc\`)
  • Or start right away:              $fish_path
  • Tmux with everything loaded:      tm
EOF
}

main "$@"
