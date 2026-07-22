function claude --description "Claude Code wrapper with EVAS / OpenRouter routing"
    set -l choice ""

    # Parse arguments and safely remove the custom flags from $argv
    if set -l idx (contains -i -- "--evas" $argv)
        set -e argv[$idx]
        set choice "2"
    else if set -l idx (contains -i -- "--or" $argv)
        set -e argv[$idx]
        set choice "3"
    else if set -l idx (contains -i -- "--acc" $argv)
        set -e argv[$idx]
        set choice "1"
    else
        # Interactive menu fallback
        echo "Select Claude Code operating mode:"
        echo "  [1] Official Account Login (Default)"
        echo "  [2] EVAS (Randomized Key)"
        echo "  [3] OpenRouter (Actual API)"

        # [CRITICAL FIX]: Removed '-l' so it updates the function-scoped variable,
        # not a temporary block-scoped one.
        read -P "Enter 1, 2 or 3 (Press Enter for 1): " choice

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

    # Model overrides for the EVAS proxy (deepseek / glm slugs)
    set -l evas_model_env \
        ANTHROPIC_MODEL="z-ai/glm-5.2" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="z-ai/glm-5.2" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="deepseek/deepseek-v4-pro" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="deepseek/deepseek-v4-flash" \
        CLAUDE_CODE_SUBAGENT_MODEL="deepseek/deepseek-v4-pro" \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
        ANTHROPIC_API_KEY=""

    # Model overrides for the real OpenRouter API (real Claude via OpenRouter)
    set -l or_model_env \
        ANTHROPIC_MODEL="moonshotai/kimi-k3" \
        ANTHROPIC_DEFAULT_OPUS_MODEL="moonshotai/kimi-k3" \
        ANTHROPIC_DEFAULT_SONNET_MODEL="z-ai/glm-5.2" \
        ANTHROPIC_DEFAULT_HAIKU_MODEL="moonshotai/kimi-k2.6" \
        CLAUDE_CODE_SUBAGENT_MODEL="z-ai/glm-5.2" \
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1" \
        ANTHROPIC_API_KEY=""

    # Routing execution logic based on user choice
    if test "$choice" = "2"
        # Ensure the EVAS key is loaded from the environment/secrets file
        if not set -q EVAS_API_KEY; or test -z "$EVAS_API_KEY"
            echo "Error: EVAS_API_KEY not set."
            echo "Please ensure it is defined in ~/.config/fish/secrets.fish"
            return 1
        end

        echo "=> [EVAS Mode] Using EVAS_API_KEY: "(string sub -l 20 $EVAS_API_KEY)"..."

        env ANTHROPIC_BASE_URL="https://api.evas.ai" \
            ANTHROPIC_AUTH_TOKEN=$EVAS_API_KEY \
            $evas_model_env \
            $claude_bin $argv
    else if test "$choice" = "3"
        # Real OpenRouter API, single key exported as OPENROUTER_API_KEY
        if not set -q OPENROUTER_API_KEY; or test -z "$OPENROUTER_API_KEY"
            echo "Error: OPENROUTER_API_KEY not set."
            echo "Please export your OpenRouter key as OPENROUTER_API_KEY."
            return 1
        end

        echo "=> [OpenRouter Mode] Using OPENROUTER_API_KEY: "(string sub -l 20 $OPENROUTER_API_KEY)"..."

        env ANTHROPIC_BASE_URL="https://openrouter.ai/api" \
            ANTHROPIC_AUTH_TOKEN=$OPENROUTER_API_KEY \
            $or_model_env \
            $claude_bin $argv
    else
        echo "=> [Official Account Mode]"
        $claude_bin $argv
    end
end
