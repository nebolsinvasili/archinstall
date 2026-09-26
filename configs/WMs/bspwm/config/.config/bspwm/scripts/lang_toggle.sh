#!/usr/bin/env bash

LANG=$(printf "English (US)\nРусский (RU)" | rofi \
  -dmenu \
  -p "Keyboard Layout" \
  -theme /home/nebolsinvasili/dotfiles/configs/wm-config/config/bspwm/config/rofi/themes/LangSelect.rasi)

case "$LANG" in
    *US*) setxkbmap us ;;
    *RU*) setxkbmap ru ;;
esac
