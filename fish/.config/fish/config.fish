# ~/.config/fish/config.fish

# Load Secrets
if test -f ~/.config/fish/secrets.fish
    source ~/.config/fish/secrets.fish
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

# Welcome message / MOTD can be configured via `fish_greeting` function
function fish_greeting
  echo "Welcome back, Joe!"
end
