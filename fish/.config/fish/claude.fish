function claude --description "Claude Code wrapper with OpenRouter key rotation"
    set -l secrets_file ~/.config/fish/secrets.fish
    if test -f $secrets_file
        source $secrets_file
    end

    if not set -q OPENROUTER_KEYS; or test (count $OPENROUTER_KEYS) -eq 0
        echo "Error: OPENROUTER_KEYS array not found or empty."
        echo "Please define 'set -g OPENROUTER_KEYS ...' in $secrets_file"
        return 1
    end

    set -l random_key (random choice $OPENROUTER_KEYS)
    set -l choice ""

    if contains -- "--or" $argv
        set -l idx (contains -i -- "--or" $argv)
        set -e argv[$idx]
        set choice "2"
    else if contains -- "--acc" $argv
        set -l idx (contains -i -- "--acc" $argv)
        set -e argv[$idx]
        set choice "1"
    else
        # 5. Interactive menu
        echo "Select Claude Code operating mode:"
        echo "  [1] Official Account Login (Default)"
        echo "  [2] OpenRouter (Randomized Key)"
        read -l -p 'echo "Enter 1 or 2 (Press Enter for 1): "' choice
    end

    set -l claude_bin (command -v claude)

    if test "$choice" = "2"
        echo "=> [OpenRouter Mode] Assigned random key: "(string sub -l 20 $random_key)"..."
 
        env ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
            ANTHROPIC_AUTH_TOKEN=$random_key \
            ANTHROPIC_API_KEY="" \
            $claude_bin $argv
    else
        echo "=> [Official Account Mode]"
        $claude_bin $argv
    end
end
