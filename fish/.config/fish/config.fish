# ~/.config/fish/config.fish

# Load Secrets
if test -f ~/.config/fish/secrets.fish
    source ~/.config/fish/secrets.fish
end

# No Greetings
function fish_greeting
end

# Theme
set -g fish_prompt_pwd_dir_length 1
set -g theme_display_user yes
set -g theme_hide_hostname no
set -g theme_hostname always

# Preferred Editor
if status --is-interactive
    if test -n "$SSH_CONNECTION"
        set -gx EDITOR vim
    else
        set -gx EDITOR nvim
    end
end

# Universal Homebrew Setup
set -l brew_paths \
    "/opt/homebrew/bin/brew" \
    "/usr/local/bin/brew" \
    "/home/linuxbrew/.linuxbrew/bin/brew" \
    "$HOME/.linuxbrew/bin/brew"

for brew_exe in $brew_paths
    if test -f $brew_exe
        eval ($brew_exe shellenv)
        break
    end
end

# OS-Specific Configs
if test (uname) = "Darwin"
    # Homebrew Paths (Apple Silicon)
    if test -d /opt/homebrew/bin
        fish_add_path /opt/homebrew/bin
        fish_add_path /opt/homebrew/opt/node@22/bin
    end

    # Obsidian-nvim
    alias on 'nvim ~/Documents/notes'
    alias oh 'nvim ~/Documents/notes/1726823130-heap-file.md'

    # Kitty SSH
    if test "$TERM" = "xterm-kitty"; or type -q kitty
        alias ssh 'kitty +kitten ssh'
    end
end

# --- pipx ---
fish_add_path "$HOME/.local/bin" # Adds user's local bin, good for pipx installed tools

# lsd
if type -q lsd
    alias ls 'lsd'
end

# Tmux
alias ta='tmux attach-session -t'
alias tl='tmux list-sessions'
alias tn='tmux new-session -s'
alias tk='tmux kill-session -t'
alias tka='tmux kill-server'
alias tm='tmux attach-session -t main 2>/dev/null || tmux new-session -s main'

# Proxy
function proxy
    echo "🌐 Select Proxy Profile:"
    echo "   [1] 🏢 Company (iPhone Hotspot -> 172.22.100.156)"
    echo "   [2] 🏠 Home (Mac Surge -> 127.0.0.1)"
    echo "   [0] ❌ Cancel"

    read -l -P "👉 Enter choice [1]: " choice

    # Default: 1
    if test -z "$choice"
        set choice 1
    end

    switch $choice
        case 1
            # --- Company (iPhone) ---
            set -gx proxy_host "172.22.100.156"
            set -gx proxy_http_port "6154"
            set -gx proxy_socks_port "6153"
            set -gx proxy_type "Company (iPhone)"
        case 2
            # --- Home (Mac Surge) ---
            set -gx proxy_host "127.0.0.1"
            set -gx proxy_http_port "6152"
            set -gx proxy_socks_port "6153"
            set -gx proxy_type "Home (Surge)"
        case 0
            echo "Operation cancelled."
            return 0
        case '*'
            echo "Invalid choice."
            return 1
    end

    set -gx http_proxy "http://$proxy_host:$proxy_http_port"
    set -gx https_proxy "http://$proxy_host:$proxy_http_port"
    set -gx HTTP_PROXY "http://$proxy_host:$proxy_http_port"
    set -gx HTTPS_PROXY "http://$proxy_host:$proxy_http_port"

    set -gx all_proxy "socks5://$proxy_host:$proxy_socks_port"
    set -gx ALL_PROXY "socks5://$proxy_host:$proxy_socks_port"

    set -l no_proxy_list "localhost,127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,172.22.0.0/16"

    set -gx no_proxy $no_proxy_list
    set -gx NO_PROXY $no_proxy_list

    echo "✅ Proxy Enabled [$proxy_type]:"
    echo "   HTTP/HTTPS -> $proxy_host:$proxy_http_port"
    echo "   SOCKS5     -> $proxy_host:$proxy_socks_port"
end

function unproxy
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy

    set -e HTTP_PROXY
    set -e HTTPS_PROXY
    set -e ALL_PROXY
    set -e NO_PROXY

    set -e proxy_host
    set -e proxy_http_port
    set -e proxy_socks_port

    echo "🚫 Proxy Disabled"
end
