#!/bin/sh

kitty_config="$HOME/.config/kitty/kitty.conf"
themes_dir="$HOME/.config/kitty/themes"

echo "$RICE"

if [ -n "$RICE" ] && [ -f "$themes_dir/$RICE.conf" ]; then
  theme="themes/$RICE.conf"
else
  theme="themes/default.conf"
fi

if grep -q '^include[[:space:]]\+themes/' "$kitty_config"; then
  sed -i -e "s|^include[[:space:]]\+themes/.*|include $theme|" \
    "$kitty_config"
else
  printf '\ninclude %s\n' "$theme" >>"$kitty_config"
fi
