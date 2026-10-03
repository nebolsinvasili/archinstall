#!/usr/bin/env bash
# ============================================================
#
# partition.sh
#
# Ручная разметка диска: создание, ФС, шифрование, точки монтирования
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__PARTITION_SH:-}" ]] && return
readonly __PARTITION_SH=1

# Функция для ручного выбора диска (улучшенная - как в автоустановке)
manual_select_disk() {
    # Получаем список дисков в правильном формате для whiptail
    DISK_ARRAY=()
    while IFS= read -r line; do
        [[ "$line" =~ ^NAME ]] && continue
        disk_name=$(echo "$line" | awk '{print $1}')
        if [[ "$disk_name" =~ ^loop ]] || [[ "$disk_name" =~ ^sr ]] || [[ "$disk_name" =~ ^ram ]]; then
            continue
        fi
        disk_size=$(lsblk -d -o SIZE /dev/"$disk_name" 2>/dev/null | tail -1)
        disk_model=$(lsblk -d -o MODEL /dev/"$disk_name" 2>/dev/null | tail -1)
        disk_type=""
        if [ -f "/sys/block/$disk_name/removable" ] && [ "$(cat "/sys/block/$disk_name/removable" 2>/dev/null)" = "1" ]; then
            disk_type="USB"
        elif [[ "$disk_name" =~ ^vd ]]; then
            disk_type="VirtIO"
        elif [[ "$disk_name" =~ ^sd ]]; then
            disk_type="SATA/SCSI"
        elif [[ "$disk_name" =~ ^nvme ]]; then
            disk_type="NVMe"
        elif [[ "$disk_name" =~ ^mmcblk ]]; then
            disk_type="MMC"
        fi
        if [ -n "$disk_model" ] && [ "$disk_model" != "-" ]; then
            disk_info="$disk_size - $disk_type $disk_model"
        else
            disk_info="$disk_size - $disk_type Disk"
        fi
        disk_info=$(echo "$disk_info" | xargs)
        # Для whiptail: сначала путь к диску (значение), потом описание (отображается)
        DISK_ARRAY+=("/dev/$disk_name" "$disk_info")
    done < <(lsblk -d -o NAME,TYPE | grep -E "disk$")

    if [ ${#DISK_ARRAY[@]} -eq 0 ]; then
        whiptail --title "Ошибка" --msgbox "Не найдено дисков!" 8 40
        return 1
    fi

    SELECTED_DISK=$(whiptail --title "Выбор диска" \
                             --menu "Выберите диск:" 18 70 10 \
                             "${DISK_ARRAY[@]}" \
                             3>&1 1>&2 2>&3 \
                             --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -eq 0 ] && [ -n "$SELECTED_DISK" ]; then
        MANUAL_DISK="$SELECTED_DISK"
        return 0
    fi
    return 1
}

# Функция для выбора разделов (cfdisk)
manual_partitions() {
    if [ -z "$MANUAL_DISK" ]; then
        whiptail --title "Ошибка" --msgbox "Сначала выберите диск!" 8 40
        return 1
    fi
    clear
    echo -e "\033[1;36m"
    echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           Редактирование разделов                             ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "\033[0m"
    echo ""
    echo -e "\033[1;33mДиск: $MANUAL_DISK\033[0m"
    echo ""
    echo -e "\033[1;36mИнструкция:\033[0m"
    echo "  - Используйте стрелки для навигации"
    echo "  - [Enter] - изменить раздел"
    echo "  - [Delete] - удалить раздел"
    echo "  - [Tab] - переключение между разделами и кнопками"
    echo "  - [Ctrl+C] - выход"
    echo ""
    read -p "Нажмите Enter для запуска cfdisk..."
    cfdisk "$MANUAL_DISK"
    return 0
}

# Функция для выбора файловой системы для разделов
manual_filesystem() {
    while true; do
        ALL_PARTITIONS=$(get_all_partitions_list)
        if [ $? -ne 0 ] || [ -z "$ALL_PARTITIONS" ]; then
            whiptail --title "Ошибка" --msgbox "Нет разделов ни на одном диске!" 8 40
            return 1
        fi

        local temp_file=$(mktemp)

        local parts_array=($ALL_PARTITIONS)
        for ((i=0; i<${#parts_array[@]}; i+=2)); do
            part_path="${parts_array[i]}"
            part_size="${parts_array[i+1]}"
            current_fs="${PARTITION_FS[$part_path]}"
            if [ -n "$current_fs" ] && [ "$current_fs" != "none" ]; then
                echo "$part_path|$part_size - текущая: $current_fs" >> "$temp_file"
            else
                echo "$part_path|$part_size - не выбрана" >> "$temp_file"
            fi
        done

        MENU_ARGS=()
        while IFS='|' read -r path desc; do
            MENU_ARGS+=("$path" "$desc")
        done < "$temp_file"
        rm -f "$temp_file"

        SELECTED_PART=$(whiptail --title "Выбор файловой системы" \
                                 --menu "Выберите раздел для настройки файловой системы:" 20 90 12 \
                                 "${MENU_ARGS[@]}" \
                                 3>&1 1>&2 2>&3 \
                                 --ok-button "Выбрать" --cancel-button "Назад")

        if [ $? -ne 0 ] || [ -z "$SELECTED_PART" ]; then
            return 1
        fi

        FS_CHOICE=$(whiptail --title "Файловая система для $SELECTED_PART" \
                             --menu "Выберите тип файловой системы:" 16 60 9 \
                             "1" "btrfs" \
                             "2" "ext4" \
                             "3" "fat32" \
                             "4" "xfs" \
                             "5" "f2fs" \
                             "6" "ntfs" \
                             "7" "zfs" \
                             "0" "Не форматировать" \
                             3>&1 1>&2 2>&3 \
                             --ok-button "Выбрать" --cancel-button "Отмена")

        if [ $? -eq 0 ] && [ -n "$FS_CHOICE" ]; then
            case $FS_CHOICE in
                1) PARTITION_FS["$SELECTED_PART"]="btrfs" ;;
                2) PARTITION_FS["$SELECTED_PART"]="ext4" ;;
                3) PARTITION_FS["$SELECTED_PART"]="fat32" ;;
                4) PARTITION_FS["$SELECTED_PART"]="xfs" ;;
                5) PARTITION_FS["$SELECTED_PART"]="f2fs" ;;
                6) PARTITION_FS["$SELECTED_PART"]="ntfs" ;;
                7) PARTITION_FS["$SELECTED_PART"]="zfs" ;;
                0) PARTITION_FS["$SELECTED_PART"]="none" ;;
            esac
            whiptail --title "Информация" --msgbox "Для раздела $SELECTED_PART выбрана ФС: ${PARTITION_FS[$SELECTED_PART]}" 8 60
        fi
    done
}

# Функция для выбора шифрования разделов
manual_encryption() {
    while true; do
        ALL_PARTITIONS=$(get_all_partitions_list)
        if [ $? -ne 0 ] || [ -z "$ALL_PARTITIONS" ]; then
            whiptail --title "Ошибка" --msgbox "Нет разделов ни на одном диске!" 8 40
            return 1
        fi

        local temp_file=$(mktemp)

        local parts_array=($ALL_PARTITIONS)
        for ((i=0; i<${#parts_array[@]}; i+=2)); do
            part_path="${parts_array[i]}"
            part_size="${parts_array[i+1]}"
            current_enc="${PARTITION_ENCRYPTION[$part_path]}"
            if [ -n "$current_enc" ] && [ "$current_enc" != "none" ]; then
                echo "$part_path|$part_size - текущее: $current_enc" >> "$temp_file"
            else
                echo "$part_path|$part_size - без шифрования" >> "$temp_file"
            fi
        done

        MENU_ARGS=()
        while IFS='|' read -r path desc; do
            MENU_ARGS+=("$path" "$desc")
        done < "$temp_file"
        rm -f "$temp_file"

        SELECTED_PART=$(whiptail --title "Выбор шифрования" \
                                 --menu "Выберите раздел для настройки шифрования:" 20 90 12 \
                                 "${MENU_ARGS[@]}" \
                                 3>&1 1>&2 2>&3 \
                                 --ok-button "Выбрать" --cancel-button "Назад")

        if [ $? -ne 0 ] || [ -z "$SELECTED_PART" ]; then
            return 1
        fi

        ENC_CHOICE=$(whiptail --title "Шифрование для $SELECTED_PART" \
                              --menu "Выберите тип шифрования:" 12 60 4 \
                              "1" "LUKS2" \
                              "2" "LUKS1" \
                              "0" "Без шифрования" \
                              3>&1 1>&2 2>&3 \
                              --ok-button "Выбрать" --cancel-button "Отмена")

        if [ $? -eq 0 ] && [ -n "$ENC_CHOICE" ]; then
            case $ENC_CHOICE in
                1) PARTITION_ENCRYPTION["$SELECTED_PART"]="luks2" ;;
                2) PARTITION_ENCRYPTION["$SELECTED_PART"]="luks1" ;;
                0) PARTITION_ENCRYPTION["$SELECTED_PART"]="none" ;;
            esac
            whiptail --title "Информация" --msgbox "Для раздела $SELECTED_PART выбрано шифрование: ${PARTITION_ENCRYPTION[$SELECTED_PART]}" 8 60
        fi
    done
}

# Функция для выбора точек монтирования
manual_mountpoints() {
    while true; do
        ALL_PARTITIONS=$(get_all_partitions_list)
        if [ $? -ne 0 ] || [ -z "$ALL_PARTITIONS" ]; then
            whiptail --title "Ошибка" --msgbox "Нет разделов ни на одном диске!" 8 40
            return 1
        fi

        local temp_file=$(mktemp)

        local parts_array=($ALL_PARTITIONS)
        for ((i=0; i<${#parts_array[@]}; i+=2)); do
            part_path="${parts_array[i]}"
            part_size="${parts_array[i+1]}"
            current_mount="${PARTITION_MOUNT[$part_path]}"
            if [ -n "$current_mount" ] && [ "$current_mount" != "none" ]; then
                echo "$part_path|$part_size - монтируется в: $current_mount" >> "$temp_file"
            else
                echo "$part_path|$part_size - не смонтирован" >> "$temp_file"
            fi
        done

        MENU_ARGS=()
        while IFS='|' read -r path desc; do
            MENU_ARGS+=("$path" "$desc")
        done < "$temp_file"
        rm -f "$temp_file"

        SELECTED_PART=$(whiptail --title "Выбор точки монтирования" \
                                 --menu "Выберите раздел для настройки монтирования:" 20 90 12 \
                                 "${MENU_ARGS[@]}" \
                                 3>&1 1>&2 2>&3 \
                                 --ok-button "Выбрать" --cancel-button "Назад")

        if [ $? -ne 0 ] || [ -z "$SELECTED_PART" ]; then
            return 1
        fi

        MOUNT_CHOICE=$(whiptail --title "Точка монтирования для $SELECTED_PART" \
                                --menu "Выберите точку монтирования:" 14 60 6 \
                                "1" "/ (Root)" \
                                "2" "/boot/efi" \
                                "3" "/boot" \
                                "4" "/home" \
                                "5" "swap" \
                                "0" "Не монтировать" \
                                3>&1 1>&2 2>&3 \
                                --ok-button "Выбрать" --cancel-button "Отмена")

        if [ $? -eq 0 ] && [ -n "$MOUNT_CHOICE" ]; then
            case $MOUNT_CHOICE in
                1) PARTITION_MOUNT["$SELECTED_PART"]="/" ;;
                2) PARTITION_MOUNT["$SELECTED_PART"]="/boot/efi" ;;
                3) PARTITION_MOUNT["$SELECTED_PART"]="/boot" ;;
                4) PARTITION_MOUNT["$SELECTED_PART"]="/home" ;;
                5) PARTITION_MOUNT["$SELECTED_PART"]="swap" ;;
                0) PARTITION_MOUNT["$SELECTED_PART"]="none" ;;
            esac

            if [ "$MOUNT_CHOICE" = "5" ]; then
                PARTITION_FS["$SELECTED_PART"]="swap"
                whiptail --title "Информация" --msgbox "Для раздела $SELECTED_PART выбран swap\nРаздел будет отформатирован как swap" 8 60
            else
                whiptail --title "Информация" --msgbox "Для раздела $SELECTED_PART выбрано монтирование: ${PARTITION_MOUNT[$SELECTED_PART]}" 8 60
            fi
        fi
    done
}

# Функция для выполнения форматирования и монтирования в ручной установке
apply_manual_partitioning() {
    echo -e "\033[1;36m▶ Применение настроек разделов...\033[0m"

    ROOT_FOUND=0
    ROOT_PART=""
    for part in "${!PARTITION_MOUNT[@]}"; do
        if [ "${PARTITION_MOUNT[$part]}" = "/" ]; then
            ROOT_FOUND=1
            ROOT_PART="$part"
            break
        fi
    done

    if [ $ROOT_FOUND -eq 0 ]; then
        echo -e "\033[1;31m✗ Ошибка: Не выбран корневой раздел (/)\033[0m"
        return 1
    fi

    for part in "${!PARTITION_FS[@]}"; do
        fs="${PARTITION_FS[$part]}"
        if [ "$fs" != "none" ] && [ -n "$fs" ] && [ -b "$part" ]; then
            echo "  → Форматирование $part в $fs"
            case $fs in
                ext4) mkfs.ext4 -F "$part" 2>&1 | grep -v "Creating filesystem" ;;
                btrfs) mkfs.btrfs -f "$part" 2>&1 | grep -v "Label" ;;
                xfs) mkfs.xfs -f "$part" 2>&1 | grep -v "meta-data" ;;
                f2fs) mkfs.f2fs -f "$part" 2>&1 | grep -v "Info" ;;
                ntfs) mkfs.ntfs -F "$part" 2>&1 | grep -v "Syncing" ;;
                fat32) mkfs.fat -F32 "$part" 2>&1 | grep -v "mkfs.fat" ;;
                swap) mkswap "$part" 2>&1 | grep -v "Setting up swapspace" ;;
                zfs) echo "  → ZFS требует отдельной настройки, пропускаем автоматическое форматирование" ;;
            esac
            echo -e "\033[1;32m    ✓ Готово\033[0m"
        fi
    done

    for part in "${!PARTITION_ENCRYPTION[@]}"; do
        enc="${PARTITION_ENCRYPTION[$part]}"
        if [ "$enc" != "none" ] && [ -n "$enc" ] && [ -b "$part" ]; then
            echo "  → Настройка шифрования $part ($enc)"
            echo -n "$MANUAL_ROOTPASS" | cryptsetup luksFormat --type "$enc" "$part" 2>&1 | grep -v "WARNING"
            echo -n "$MANUAL_ROOTPASS" | cryptsetup open "$part" "crypt_$(basename "$part")" 2>&1
            echo -e "\033[1;32m    ✓ Готово\033[0m"
        fi
    done

    echo "  → Монтирование корневого раздела $ROOT_PART в /mnt"
    if [[ "${PARTITION_ENCRYPTION[$ROOT_PART]}" != "none" ]] && [ -n "${PARTITION_ENCRYPTION[$ROOT_PART]}" ]; then
        mount "/dev/mapper/crypt_$(basename "$ROOT_PART")" /mnt
    else
        mount "$ROOT_PART" /mnt
    fi

    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m✗ Ошибка монтирования корневого раздела\033[0m"
        return 1
    fi
    echo -e "\033[1;32m    ✓ Готово\033[0m"

    mkdir -p /mnt/{boot,home,var,.snapshots}

    for part in "${!PARTITION_MOUNT[@]}"; do
        mount_point="${PARTITION_MOUNT[$part]}"
        if [ "$mount_point" != "none" ] && [ -n "$mount_point" ] && [ "$mount_point" != "/" ]; then
            if [ "$mount_point" = "swap" ]; then
                echo "  → Активация swap на $part"
                swapon "$part" 2>/dev/null
                echo -e "\033[1;32m    ✓ Готово\033[0m"
            elif [ "$mount_point" = "/boot/efi" ]; then
                echo "  → Монтирование $part в /mnt/boot/efi"
                mkdir -p "/mnt/boot/efi"
                mount "$part" "/mnt/boot/efi"
                echo -e "\033[1;32m    ✓ Готово\033[0m"
            else
                echo "  → Монтирование $part в /mnt$mount_point"
                mkdir -p "/mnt$mount_point"
                if [[ "${PARTITION_ENCRYPTION[$part]}" != "none" ]] && [ -n "${PARTITION_ENCRYPTION[$part]}" ]; then
                    mount "/dev/mapper/crypt_$(basename "$part")" "/mnt$mount_point"
                else
                    mount "$part" "/mnt$mount_point"
                fi
                if [ $? -eq 0 ]; then
                    echo -e "\033[1;32m    ✓ Готово\033[0m"
                else
                    echo -e "\033[1;31m    ✗ Ошибка монтирования $part\033[0m"
                fi
            fi
        fi
    done

    echo -e "\033[1;32m✓ Применение настроек разделов завершено\033[0m"
    echo ""
}
