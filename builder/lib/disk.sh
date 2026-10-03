#!/usr/bin/env bash
# ============================================================
#
# disk.sh
#
# Работа с дисками и разделами: список, тип, монтирование, очистка
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__DISK_SH:-}" ]] && return
readonly __DISK_SH=1

# Функция для получения количества разделов с выбранной ФС
get_fs_count() {
    local count=0
    for fs in "${PARTITION_FS[@]}"; do
        if [ -n "$fs" ] && [ "$fs" != "none" ]; then
            ((count++))
        fi
    done
    echo "$count"
}

# Функция для получения списка дисков (улучшенная - как в автоустановке)
get_disk_list() {
    DISKS=()
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
        DISKS+=("/dev/$disk_name" "$disk_info")
    done < <(lsblk -d -o NAME,TYPE | grep -E "disk$")

    if [ ${#DISKS[@]} -eq 0 ]; then
        return 1
    fi
    echo "${DISKS[@]}"
}

# Функция для получения списка ВСЕХ разделов со ВСЕХ дисков (исправленная для NVMe)
get_all_partitions_list() {
    PARTITIONS=()

    while IFS= read -r disk; do
        disk_name=$(basename "$disk")
        # Определяем шаблон для поиска разделов в зависимости от типа диска
        if [[ "$disk_name" =~ ^nvme ]]; then
            # Для NVMe дисков разделы имеют вид nvme0n1p1, nvme0n1p2 и т.д.
            part_pattern="^${disk_name}p[0-9]+"
        elif [[ "$disk_name" =~ ^mmcblk ]]; then
            # Для MMC дисков разделы имеют вид mmcblk0p1, mmcblk0p2 и т.д.
            part_pattern="^${disk_name}p[0-9]+"
        else
            # Для обычных дисков (sda, vda, xvda и т.д.) разделы имеют вид sda1, sda2 и т.д.
            part_pattern="^${disk_name}[0-9]+"
        fi

        while IFS= read -r part; do
            if [ -n "$part" ]; then
                part_path="/dev/$part"
                part_size=$(lsblk -no SIZE "$part_path" 2>/dev/null | head -1)
                part_fs=$(lsblk -no FSTYPE "$part_path" 2>/dev/null | head -1)
                if [ -z "$part_fs" ]; then
                    part_fs="none"
                fi
                PARTITIONS+=("$part_path" "$part_size")
            fi
        done < <(lsblk -lno NAME "$disk" 2>/dev/null | grep -E "$part_pattern" | sort -V)
    done < <(lsblk -d -o NAME,TYPE | grep -E "disk$" | awk '{print "/dev/"$1}')

    if [ ${#PARTITIONS[@]} -eq 0 ]; then
        return 1
    fi

    echo "${PARTITIONS[@]}"
}

# Функция для получения списка разделов выбранного диска (исправленная для NVMe)
get_partition_list() {
    local disk=$1
    local disk_name=$(basename "$disk")
    PARTITIONS=()

    # Определяем шаблон для поиска разделов в зависимости от типа диска
    if [[ "$disk_name" =~ ^nvme ]]; then
        # Для NVMe дисков разделы имеют вид nvme0n1p1, nvme0n1p2 и т.д.
        part_pattern="^${disk_name}p[0-9]+"
    elif [[ "$disk_name" =~ ^mmcblk ]]; then
        # Для MMC дисков разделы имеют вид mmcblk0p1, mmcblk0p2 и т.д.
        part_pattern="^${disk_name}p[0-9]+"
    else
        # Для обычных дисков (sda, vda, xvda и т.д.) разделы имеют вид sda1, sda2 и т.д.
        part_pattern="^${disk_name}[0-9]+"
    fi

    while IFS= read -r part; do
        if [ -n "$part" ]; then
            part_path="/dev/$part"
            part_size=$(lsblk -no SIZE "$part_path" 2>/dev/null | head -1)
            part_fs=$(lsblk -no FSTYPE "$part_path" 2>/dev/null | head -1)
            if [ -z "$part_fs" ]; then
                part_fs="none"
            fi
            PARTITIONS+=("$part_path" "$part_size")
        fi
    done < <(lsblk -lno NAME "$disk" 2>/dev/null | grep -E "$part_pattern" | sort -V)

    if [ ${#PARTITIONS[@]} -eq 0 ]; then
        return 1
    fi

    echo "${PARTITIONS[@]}"
}

# Функция для получения размера диска
get_disk_size() {
    local disk=$1
    local size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null)
    if [ -n "$size_bytes" ]; then
        echo $((size_bytes / 1024 / 1024 / 1024))
    else
        echo "0"
    fi
}

# Функция для определения типа диска
check_disk_type() {
    local disk=$1
    local disk_base=$(basename "$disk")

    if [[ "$disk_base" == vd* ]]; then
        echo "virtio"
        return
    fi

    if [ -f "/sys/block/$disk_base/removable" ] && [ "$(cat "/sys/block/$disk_base/removable" 2>/dev/null)" = "1" ]; then
        echo "usb"
        return
    fi

    if [ -f "/sys/block/$disk_base/queue/rotational" ]; then
        ROT=$(cat "/sys/block/$disk_base/queue/rotational" 2>/dev/null)
        if [ "$ROT" -eq 0 ]; then
            echo "ssd"
        else
            echo "hdd"
        fi
    else
        echo "ssd"
    fi
}

# Функция для получения параметров монтирования
get_mount_options() {
    local disk_type=$1

    case "$disk_type" in
        "ssd")
            echo "rw,noatime,compress-force=zstd:3,ssd,space_cache=v2,discard=async"
            ;;
        "virtio")
            echo "defaults,noatime,compress-force=zstd:3,space_cache=v2,autodefrag,discard=async,ssd"
            ;;
        "usb")
            echo "rw,noatime,compress-force=zstd:3,ssd,space_cache=v2,discard=async,autodefrag"
            ;;
        "hdd")
            echo "rw,relatime,compress-force=zstd:3,space_cache=v2,autodefrag"
            ;;
        *)
            echo "rw,noatime,compress-force=zstd:3,space_cache=v2"
            ;;
    esac
}

# Функция для определения размера EFI раздела
get_efi_size() {
    local disk_size_gb=$1
    if [ "$disk_size_gb" -lt 1000 ]; then
        echo "300"
    elif [ "$disk_size_gb" -eq 1000 ]; then
        echo "512"
    else
        echo "1024"
    fi
}

# Функция для очистки диска
cleanup_disk_partitions() {
    local disk=$1
    # Получаем список разделов в зависимости от типа диска
    local disk_name=$(basename "$disk")
    if [[ "$disk_name" =~ ^nvme ]]; then
        part_pattern="${disk_name}p[0-9]+"
    elif [[ "$disk_name" =~ ^mmcblk ]]; then
        part_pattern="${disk_name}p[0-9]+"
    else
        part_pattern="${disk_name}[0-9]+"
    fi

    for part in $(ls ${disk}* 2>/dev/null | grep -E "$part_pattern"); do
        wipefs -a "$part" 2>/dev/null
    done
    wipefs -a "$disk" 2>/dev/null
    sync
    sleep 2
}

# Функция для очистки монтирований
cleanup_mounts() {
    if mountpoint -q /mnt 2>/dev/null; then
        umount -R /mnt 2>/dev/null
    fi

    if [ -d /mnt/os ] && mountpoint -q /mnt/os 2>/dev/null; then
        umount /mnt/os 2>/dev/null
        rmdir /mnt/os 2>/dev/null
    fi

    for mount_point in /mnt/boot/efi /mnt/boot /mnt/home /mnt/var/log /mnt/var/cache/pacman/pkg /mnt/var /mnt/.snapshots /mnt; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            umount -l "$mount_point" 2>/dev/null
        fi
    done

    if cryptsetup status cryptroot >/dev/null 2>&1; then
        cryptsetup close cryptroot 2>/dev/null
    fi

    if swapon --show | grep -q "/dev/"; then
        swapoff -a 2>/dev/null
    fi

    sync
}

# Функция для поиска существующей ОС (для режима side)
find_existing_os() {
    local disk=$1
    local new_root_part=$2

    echo -e "\033[1;36m▶ Поиск существующих операционных систем...\033[0m"

    EXISTING_ROOT_PART=""
    EXISTING_FS_TYPE=""
    EXISTING_SUBVOL=""
    EXISTING_OS_NAME=""

    mkdir -p /mnt/os

    # Получаем список всех разделов на диске с учетом типа диска
    local disk_name=$(basename "$disk")
    if [[ "$disk_name" =~ ^nvme ]]; then
        part_pattern="${disk_name}p[0-9]+"
    elif [[ "$disk_name" =~ ^mmcblk ]]; then
        part_pattern="${disk_name}p[0-9]+"
    else
        part_pattern="${disk_name}[0-9]+"
    fi

    local partitions=$(lsblk -lno NAME,FSTYPE "$disk" 2>/dev/null | grep -E "$part_pattern" | grep -E "btrfs|ext4|xfs|ntfs|ext3|ext2" | awk '{print "/dev/"$1}')

    for part in $partitions; do
        if [ "$part" = "$new_root_part" ]; then
            continue
        fi

        local fs_type=$(blkid -o value -s TYPE "$part" 2>/dev/null)
        echo -e "\033[1;36m  → Проверка раздела $part (ФС: $fs_type)\033[0m"

        if [ "$fs_type" = "btrfs" ]; then
            for subvol in "@" "@root" "root" ""; do
                if [ -n "$subvol" ]; then
                    mount -o ro,subvol="$subvol" "$part" /mnt/os 2>/dev/null
                else
                    mount -o ro "$part" /mnt/os 2>/dev/null
                fi

                if mountpoint -q /mnt/os; then
                    if [ -d /mnt/os/etc ] && [ -d /mnt/os/usr ] && [ -d /mnt/os/bin ]; then
                        echo -e "\033[1;32m    ✓ Найдена Linux система на $part (Btrfs, subvol=$subvol)\033[0m"
                        EXISTING_ROOT_PART="$part"
                        EXISTING_FS_TYPE="btrfs"
                        EXISTING_SUBVOL="$subvol"
                        EXISTING_OS_NAME="Linux"
                        umount /mnt/os
                        rmdir /mnt/os 2>/dev/null
                        return 0
                    fi
                    umount /mnt/os
                fi
            done
        elif [[ "$fs_type" =~ ^(ext4|xfs|ext3|ext2)$ ]]; then
            if mount -o ro "$part" /mnt/os 2>/dev/null; then
                if [ -d /mnt/os/etc ] && [ -d /mnt/os/usr ] && [ -d /mnt/os/bin ]; then
                    echo -e "\033[1;32m    ✓ Найдена Linux система на $part ($fs_type)\033[0m"
                    EXISTING_ROOT_PART="$part"
                    EXISTING_FS_TYPE="$fs_type"
                    EXISTING_SUBVOL=""
                    EXISTING_OS_NAME="Linux"
                    umount /mnt/os
                    rmdir /mnt/os 2>/dev/null
                    return 0
                fi
                umount /mnt/os
            fi
        elif [ "$fs_type" = "ntfs" ]; then
            if ! command -v ntfs-3g &> /dev/null; then
                pacman -S --noconfirm ntfs-3g >/dev/null 2>&1
            fi

            if mount -t ntfs3 -o ro "$part" /mnt/os 2>/dev/null || mount -t ntfs-3g -o ro "$part" /mnt/os 2>/dev/null; then
                if [ -d /mnt/os/Windows ] && [ -d /mnt/os/Windows/System32 ]; then
                    echo -e "\033[1;32m    ✓ Найдена Windows на разделе $part\033[0m"
                    EXISTING_ROOT_PART="$part"
                    EXISTING_FS_TYPE="ntfs"
                    EXISTING_SUBVOL=""
                    EXISTING_OS_NAME="Windows"
                    umount /mnt/os
                    rmdir /mnt/os 2>/dev/null
                    return 0
                fi
                umount /mnt/os
            fi
        fi
    done

    rmdir /mnt/os 2>/dev/null
    echo -e "\033[1;33m  → Существующие ОС не найдены\033[0m"
    return 1
}

# Функция для выбора диска (автоустановка)
select_disk() {
    DISK_LIST=()
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
        DISK_LIST+=("/dev/$disk_name" "$disk_info")
    done < <(lsblk -d -o NAME,TYPE | grep -E "disk$")

    if [ ${#DISK_LIST[@]} -eq 0 ]; then
        whiptail --title "Ошибка" --msgbox "Не найдено дисков для установки!" 8 40
        return 1
    fi

    SELECTED_DISK=$(whiptail --title "Выбор диска для установки" \
                             --menu "Выберите диск для установки:" 18 70 10 \
                             "${DISK_LIST[@]}" \
                             3>&1 1>&2 2>&3 \
                             --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    if [ -n "$SELECTED_DISK" ]; then
        echo "$SELECTED_DISK"
        return 0
    else
        return 1
    fi
}

# Функция для выбора шифрования (автоустановка)
select_encryption() {
    CHOICE=$(whiptail --title "Выбор шифрования диска" \
                      --menu "Выберите тип шифрования:" 10 60 3 \
                      "1" "Без шифрования" \
                      "2" "LUKS шифрование" \
                      "3" "LUKS2 шифрование" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    case $CHOICE in
        1) echo "none" ;;
        2) echo "luks1" ;;
        3) echo "luks2" ;;
        *) echo "none" ;;
    esac
    return 0
}

# Функция для выбора swap (автоустановка)
select_swap_auto() {
    CHOICE=$(whiptail --title "Выбор раздела подкачки" \
                      --menu "Выберите размер swap:" 11 60 6 \
                      "1" "Без swap" \
                      "2" "1 GB" \
                      "3" "2 GB" \
                      "4" "4 GB" \
                      "5" "8 GB" \
                      "6" "16 GB" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    case $CHOICE in
        1) echo "0" ;;
        2) echo "1" ;;
        3) echo "2" ;;
        4) echo "4" ;;
        5) echo "8" ;;
        6) echo "16" ;;
        *) echo "2" ;;
    esac
    return 0
}
