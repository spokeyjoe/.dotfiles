function claude --description "Claude Code wrapper with OpenRouter key rotation"
    # Ensure keys are successfully loaded from the environment/secrets file
    if not set -q OPENROUTER_KEYS; or test (count $OPENROUTER_KEYS) -eq 0
        echo "Error: OPENROUTER_KEYS array not found or empty."
        echo "Please ensure they are defined in ~/.config/fish/secrets.fish"
        return 1
    end

    set -l random_key (random choice $OPENROUTER_KEYS)
    set -l choice ""

    # Parse arguments and safely remove the custom flags from $argv
    if set -l idx (contains -i -- "--or" $argv)
        set -e argv[$idx]
        set choice "2"
    else if set -l idx (contains -i -- "--acc" $argv)
        set -e argv[$idx]
        set choice "1"
    else
        # Interactive menu fallback
        echo "Select Claude Code operating mode:"
        echo "  [1] Official Account Login (Default)"
        echo "  [2] OpenRouter (Randomized Key)"

        # [CRITICAL FIX]: Removed '-l' so it updates the function-scoped variable, 
        # not a temporary block-scoped one.
        read -P "Enter 1 or 2 (Press Enter for 1): " choice

        # Strip any accidental whitespace or hidden newline characters
        set choice (string trim "$choice")

        # Explicitly handle the empty "Enter" case
        if test -z "$choice"
            set choice "1"
        end
    end

    # Get the actual path to the claude CLI binary
    set -l claude_bin (command -v claude)

    if test -z "$claude_bin"
        echo "Error: claude binary not found in PATH."
        return 1
    end

    # Routing execution logic based on user choice
    if test "$choice" = "2"
        echo "=> [OpenRouter Mode] Assigned random key: "(string sub -l 20 $random_key)"..."

        env ANTHROPIC_BASE_URL="https://api.evas.ai" \
            ANTHROPIC_AUTH_TOKEN=$random_key \
            ANTHROPIC_API_KEY="" \
            $claude_bin $argv
    else
        echo "=> [Official Account Mode]"
        $claude_bin $argv
    end
end
