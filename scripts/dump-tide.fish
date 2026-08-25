#!/usr/bin/env fish
# dump-tide.fish — regenerate fish/.config/fish/tide_vars.fish from the
# current machine's live tide configuration.
#
# Usage (from anywhere):
#   fish ~/.dotfiles/scripts/dump-tide.fish > ~/.dotfiles/fish/.config/fish/tide_vars.fish

echo "# tide_vars.fish — snapshot of tide (prompt theme) universal variables."
echo "#"
echo "# Applied ONCE by ~/.dotfiles/bootstrap.sh on fresh machines (universal"
echo "# variables persist in ~/.config/fish/fish_variables afterwards, so this"
echo "# file is NOT auto-sourced on every shell startup — re-setting them each"
echo "# launch would make interactive tweaks impossible)."
echo "#"
echo "# To re-apply manually:   fish -c 'source ~/.config/fish/tide_vars.fish'"
echo "# To regenerate after changing your prompt:  fish ~/.dotfiles/scripts/dump-tide.fish > ~/.dotfiles/fish/.config/fish/tide_vars.fish"
echo ""

for var in (set --universal --names | string match 'tide_*')
    set -l vals $$var
    if test (count $vals) -eq 0
        # Zero-element variable (set, but empty) — `set -U name` preserves that.
        echo "set -U $var"
    else
        # string escape prints one line per element; join with spaces.
        echo "set -U $var "(string join " " -- (string escape -- $vals))
    end
end
