#!/usr/bin/env bash
# ============================================================
#
# locale.sh
#
# Язык, регион, локали и настройка консоли
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__LOCALE_SH:-}" ]] && return
readonly __LOCALE_SH=1

# Функция для выбора языка системы (автоустановка)
select_language() {
    CHOICE=$(whiptail --title "Выбор языка системы" \
                      --menu "Выберите язык системы:" 12 60 6 \
                      "1" "Русский (ru_RU.UTF-8)" \
                      "2" "Українська (uk_UA.UTF-8)" \
                      "3" "Беларуская (be_BY.UTF-8)" \
                      "4" "Deutsch (de_DE.UTF-8)" \
                      "5" "Polski (pl_PL.UTF-8)" \
                      "6" "English (en_US.UTF-8)" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    case $CHOICE in
        1) echo "ru_RU.UTF-8" ;;
        2) echo "uk_UA.UTF-8" ;;
        3) echo "be_BY.UTF-8" ;;
        4) echo "de_DE.UTF-8" ;;
        5) echo "pl_PL.UTF-8" ;;
        6) echo "en_US.UTF-8" ;;
        *) echo "" ;;
    esac
    return 0
}

# Функция для выбора региона (автоустановка)
select_region_dialog() {
    local retry=$1
    REGIONS=()
    while IFS= read -r region; do
        region=$(basename "$region")
        if [[ "$region" != "posix" ]] && [[ "$region" != "right" ]] && [[ "$region" != "SystemV" ]] && [[ "$region" != "Etc" ]] && [[ "$region" != "GMT"* ]] && [[ "$region" != "US" ]] && [[ "$region" != "Canada" ]] && [[ "$region" != "Mexico" ]] && [[ "$region" != "Brazil" ]] && [[ "$region" != "Chile" ]] && [[ "$region" != "Cuba" ]] && [[ "$region" != "Jamaica" ]]; then
            REGIONS+=("$region" "")
        fi
    done < <(find /usr/share/zoneinfo -maxdepth 1 -type d | grep -v "/$" | sort)

    SELECTED_REGION=$(whiptail --title "Выбор региона" \
                               --menu "" 20 60 15 \
                               "${REGIONS[@]}" \
                               3>&1 1>&2 2>&3 \
                               --ok-button "Выбрать" --cancel-button "Отмена")

    if [ $? -ne 0 ] || [ -z "$SELECTED_REGION" ]; then
        return 1
    fi

    CITIES=()
    while IFS= read -r city; do
        city=$(basename "$city")
        CITIES+=("$city" "")
    done < <(find "/usr/share/zoneinfo/$SELECTED_REGION" -maxdepth 1 -type f | sort)

    SELECTED_CITY=$(whiptail --title "Выбор города" \
                             --menu "" 20 60 15 \
                             "${CITIES[@]}" \
                             3>&1 1>&2 2>&3 \
                             --ok-button "Выбрать" --cancel-button "Назад")

    if [ $? -ne 0 ] || [ -z "$SELECTED_CITY" ]; then
        "$retry"
        return $?
    fi

    echo "$SELECTED_REGION/$SELECTED_CITY"
    return 0
}

# Функция для выбора региона (автоустановка)
select_region() {
    select_region_dialog select_region
}

# Функция для выбора региона (ручная установка)
select_region_manual() {
    select_region_dialog select_region_manual
}

# Функция для настройки локалей
configure_locales() {
    local LANG_CHOICE=$1
    sed -i 's/^[^#].*UTF-8/#&/g' /etc/locale.gen 2>/dev/null
    sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /etc/locale.gen 2>/dev/null
    case $LANG_CHOICE in
        "ru_RU.UTF-8") sed -i 's/#ru_RU.UTF-8/ru_RU.UTF-8/g' /etc/locale.gen 2>/dev/null ;;
        "uk_UA.UTF-8") sed -i 's/#uk_UA.UTF-8/uk_UA.UTF-8/g' /etc/locale.gen 2>/dev/null ;;
        "be_BY.UTF-8") sed -i 's/#be_BY.UTF-8/be_BY.UTF-8/g' /etc/locale.gen 2>/dev/null ;;
        "de_DE.UTF-8") sed -i 's/#de_DE.UTF-8/de_DE.UTF-8/g' /etc/locale.gen 2>/dev/null ;;
        "pl_PL.UTF-8") sed -i 's/#pl_PL.UTF-8/pl_PL.UTF-8/g' /etc/locale.gen 2>/dev/null ;;
        "en_US.UTF-8") ;;
    esac
    locale-gen >/dev/null 2>&1
    echo "LANG=$LANG_CHOICE" > /etc/locale.conf
}

# Функция для настройки vconsole.conf в зависимости от языка
configure_vconsole() {
    local target=$1
    local LANG_CHOICE=$2

    case $LANG_CHOICE in
        "ru_RU.UTF-8")
            echo "KEYMAP=ru" > "$target/etc/vconsole.conf"
            echo "FONT=cyr-sun16" >> "$target/etc/vconsole.conf"
            ;;
        "uk_UA.UTF-8")
            echo "KEYMAP=uk" > "$target/etc/vconsole.conf"
            echo "FONT=cyr-sun16" >> "$target/etc/vconsole.conf"
            ;;
        "be_BY.UTF-8")
            echo "KEYMAP=by" > "$target/etc/vconsole.conf"
            echo "FONT=cyr-sun16" >> "$target/etc/vconsole.conf"
            ;;
        "de_DE.UTF-8")
            echo "KEYMAP=de-latin1" > "$target/etc/vconsole.conf"
            echo "FONT=Lat2-Terminus16" >> "$target/etc/vconsole.conf"
            ;;
        "pl_PL.UTF-8")
            echo "KEYMAP=pl" > "$target/etc/vconsole.conf"
            echo "FONT=Lat2-Terminus16" >> "$target/etc/vconsole.conf"
            ;;
        "en_US.UTF-8")
            echo "KEYMAP=us" > "$target/etc/vconsole.conf"
            ;;
        *)
            echo "KEYMAP=ru" > "$target/etc/vconsole.conf"
            echo "FONT=cyr-sun16" >> "$target/etc/vconsole.conf"
            ;;
    esac
}

# Функция для выбора языка (ручная установка)
# Диалог общий с автоустановкой
select_language_manual() {
    select_language
}
