#!/usr/bin/env bash
# ============================================================
#
# ui.sh
#
# Диалоги и служебные функции интерфейса whiptail
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__UI_SH:-}" ]] && return
readonly __UI_SH=1

# Ширина терминала для диалогов whiptail, минимум 80 колонок
dialog_width() {
    local cols
    cols=$(tput cols 2>/dev/null)
    case "$cols" in
        ''|*[!0-9]*) cols=80 ;;
    esac
    if [ "$cols" -lt 80 ]; then
        cols=80
    fi
    echo "$cols"
}

# Функция для проверки наличия whiptail
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        clear
        echo -e "\033[1;33mWhiptail не установлен. Устанавливаю...\033[0m"
        pacman -S --noconfirm libnewt >/dev/null 2>&1
    fi
}
