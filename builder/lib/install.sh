#!/usr/bin/env bash
# ============================================================
#
# install.sh
#
# Сценарии установки: автоустановка и ручная установка
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__INSTALL_SH:-}" ]] && return
readonly __INSTALL_SH=1

# Функция для базовой настройки установленной системы
# Используется автоустановкой и ручной установкой
configure_base_system() {
    local target=$1
    local disk=$2
    local language=$3
    local region=$4
    local username=$5
    local userpass=$6
    local rootpass=$7

    genfstab -U "$target" >> "$target/etc/fstab"

    configure_locales "$language"
    configure_pacman "$target"
    configure_vconsole "$target" "$language"

    echo "  → Настройка временной зоны"
    arch-chroot "$target" ln -sf "/usr/share/zoneinfo/$region" /etc/localtime
    arch-chroot "$target" hwclock --systohc

    echo "  → Настройка локалей"
    cp /etc/locale.gen /etc/locale.conf "$target/etc/"
    arch-chroot "$target" locale-gen

    echo "  → Настройка hostname"
    echo "arch" > "$target/etc/hostname"

    echo "  → Настройка hosts"
    cat > "$target/etc/hosts" <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch.localdomain arch
HOSTS

    echo "  → Настройка пароля root"
    echo "root:$rootpass" | arch-chroot "$target" chpasswd

    echo "  → Создание пользователя $username"
    arch-chroot "$target" useradd -m -G wheel -s /bin/zsh "$username"
    echo "$username:$userpass" | arch-chroot "$target" chpasswd

    echo "  → Настройка sudo"
    echo "%wheel ALL=(ALL:ALL) ALL" >> "$target/etc/sudoers"

    echo "  → Назначение zsh оболочкой по умолчанию для всех пользователей"
    set_default_shell "$target"

    configure_user_dirs "$target" "$username"

    # Установка GRUB
    install_grub_only "$target" "$disk"

    echo "  → Включение сервисов"
    arch-chroot "$target" systemctl enable NetworkManager
    arch-chroot "$target" systemctl enable bluetooth
    arch-chroot "$target" systemctl enable cups

    echo ""
    echo -e "\033[1;36m▶ Установка помощника AUR...\033[0m"
    install_yay "$target" "$username"
}

# Функция для выполнения ручной установки
run_manual_installation() {
    print_banner
    echo ""
    echo -e "\033[1;33mНачинается ручная установка системы...\033[0m"
    echo ""

    update_pacman_database

    echo -e "\033[1;36m▶ Выбранная временная зона: $MANUAL_REGION\033[0m"
    echo ""

    apply_manual_partitioning

    echo ""
    echo -e "\033[1;36m▶ Настройка Btrfs подтомов (если корневой раздел Btrfs)...\033[0m"

    ROOT_PART=""
    for part in "${!PARTITION_MOUNT[@]}"; do
        if [ "${PARTITION_MOUNT[$part]}" = "/" ]; then
            if [[ "${PARTITION_ENCRYPTION[$part]}" != "none" ]] && [ -n "${PARTITION_ENCRYPTION[$part]}" ]; then
                ROOT_PART="/dev/mapper/crypt_$(basename "$part")"
            else
                ROOT_PART="$part"
            fi
            break
        fi
    done

    if [ -n "$ROOT_PART" ] && [ -b "$ROOT_PART" ]; then
        ROOT_FS=$(blkid -o value -s TYPE "$ROOT_PART" 2>/dev/null)
        if [ "$ROOT_FS" = "btrfs" ]; then
            echo "  → Создание Btrfs подтомов на корневом разделе"

            mount "$ROOT_PART" /mnt

            btrfs subvolume create /mnt/@
            btrfs subvolume create /mnt/@home
            btrfs subvolume create /mnt/@var
            btrfs subvolume create /mnt/@log
            btrfs subvolume create /mnt/@pkg
            btrfs subvolume create /mnt/@.snapshots

            umount /mnt

            DISK_TYPE=$(check_disk_type "$MANUAL_DISK")
            MOUNT_OPTS=$(get_mount_options "$DISK_TYPE")

            mount -o ${MOUNT_OPTS},subvol=@ "$ROOT_PART" /mnt
            mkdir -p /mnt/{home,var,.snapshots}
            mount -o ${MOUNT_OPTS},subvol=@home "$ROOT_PART" /mnt/home
            mount -o ${MOUNT_OPTS},subvol=@.snapshots "$ROOT_PART" /mnt/.snapshots
            mkdir -p /mnt/var
            mount -o ${MOUNT_OPTS},subvol=@var "$ROOT_PART" /mnt/var
            mkdir -p /mnt/var/log /mnt/var/cache/pacman/pkg
            mount -o ${MOUNT_OPTS},subvol=@log "$ROOT_PART" /mnt/var/log
            mount -o ${MOUNT_OPTS},subvol=@pkg "$ROOT_PART" /mnt/var/cache/pacman/pkg
        fi
    fi

    for part in "${!PARTITION_MOUNT[@]}"; do
        mount_point="${PARTITION_MOUNT[$part]}"
        if [ "$mount_point" != "none" ] && [ -n "$mount_point" ] && [ "$mount_point" != "/" ] && [ "$mount_point" != "swap" ]; then
            echo "  → Монтирование $part в /mnt$mount_point"
            mkdir -p "/mnt$mount_point"
            if [[ "${PARTITION_ENCRYPTION[$part]}" != "none" ]] && [ -n "${PARTITION_ENCRYPTION[$part]}" ]; then
                mount "/dev/mapper/crypt_$(basename "$part")" "/mnt$mount_point"
            else
                mount "$part" "/mnt$mount_point"
            fi
        fi
    done

    echo ""
    echo -e "\033[1;36m▶ Установка базовой системы...\033[0m"

    KERNEL_PKGS=$(kernel_packages "$MANUAL_KERNEL")

    echo "  → Выбрано ядро: $KERNEL_PKGS"

    pacstrap /mnt base base-devel $KERNEL_PKGS linux-firmware iucode-tool \
        btrfs-progs dosfstools efibootmgr grub grub-btrfs zsh xdg-user-dirs \
        amd-ucode intel-ucode networkmanager dhcpcd nano vim \
        archlinux-keyring --noconfirm

    echo ""
    echo -e "\033[1;36m▶ Настройка системы...\033[0m"

    configure_base_system "/mnt" "$MANUAL_DISK" "$MANUAL_LANGUAGE" "$MANUAL_REGION" \
        "$MANUAL_USERNAME" "$MANUAL_USERPASS" "$MANUAL_ROOTPASS"

    if [ "$MANUAL_GPU" != "0" ]; then
        echo ""
        echo -e "\033[1;36m▶ Установка драйверов видеокарты...\033[0m"

        case $MANUAL_GPU in
            1) install_intel_drivers "/mnt" ;;
            2) install_amd_drivers "/mnt" ;;
            3) install_nvidia_drivers "/mnt" "dkms" ;;
            4) install_nvidia_drivers "/mnt" "open" ;;
        esac
    fi

    if [ -n "$MANUAL_DESKTOP_LIST" ]; then
        echo ""
        echo -e "\033[1;36m▶ Установка рабочих столов и оконных менеджеров...\033[0m"

        install_desktop_group "/mnt" "$MANUAL_DESKTOP_LIST" "$MANUAL_USERNAME"

        if [ "$MANUAL_DISPLAY_MANAGER" = "0" ] && desktop_list_has_bare_wm "$MANUAL_DESKTOP_LIST"; then
            echo "  → Настройка автоматического запуска графической сессии на tty1..."
            setup_tty_autostart "/mnt" "$MANUAL_USERNAME"
        fi

        install_display_manager "/mnt" "$MANUAL_DISPLAY_MANAGER" "$MANUAL_DESKTOP_LIST"
    fi

    if [ -n "$EXTRA_PACKAGES" ]; then
        echo ""
        echo -e "\033[1;36m▶ Установка дополнительных пакетов...\033[0m"
        echo "  → Установка: $EXTRA_PACKAGES"
        arch-chroot /mnt pacman -S --noconfirm $EXTRA_PACKAGES
    fi

    echo ""
    echo -e "\033[1;36m▶ Завершение установки...\033[0m"

    # 1) Сначала mkinitcpio -P
    arch-chroot /mnt mkinitcpio -P

    # 2) Затем os-prober и grub-mkconfig (если есть другие ОС)
    if [ -n "$EXISTING_ROOT_PART" ]; then
        add_other_os_to_grub "/mnt" "$EXISTING_ROOT_PART" "$EXISTING_SUBVOL"
    else
        # Если нет других ОС, просто генерируем конфигурацию
        generate_grub_config "/mnt"
    fi

    echo ""
    echo -e "\033[1;32m✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!\033[0m"
    echo ""
    echo -e "\033[1;36m▶ Установленная временная зона: $MANUAL_REGION\033[0m"
    echo ""
}

# Функция для ручной установки (основная)
manual_installation_full() {
    while true; do
        show_manual_menu
        if [ $? -eq 0 ]; then
            run_manual_installation

            umount -R /mnt 2>/dev/null

            echo ""
            read -p "Нажмите Enter для перезагрузки или Ctrl+C для выхода..."
            reboot
            return 0
        else
            return 0
        fi
    done
}

# Функция для установки с выводом логов в терминал (автоустановка)
run_installation() {
    print_banner
    echo ""
    echo -e "\033[1;33mНачинается установка системы...\033[0m"
    echo ""

    update_pacman_database

    echo -e "\033[1;36m▶ Выбранная временная зона: $REGION\033[0m"
    echo ""

    DISK_TYPE=$(check_disk_type "$DISK")
    echo -e "\033[1;36m▶ Тип диска: $(echo $DISK_TYPE | tr '[:lower:]' '[:upper:]')\033[0m"

    MOUNT_OPTS=$(get_mount_options "$DISK_TYPE")
    echo -e "\033[1;36m▶ Параметры монтирования Btrfs: $MOUNT_OPTS\033[0m"
    echo ""

    EXISTING_ROOT_PART=""
    EXISTING_FS_TYPE=""
    EXISTING_SUBVOL=""
    EXISTING_OS_NAME=""

    if [ "$INSTALL_TYPE" = "side" ]; then
        echo -e "\033[1;36m▶ Поиск свободного места на диске $DISK...\033[0m"

        PARTITIONS=$(parted -s "$DISK" unit MiB print free 2>/dev/null)

        FREE_LINE=$(echo "$PARTITIONS" | grep -i "Free Space" | tail -1)

        if [ -z "$FREE_LINE" ]; then
            echo -e "\033[1;31m✗ Ошибка: Не найдено свободного места на диске!\033[0m"
            read -p "Нажмите Enter для возврата в главное меню..."
            main_installation
            return
        fi

        FREE_START=$(echo "$FREE_LINE" | awk '{print $1}' | sed 's/MiB//g')
        FREE_SIZE=$(echo "$FREE_LINE" | awk '{print $3}' | sed 's/MiB//g')

        FREE_START=$(echo "$FREE_START" | cut -d'.' -f1)
        FREE_SIZE=$(echo "$FREE_SIZE" | cut -d'.' -f1)

        if [ -z "$FREE_START" ] || [ -z "$FREE_SIZE" ] || [ "$FREE_SIZE" -lt 10240 ]; then
            echo -e "\033[1;31m✗ Ошибка: Недостаточно свободного места на диске!\033[0m"
            echo -e "\033[1;33m  Для установки ArchLinux требуется минимум 10 ГБ свободного места.\033[0m"
            echo -e "\033[1;33m  Найдено: ${FREE_SIZE} MiB\033[0m"
            echo ""
            read -p "Нажмите Enter для возврата в главное меню..."
            main_installation
            return
        fi

        echo -e "\033[1;32m  → Найдено свободное место: ${FREE_SIZE}MiB (начиная с ${FREE_START}MiB)\033[0m"

        SWAP_SIZE_MIB=$((SWAP_SIZE * 1024))
        ROOT_SIZE=$((FREE_SIZE - SWAP_SIZE_MIB))

        if [ "$ROOT_SIZE" -lt 10240 ]; then
            echo -e "\033[1;31m✗ Ошибка: Недостаточно места для корневого раздела!\033[0m"
            echo -e "\033[1;33m  Корневой раздел должен быть не менее 10 ГБ.\033[0m"
            echo -e "\033[1;33m  Доступно для корня: ${ROOT_SIZE} MiB\033[0m"
            echo ""
            read -p "Нажмите Enter для возврата в главное меню..."
            main_installation
            return
        fi

        BOOT_PART=""
        if [ -d /sys/firmware/efi ]; then
            EFI_PART=$(lsblk -o NAME,PARTTYPE -l | grep -i "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" | head -1 | awk '{print "/dev/"$1}')
            if [ -z "$EFI_PART" ]; then
                EFI_PART=$(lsblk -o NAME,FSTYPE -l | grep -i "vfat" | head -1 | awk '{print "/dev/"$1}')
            fi

            if [ -n "$EFI_PART" ] && [ -b "$EFI_PART" ]; then
                echo -e "\033[1;32m  → Найден существующий EFI раздел: $EFI_PART (будет смонтирован в /boot/efi, НЕ отформатирован)\033[0m"
                BOOT_PART="$EFI_PART"
            else
                echo -e "\033[1;33m  → EFI раздел не найден, будет создан новый\033[0m"
                EFI_SIZE=300
                echo "  → Создание EFI раздела (${EFI_SIZE}MiB)..."
                parted -s "$DISK" mkpart primary fat32 ${FREE_START}MiB $((FREE_START + EFI_SIZE))MiB
                parted -s "$DISK" set $(($(ls ${DISK}* 2>/dev/null | grep -E "${DISK}[0-9]+$" | wc -l))) esp on
                BOOT_PART="${DISK}$(($(ls ${DISK}* 2>/dev/null | grep -E "${DISK}[0-9]+$" | wc -l)))"
                echo "  → Форматирование нового EFI раздела (FAT32)"
                mkfs.fat -F32 "${BOOT_PART}" 2>/dev/null
                FREE_START=$((FREE_START + EFI_SIZE))
                FREE_SIZE=$((FREE_SIZE - EFI_SIZE))
            fi
        fi

        if [ "$SWAP_SIZE" -gt 0 ]; then
            echo "  → Создание swap раздела (${SWAP_SIZE}GB)..."
            parted -s "$DISK" mkpart primary linux-swap ${FREE_START}MiB $((FREE_START + SWAP_SIZE_MIB))MiB
            SWAP_PART="${DISK}$(($(ls ${DISK}* 2>/dev/null | grep -E "${DISK}[0-9]+$" | wc -l)))"

            NEW_START=$((FREE_START + SWAP_SIZE_MIB))
            echo "  → Создание корневого раздела Btrfs (${ROOT_SIZE}MiB)..."
            parted -s "$DISK" mkpart primary btrfs ${NEW_START}MiB 100%
            ROOT_PART="${DISK}$(($(ls ${DISK}* 2>/dev/null | grep -E "${DISK}[0-9]+$" | wc -l)))"
        else
            echo "  → Создание корневого раздела Btrfs (${FREE_SIZE}MiB)..."
            parted -s "$DISK" mkpart primary btrfs ${FREE_START}MiB 100%
            ROOT_PART="${DISK}$(($(ls ${DISK}* 2>/dev/null | grep -E "${DISK}[0-9]+$" | wc -l)))"
            SWAP_PART=""
        fi

        partprobe "$DISK" 2>/dev/null
        sleep 2

        if [ -n "$SWAP_PART" ]; then
            echo "  → Форматирование swap раздела"
            mkswap "${SWAP_PART}" 2>/dev/null
            swapon "${SWAP_PART}" 2>/dev/null
        fi

        echo "  → Форматирование корневого раздела (Btrfs)"
        mkfs.btrfs -f "$ROOT_PART" 2>/dev/null

        find_existing_os "$DISK" "$ROOT_PART"

    else
        cleanup_disk_partitions "$DISK"

        echo -e "\033[1;36m▶ Начинаем разметку диска...\033[0m"
        if [ -d /sys/firmware/efi ]; then
            DISK_SIZE=$(get_disk_size "$DISK")
            EFI_SIZE=$(get_efi_size "$DISK_SIZE")

            echo "  → Размер диска: ${DISK_SIZE}GB"
            echo "  → Размер EFI раздела: ${EFI_SIZE}MiB"

            parted -s "$DISK" mklabel gpt
            echo "  → Создание EFI раздела (${EFI_SIZE}MiB)"
            parted -s "$DISK" mkpart primary fat32 1MiB ${EFI_SIZE}MiB
            parted -s "$DISK" set 1 esp on

            if [ "$SWAP_SIZE" -gt 0 ]; then
                SWAP_START=$((EFI_SIZE + 1))
                SWAP_END=$((SWAP_START + SWAP_SIZE * 1024))
                echo "  → Создание swap раздела (${SWAP_SIZE}GB)"
                parted -s "$DISK" mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB
                echo "  → Создание корневого раздела Btrfs"
                parted -s "$DISK" mkpart primary btrfs ${SWAP_END}MiB 100%
                ROOT_PART="${DISK}3"
                BOOT_PART="${DISK}1"
                SWAP_PART="${DISK}2"
            else
                echo "  → Создание корневого раздела Btrfs"
                parted -s "$DISK" mkpart primary btrfs ${EFI_SIZE}MiB 100%
                ROOT_PART="${DISK}2"
                BOOT_PART="${DISK}1"
                SWAP_PART=""
            fi
        else
            echo "  → Создание MSDOS таблицы разделов на $DISK"
            parted -s "$DISK" mklabel msdos

            if [ "$SWAP_SIZE" -gt 0 ]; then
                SWAP_SIZE_MB=$((SWAP_SIZE * 1024))
                echo "  → Создание swap раздела (${SWAP_SIZE}GB)"
                parted -s "$DISK" mkpart primary linux-swap 1MiB ${SWAP_SIZE_MB}MiB
                echo "  → Создание корневого раздела Btrfs"
                parted -s "$DISK" mkpart primary btrfs ${SWAP_SIZE_MB}MiB 100%
                ROOT_PART="${DISK}2"
                SWAP_PART="${DISK}1"
            else
                echo "  → Создание корневого раздела Btrfs"
                parted -s "$DISK" mkpart primary btrfs 1MiB 100%
                ROOT_PART="${DISK}1"
                SWAP_PART=""
            fi
            parted -s "$DISK" set 1 boot on
        fi

        partprobe "$DISK" 2>/dev/null
        sleep 2

        if [ -d /sys/firmware/efi ]; then
            echo "  → Форматирование EFI раздела (FAT32)"
            mkfs.fat -F32 "${BOOT_PART}" 2>/dev/null
        fi

        if [ -n "$SWAP_PART" ]; then
            echo "  → Форматирование swap раздела"
            mkswap "${SWAP_PART}" 2>/dev/null
            swapon "${SWAP_PART}" 2>/dev/null
        fi

        if [ "$ENCRYPTION" != "none" ]; then
            echo "  → Настройка LUKS шифрования"
            echo -n "$ROOTPASS" | cryptsetup luksFormat --type luks2 "$ROOT_PART"
            echo -n "$ROOTPASS" | cryptsetup open "$ROOT_PART" cryptroot
            ROOT_PART="/dev/mapper/cryptroot"
        fi

        echo "  → Форматирование корневого раздела (Btrfs)"
        mkfs.btrfs -f "$ROOT_PART" 2>/dev/null
    fi

    echo ""
    echo -e "\033[1;36m▶ Настройка Btrfs подтомов...\033[0m"

    mount "$ROOT_PART" /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@var
    btrfs subvolume create /mnt/@log
    btrfs subvolume create /mnt/@pkg
    btrfs subvolume create /mnt/@.snapshots

    umount /mnt

    echo "  → Монтирование корневого подтома"
    mount -o ${MOUNT_OPTS},subvol=@ "$ROOT_PART" /mnt

    mkdir -p /mnt/{boot,home,.snapshots}

    echo "  → Монтирование подтома home"
    mount -o ${MOUNT_OPTS},subvol=@home "$ROOT_PART" /mnt/home

    echo "  → Монтирование подтома snapshots"
    mount -o ${MOUNT_OPTS},subvol=@.snapshots "$ROOT_PART" /mnt/.snapshots

    mkdir -p /mnt/var
    echo "  → Монтирование подтома var"
    mount -o ${MOUNT_OPTS},subvol=@var "$ROOT_PART" /mnt/var

    mkdir -p /mnt/var/log
    mkdir -p /mnt/var/cache/pacman/pkg

    echo "  → Монтирование подтома log"
    mount -o ${MOUNT_OPTS},subvol=@log "$ROOT_PART" /mnt/var/log

    echo "  → Монтирование подтома pkg"
    mount -o ${MOUNT_OPTS},subvol=@pkg "$ROOT_PART" /mnt/var/cache/pacman/pkg

    if [ -d /sys/firmware/efi ]; then
        if [ -n "$BOOT_PART" ]; then
            mkdir -p /mnt/boot/efi
            echo "  → Монтирование EFI раздела $BOOT_PART в /mnt/boot/efi (без форматирования)"
            mount "${BOOT_PART}" /mnt/boot/efi
        else
            echo -e "\033[1;33m  → EFI раздел не найден\033[0m"
        fi
    else
        echo "  → BIOS система, EFI раздел не требуется"
    fi

    echo ""
    echo -e "\033[1;36m▶ Установка базовой системы...\033[0m"

    KERNEL_PKGS=$(kernel_packages "$KERNEL")

    echo "  → Выбрано ядро: $KERNEL_PKGS"

    if [ "$INSTALL_TYPE" = "side" ]; then
        echo "  → Установка os-prober и ntfs-3g для обнаружения других ОС..."
        pacstrap /mnt base base-devel $KERNEL_PKGS linux-firmware iucode-tool \
            btrfs-progs dosfstools efibootmgr grub grub-btrfs os-prober ntfs-3g zsh xdg-user-dirs \
            amd-ucode intel-ucode networkmanager dhcpcd nano vim \
            archlinux-keyring --noconfirm
    else
        pacstrap /mnt base base-devel $KERNEL_PKGS linux-firmware iucode-tool \
            btrfs-progs dosfstools efibootmgr grub grub-btrfs zsh xdg-user-dirs \
            amd-ucode intel-ucode networkmanager dhcpcd nano vim \
            archlinux-keyring --noconfirm
    fi

    echo ""
    echo -e "\033[1;36m▶ Настройка системы...\033[0m"

    configure_base_system "/mnt" "$DISK" "$LANGUAGE" "$REGION" \
        "$USERNAME" "$USERPASS" "$ROOTPASS"

    if [ "$GPU_DRIVERS" != "0" ]; then
        echo ""
        echo -e "\033[1;36m▶ Установка драйверов видеокарты...\033[0m"

        case $GPU_DRIVERS in
            1) install_intel_drivers "/mnt" ;;
            2) install_amd_drivers "/mnt" ;;
            3) install_nvidia_drivers "/mnt" "dkms" ;;
            4) install_nvidia_drivers "/mnt" "open" ;;
        esac
    fi

    if [ -n "$DESKTOP_LIST" ]; then
        echo ""
        echo -e "\033[1;36m▶ Установка рабочих столов и оконных менеджеров...\033[0m"

        install_desktop_group "/mnt" "$DESKTOP_LIST" "$USERNAME"

        if [ "$DISPLAY_MANAGER" = "0" ] && desktop_list_has_bare_wm "$DESKTOP_LIST"; then
            echo "  → Настройка автоматического запуска графической сессии на tty1..."
            setup_tty_autostart "/mnt" "$USERNAME"
        fi

        install_display_manager "/mnt" "$DISPLAY_MANAGER" "$DESKTOP_LIST"
    fi

    echo ""
    echo -e "\033[1;36m▶ Завершение установки...\033[0m"

    # 1) Сначала mkinitcpio -P (для всех режимов)
    arch-chroot /mnt mkinitcpio -P

    # 2) Затем работа с загрузчиком в зависимости от режима
    if [ "$INSTALL_TYPE" = "side" ] && [ -n "$EXISTING_ROOT_PART" ]; then
        # Для режима "рядом с другой ОС" - os-prober и grub-mkconfig
        add_other_os_to_grub "/mnt" "$EXISTING_ROOT_PART" "$EXISTING_SUBVOL"
    else
        # Для режима "чистая установка" - просто генерация конфигурации
        generate_grub_config "/mnt"
    fi

    if [ -d /mnt/os ] && mountpoint -q /mnt/os 2>/dev/null; then
        umount /mnt/os
        rmdir /mnt/os
    fi

    echo ""
    echo -e "\033[1;32m✅ УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!\033[0m"
    echo ""
    echo -e "\033[1;36m▶ Установленная временная зона: $REGION\033[0m"
    echo ""
}

# Главная функция установки
main_installation() {
    cleanup_mounts
    check_whiptail

    select_install_type
    if [ $? -ne 0 ]; then
        return
    fi

    if [ "$INSTALL_TYPE" = "mirrors" ]; then
        sort_mirrors
        main_installation
        return
    fi

    if [ "$INSTALL_TYPE" = "manual" ]; then
        manual_installation_full
        main_installation
        return
    fi

    # Автоустановка - показываем меню настроек
    show_settings_menu
    if [ $? -ne 0 ]; then
        main_installation
        return
    fi

    CONFIRM_MSG="Проверьте параметры установки:\n\nДиск: $DISK\nЯзык: $LANGUAGE\nРегион: $REGION\nШифрование: $ENCRYPTION\nSwap: $SWAP_SIZE GB\nПользователь: $USERNAME\nЯдро: $KERNEL\n"

    if [ "$GPU_DRIVERS" = "0" ]; then
        CONFIRM_MSG="$CONFIRM_MSGДрайверы GPU: Не устанавливать\n"
    else
        case $GPU_DRIVERS in
            1) GPU_NAME="Intel" ;;
            2) GPU_NAME="AMD" ;;
            3) GPU_NAME="Nvidia dkms" ;;
            4) GPU_NAME="Nvidia open" ;;
            *) GPU_NAME="Не установлен" ;;
        esac
        CONFIRM_MSG="$CONFIRM_MSGДрайверы GPU: $GPU_NAME\n"
    fi

    CONFIRM_MSG="$CONFIRM_MSGРабочий стол / WM: $(desktops_summary "$DESKTOP_LIST")\n"

    DM_NAME=$(display_manager_name "$DISPLAY_MANAGER")
    CONFIRM_MSG="$CONFIRM_MSGДиспетчер входа: $DM_NAME\n"

    CONFIRM_MSG="$CONFIRM_MSG\nНачать установку?"

    whiptail --title "Подтверждение параметров" \
             --yesno "$CONFIRM_MSG" 26 70 \
             --yes-button "Установить" --no-button "Отмена"

    if [ $? -ne 0 ]; then
        whiptail --title "Отмена" --msgbox "Установка отменена. Возврат в главное меню." 8 50
        main_installation
        return
    fi

    DISK_SIZE=$(get_disk_size "$DISK")
    run_installation

    umount -R /mnt 2>/dev/null

    echo ""
    read -p "Нажмите Enter для перезагрузки или Ctrl+C для выхода..."
    reboot
}
