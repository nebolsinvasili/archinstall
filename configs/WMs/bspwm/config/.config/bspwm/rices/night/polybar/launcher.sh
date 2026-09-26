#!/usr/bin/env sh

CONFIG="$HOME/.config/bspwm/rices/$RICE/polybar/config.ini"
BARS=(left right center tray poweroff)  # перечень секций в конфиге

# Получаем список мониторов
MONITORS=$(polybar --list-monitors | cut -d":" -f1)

# Запуск каждого бара на каждом мониторе
for MON in $MONITORS; do
    for BAR in "${BARS[@]}"; do
        MONITOR=$MON polybar -q "$BAR" -c "$CONFIG" &
    done
done

