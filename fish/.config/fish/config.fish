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
    if type -q nvim
        set -gx EDITOR nvim
    else
        set -gx EDITOR vim
    end
    set -gx GIT_EDITOR $EDITOR
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

    # Kitty SSH
    if test "$TERM" = "xterm-kitty"; or type -q kitty
        alias ssh 'kitty +kitten ssh'
    end
end

# --- Obsidian Vault Paths (Cross-Platform) ---
if test -n "$WSL_DISTRO_NAME"
    set -g VAULT_PATH "/mnt/c/Users/joe.qiu/Desktop/notes"
else
    set -g VAULT_PATH "$HOME/Documents/notes"
end

alias on "nvim $VAULT_PATH"
alias oh "nvim $VAULT_PATH/1726823130-heap-file.md"

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

