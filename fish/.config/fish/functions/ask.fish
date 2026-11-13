function ask --description 'Pi CLI single question, plain-text (man-page style) answer'
    pi -p --no-session --no-tools \
        --no-context-files --no-skills --no-extensions \
        --model gpt-6.1-sol --thinking medium \
        --system-prompt (string collect < ~/.pi/agent/ask-prompt.txt) \
        -- $argv
end
