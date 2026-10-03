#!/usr/bin/env bash
# ============================================================
#
# kernel.sh
#
# Выбор ядра и формирование списка его пакетов
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__KERNEL_SH:-}" ]] && return
readonly __KERNEL_SH=1

# Функция для получения списка пакетов выбранного ядра
kernel_packages() {
    case "$1" in
        2) echo "linux-zen linux-zen-headers" ;;
        3) echo "linux-lts linux-lts-headers" ;;
        *) echo "linux linux-headers" ;;
    esac
}

# Функция для выбора ядра (автоустановка)
select_kernel_auto() {
    CHOICE=$(whiptail --title "Выбор ядра системы" \
                      --menu "Выберите ядро:" 10 60 3 \
                      "1" "Linux (обычное)" \
                      "2" "Linux-zen (производительное)" \
                      "3" "Linux-lts (стабильное)" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo "$CHOICE"
    return 0
}

# Функция для выбора ядра (ручная установка)
# Диалог общий с автоустановкой
select_kernel_manual() {
    select_kernel_auto
}

