#!/usr/bin/env bash
# ============================================================
#
# menus.sh
#
# Меню установщика и отображение хода процесса
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__MENUS_SH:-}" ]] && return
readonly __MENUS_SH=1

# Функция для отображения процесса настройки через прогресс-бар
show_setup_process() {
    cleanup_mounts

    SETUP_LOG=$(mktemp)

    {
        echo "10" > "$SETUP_LOG"
        sed -i s/'#en_US.UTF-8'/'en_US.UTF-8'/g /etc/locale.gen 2>/dev/null
        sed -i s/'#ru_RU.UTF-8'/'ru_RU.UTF-8'/g /etc/locale.gen 2>/dev/null
        echo 'LANG=ru_RU.UTF-8' > /etc/locale.conf 2>/dev/null
        sleep 0.3

        echo "30" > "$SETUP_LOG"
        echo 'KEYMAP=ru' > /etc/vconsole.conf 2>/dev/null
        echo 'FONT=cyr-sun16' >> /etc/vconsole.conf 2>/dev/null
        setfont cyr-sun16 2>/dev/null
        sleep 0.3

        echo "60" > "$SETUP_LOG"
        locale-gen >/dev/null 2>&1
        sleep 0.3

        echo "85" > "$SETUP_LOG"
        systemctl restart dhcpcd 2>/dev/null
        dhcpcd 2>/dev/null &
        sleep 0.5

        echo "100" > "$SETUP_LOG"
        sleep 0.5

        rm -f "$SETUP_LOG"
    } &

    while [ -f "$SETUP_LOG" ]; do
        if [ -f "$SETUP_LOG" ]; then
            PROGRESS=$(cat "$SETUP_LOG" 2>/dev/null | grep -E '^[0-9]+$' | tail -1)
            if [ -z "$PROGRESS" ]; then
                PROGRESS=0
            fi
            echo "$PROGRESS" | whiptail --title "EasyArch Установщик" \
                                        --gauge "Loading" 8 60 $PROGRESS \
                                        2>/dev/null
        fi
        sleep 0.1
    done
}

# Функция для выбора типа установки
select_install_type() {
    while true; do
        CHOICE=$(whiptail --title "EasyArch Установщик" \
                          --menu "Выберите действие:" 16 60 4 \
                          "1" "Авто установка с очисткой диска" \
                          "2" "Авто установка рядом с другой OS" \
                          "3" "Ручная установка" \
                          "4" "Сортировать зеркала" \
                          3>&1 1>&2 2>&3 \
                          --ok-button "Выбрать" --cancel-button "Exit")

        if [ $? -ne 0 ]; then
            whiptail --title "Выход" --msgbox "Выход из установщика EasyArch." 8 40
            exit 0
        fi

        case $CHOICE in
            1) INSTALL_TYPE="clean"; return 0 ;;
            2) INSTALL_TYPE="side"; return 0 ;;
            3) INSTALL_TYPE="manual"; return 0 ;;
            4) INSTALL_TYPE="mirrors"; return 0 ;;
            *) whiptail --title "Ошибка" --msgbox "Пожалуйста, выберите опцию" 8 40 ;;
        esac
    done
}

# Функция для отображения главного меню настроек (автоустановка)
show_settings_menu() {
    # Инициализация переменных с пустыми значениями (не выбрано)
    DISK=""
    LANGUAGE=""
    REGION=""
    ENCRYPTION="none"
    DESKTOP_LIST=""
    SWAP_SIZE="2"
    USERNAME=""
    USERPASS=""
    ROOTPASS=""
    KERNEL="1"
    GPU_DRIVERS="0"
    DISPLAY_MANAGER="1"

    while true; do
        # Отображение значения диска
        if [ -n "$DISK" ]; then
            DISK_NAME=$(basename "$DISK" 2>/dev/null)
            DISK_VALUE="/dev/$DISK_NAME"
        else
            DISK_VALUE="Не выбран"
        fi

        # Отображение значения языка
        if [ -n "$LANGUAGE" ]; then
            case "$LANGUAGE" in
                "ru_RU.UTF-8") LANG_VALUE="Русский" ;;
                "uk_UA.UTF-8") LANG_VALUE="Українська" ;;
                "be_BY.UTF-8") LANG_VALUE="Беларуская" ;;
                "de_DE.UTF-8") LANG_VALUE="Deutsch" ;;
                "pl_PL.UTF-8") LANG_VALUE="Polski" ;;
                "en_US.UTF-8") LANG_VALUE="English" ;;
                *) LANG_VALUE="Не выбран" ;;
            esac
        else
            LANG_VALUE="Не выбран"
        fi

        # Отображение значения региона
        if [ -n "$REGION" ]; then
            REGION_VALUE="$REGION"
        else
            REGION_VALUE="Не выбран"
        fi

        # Отображение значения шифрования
        case "$ENCRYPTION" in
            "none") ENC_VALUE="Без шифрования" ;;
            "luks1") ENC_VALUE="LUKS" ;;
            "luks2") ENC_VALUE="LUKS2" ;;
            *) ENC_VALUE="Не выбрано" ;;
        esac

        # Отображение значения рабочих столов и WM
        DIALOG_W=$(dialog_width)
        DESKTOP_VALUE=$(desktops_menu_value "$DESKTOP_LIST" $(( DIALOG_W - 30 )))

        # Отображение значения swap
        if [ "$SWAP_SIZE" = "0" ]; then
            SWAP_VALUE="Без swap"
        else
            SWAP_VALUE="${SWAP_SIZE} GB"
        fi

        # Отображение значения пользователя
        if [ -n "$USERNAME" ]; then
            USER_VALUE="$USERNAME"
        else
            USER_VALUE="Не создан"
        fi

        # Отображение значения ядра
        case "$KERNEL" in
            "1") KERNEL_VALUE="Linux (обычное)" ;;
            "2") KERNEL_VALUE="Linux-zen (производительное)" ;;
            "3") KERNEL_VALUE="Linux-lts (стабильное)" ;;
            *) KERNEL_VALUE="Не выбрано" ;;
        esac

        # Отображение значения драйверов GPU
        case "$GPU_DRIVERS" in
            "1") GPU_VALUE="Intel" ;;
            "2") GPU_VALUE="AMD" ;;
            "3") GPU_VALUE="Nvidia dkms" ;;
            "4") GPU_VALUE="Nvidia open" ;;
            "0") GPU_VALUE="Не устанавливать" ;;
            *) GPU_VALUE="Не выбрано" ;;
        esac

        # Отображение значения диспетчера входа
        DM_VALUE=$(display_manager_name "$DISPLAY_MANAGER")

        MENU_CHOICE=$(whiptail --title "EasyArch Установщик - Настройки" \
                               --menu "\n\n\n" 22 "$DIALOG_W" 11 \
                               "1" "Диск (${DISK_VALUE})" \
                               "2" "Язык (${LANG_VALUE})" \
                               "3" "Регион (${REGION_VALUE})" \
                               "4" "Шифрование (${ENC_VALUE})" \
                               "5" "Рабочий стол / WM (${DESKTOP_VALUE})" \
                               "6" "Swap (${SWAP_VALUE})" \
                               "7" "Пользователь (${USER_VALUE})" \
                               "8" "Ядро (${KERNEL_VALUE})" \
                               "9" "Драйверы GPU (${GPU_VALUE})" \
                               "10" "Диспетчер входа (${DM_VALUE})" \
                               "11" "Начать установку" \
                               3>&1 1>&2 2>&3 \
                               --ok-button "Выбрать" --cancel-button "Отмена")

        case $? in
            0)
                case $MENU_CHOICE in
                    1)
                        NEW_DISK=$(select_disk)
                        if [ $? -eq 0 ] && [ -n "$NEW_DISK" ]; then
                            DISK="$NEW_DISK"
                        fi
                        ;;
                    2)
                        NEW_LANG=$(select_language)
                        if [ $? -eq 0 ] && [ -n "$NEW_LANG" ]; then
                            LANGUAGE="$NEW_LANG"
                        fi
                        ;;
                    3)
                        NEW_REGION=$(select_region)
                        if [ $? -eq 0 ] && [ -n "$NEW_REGION" ]; then
                            REGION="$NEW_REGION"
                        fi
                        ;;
                    4)
                        NEW_ENCRYPTION=$(select_encryption)
                        if [ $? -eq 0 ] && [ -n "$NEW_ENCRYPTION" ]; then
                            ENCRYPTION="$NEW_ENCRYPTION"
                        fi
                        ;;
                    5)
                        NEW_DESKTOP=$(select_desktops "$DESKTOP_LIST")
                        if [ $? -eq 0 ]; then
                            DESKTOP_LIST="$NEW_DESKTOP"
                        fi
                        ;;
                    6)
                        NEW_SWAP=$(select_swap_auto)
                        if [ $? -eq 0 ] && [ -n "$NEW_SWAP" ]; then
                            SWAP_SIZE="$NEW_SWAP"
                        fi
                        ;;
                    7)
                        NEW_USER_INFO=$(create_user_account)
                        if [ $? -eq 0 ] && [ -n "$NEW_USER_INFO" ]; then
                            USER_INFO="$NEW_USER_INFO"
                            IFS=':' read -r USERNAME USERPASS ROOTPASS <<< "$USER_INFO"
                        fi
                        ;;
                    8)
                        NEW_KERNEL=$(select_kernel_auto)
                        if [ $? -eq 0 ] && [ -n "$NEW_KERNEL" ]; then
                            KERNEL="$NEW_KERNEL"
                        fi
                        ;;
                    9)
                        NEW_GPU=$(select_gpu_auto)
                        if [ $? -eq 0 ] && [ -n "$NEW_GPU" ]; then
                            GPU_DRIVERS="$NEW_GPU"
                        fi
                        ;;
                    10)
                        NEW_DM=$(select_display_manager_auto)
                        if [ $? -eq 0 ] && [ -n "$NEW_DM" ]; then
                            DISPLAY_MANAGER="$NEW_DM"
                        fi
                        ;;
                    11)
                        if [ -z "$DISK" ] || [ -z "$LANGUAGE" ] || [ -z "$USERNAME" ] || [ -z "$KERNEL" ] || [ -z "$REGION" ]; then
                            whiptail --title "Ошибка" --msgbox "Пожалуйста, заполните все обязательные параметры:\n\n- Диск\n- Язык\n- Регион\n- Пользователь\n- Ядро" 14 50
                            continue
                        fi
                        return 0
                        ;;
                esac
                ;;
            *)
                return 1
                ;;
        esac
    done
}

# Функция для отображения меню ручной установки
show_manual_menu() {
    # Инициализация переменных с пустыми значениями (не выбрано)
    MANUAL_DISK=""
    MANUAL_LANGUAGE=""
    MANUAL_REGION=""
    MANUAL_USERNAME=""
    MANUAL_USERPASS=""
    MANUAL_ROOTPASS=""
    MANUAL_DESKTOP_LIST=""
    MANUAL_KERNEL="1"
    MANUAL_GPU="0"
    MANUAL_DISPLAY_MANAGER="1"
    EXTRA_PACKAGES=""

    PARTITION_FS=()
    PARTITION_ENCRYPTION=()
    PARTITION_MOUNT=()

    while true; do
        # Отображение значения диска
        if [ -n "$MANUAL_DISK" ]; then
            DISK_VALUE="$MANUAL_DISK"
        else
            DISK_VALUE="Не выбран"
        fi

        # Отображение количества смонтированных разделов
        PARTITION_COUNT=${#PARTITION_MOUNT[@]}
        if [ "$PARTITION_COUNT" -gt 0 ]; then
            MOUNT_VALUE="$PARTITION_COUNT разделов"
        else
            MOUNT_VALUE="Не настроены"
        fi

        # Получаем количество разделов с выбранной ФС
        FS_COUNT=$(get_fs_count)

        # Отображение значения языка
        if [ -n "$MANUAL_LANGUAGE" ]; then
            case "$MANUAL_LANGUAGE" in
                "ru_RU.UTF-8") LANG_VALUE="Русский" ;;
                "uk_UA.UTF-8") LANG_VALUE="Українська" ;;
                "be_BY.UTF-8") LANG_VALUE="Беларуская" ;;
                "de_DE.UTF-8") LANG_VALUE="Deutsch" ;;
                "pl_PL.UTF-8") LANG_VALUE="Polski" ;;
                "en_US.UTF-8") LANG_VALUE="English" ;;
                *) LANG_VALUE="Не выбран" ;;
            esac
        else
            LANG_VALUE="Не выбран"
        fi

        # Отображение значения региона
        if [ -n "$MANUAL_REGION" ]; then
            REGION_VALUE="$MANUAL_REGION"
        else
            REGION_VALUE="Не выбран"
        fi

        # Отображение значения пользователя
        if [ -n "$MANUAL_USERNAME" ]; then
            USER_VALUE="$MANUAL_USERNAME"
        else
            USER_VALUE="Не создан"
        fi

        # Отображение значения рабочих столов и WM
        DIALOG_W=$(dialog_width)
        DESKTOP_VALUE=$(desktops_menu_value "$MANUAL_DESKTOP_LIST" $(( DIALOG_W - 30 )))

        # Отображение значения ядра
        case "$MANUAL_KERNEL" in
            "1") KERNEL_VALUE="Linux (обычное)" ;;
            "2") KERNEL_VALUE="Linux-zen (производительное)" ;;
            "3") KERNEL_VALUE="Linux-lts (стабильное)" ;;
            *) KERNEL_VALUE="Не выбрано" ;;
        esac

        # Отображение значения драйверов GPU
        case "$MANUAL_GPU" in
            "1") GPU_VALUE="Intel" ;;
            "2") GPU_VALUE="AMD" ;;
            "3") GPU_VALUE="Nvidia dkms" ;;
            "4") GPU_VALUE="Nvidia open" ;;
            "0") GPU_VALUE="Не устанавливать" ;;
            *) GPU_VALUE="Не выбрано" ;;
        esac

        # Отображение дополнительных пакетов
        if [ -n "$EXTRA_PACKAGES" ]; then
            EXTRA_VALUE="$EXTRA_PACKAGES"
        else
            EXTRA_VALUE="Не указаны"
        fi

        # Отображение значения диспетчера входа
        DM_VALUE=$(display_manager_name "$MANUAL_DISPLAY_MANAGER")

        MENU_CHOICE=$(whiptail --title "EasyArch Установщик - Ручная установка" \
                               --menu "\n\n\n" 26 "$DIALOG_W" 14 \
                               "1" "Диск (${DISK_VALUE})" \
                               "2" "Разметка диска (cfdisk)" \
                               "3" "Выбор ФС (${FS_COUNT} разделов)" \
                               "4" "Шифрование" \
                               "5" "Монтирование (${MOUNT_VALUE})" \
                               "6" "Язык (${LANG_VALUE})" \
                               "7" "Регион (${REGION_VALUE})" \
                               "8" "Пользователь (${USER_VALUE})" \
                               "9" "Рабочий стол / WM (${DESKTOP_VALUE})" \
                               "10" "Ядро (${KERNEL_VALUE})" \
                               "11" "Драйверы GPU (${GPU_VALUE})" \
                               "12" "Диспетчер входа (${DM_VALUE})" \
                               "13" "Дополнительные пакеты (${EXTRA_VALUE})" \
                               "14" "Начать установку" \
                               3>&1 1>&2 2>&3 \
                               --ok-button "Выбрать" --cancel-button "Отмена")

        case $? in
            0)
                case $MENU_CHOICE in
                    1) manual_select_disk ;;
                    2) manual_partitions ;;
                    3) manual_filesystem ;;
                    4) manual_encryption ;;
                    5) manual_mountpoints ;;
                    6)
                        NEW_LANG=$(select_language_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_LANG" ]; then
                            MANUAL_LANGUAGE="$NEW_LANG"
                        fi
                        ;;
                    7)
                        NEW_REGION=$(select_region_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_REGION" ]; then
                            MANUAL_REGION="$NEW_REGION"
                        fi
                        ;;
                    8)
                        NEW_USER_INFO=$(create_user_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_USER_INFO" ]; then
                            IFS=':' read -r MANUAL_USERNAME MANUAL_USERPASS MANUAL_ROOTPASS <<< "$NEW_USER_INFO"
                        fi
                        ;;
                    9)
                        NEW_DESKTOP=$(select_desktops "$MANUAL_DESKTOP_LIST")
                        if [ $? -eq 0 ]; then
                            MANUAL_DESKTOP_LIST="$NEW_DESKTOP"
                        fi
                        ;;
                    10)
                        NEW_KERNEL=$(select_kernel_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_KERNEL" ]; then
                            MANUAL_KERNEL="$NEW_KERNEL"
                        fi
                        ;;
                    11)
                        NEW_GPU=$(select_gpu_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_GPU" ]; then
                            MANUAL_GPU="$NEW_GPU"
                        fi
                        ;;
                    12)
                        NEW_DM=$(select_display_manager_manual)
                        if [ $? -eq 0 ] && [ -n "$NEW_DM" ]; then
                            MANUAL_DISPLAY_MANAGER="$NEW_DM"
                        fi
                        ;;
                    13) manual_extra_packages ;;
                    14)
                        if [ -z "$MANUAL_DISK" ] || [ -z "$MANUAL_LANGUAGE" ] || [ -z "$MANUAL_USERNAME" ] || [ -z "$MANUAL_KERNEL" ] || [ -z "$MANUAL_REGION" ]; then
                            whiptail --title "Ошибка" --msgbox "Пожалуйста, заполните все обязательные параметры:\n\n- Диск\n- Язык\n- Регион\n- Пользователь\n- Ядро" 14 50
                            continue
                        fi
                        if [ ${#PARTITION_MOUNT[@]} -eq 0 ]; then
                            whiptail --title "Ошибка" --msgbox "Пожалуйста, настройте монтирование разделов!" 8 40
                            continue
                        fi
                        ROOT_FOUND=0
                        for mount_point in "${PARTITION_MOUNT[@]}"; do
                            if [ "$mount_point" = "/" ]; then
                                ROOT_FOUND=1
                                break
                            fi
                        done
                        if [ $ROOT_FOUND -eq 0 ]; then
                            whiptail --title "Ошибка" --msgbox "Не выбран корневой раздел (/)!" 8 40
                            continue
                        fi
                        return 0
                        ;;
                esac
                ;;
            1)
                return 1
                ;;
        esac
    done
}

# Функция для ввода дополнительных пакетов
manual_extra_packages() {
    EXTRA_PACKAGES=$(whiptail --title "Дополнительные пакеты" \
                              --inputbox "Введите дополнительные пакеты через пробел:\n\nПример: firefox chromium vlc" 10 60 \
                              3>&1 1>&2 2>&3 \
                              --ok-button "OK" --cancel-button "Пропустить")
    if [ $? -ne 0 ]; then
        EXTRA_PACKAGES=""
        return 1
    fi
    if [ -n "$EXTRA_PACKAGES" ]; then
        whiptail --title "Информация" --msgbox "Будут установлены пакеты: $EXTRA_PACKAGES" 8 60
    fi
    return 0
}
