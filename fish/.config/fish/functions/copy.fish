function copy --description 'Copy input to client clipboard using OSC 52'
    if count $argv > /dev/null
        set input (cat $argv)
    else
        set input (cat)
    end

    set -l b64 (echo -n "$input" | base64 | string join '')

    printf "\e]52;c;%s\a" "$b64"
end
