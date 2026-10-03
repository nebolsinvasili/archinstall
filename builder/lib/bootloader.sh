#!/usr/bin/env bash
# ============================================================
#
# bootloader.sh
#
# Загрузчик GRUB: установка, конфигурация, другие ОС
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__BOOTLOADER_SH:-}" ]] && return
readonly __BOOTLOADER_SH=1

# Функция для установки GRUB (только установка, без генерации конфигурации)
install_grub_only() {
    local target=$1
    local disk=$2

    echo "  → Установка загрузчика GRUB..."

    if [ -d /sys/firmware/efi ]; then
        echo "  → Обнаружена UEFI система"
        arch-chroot "$target" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch --no-nvram --removable "$disk" 2>&1
        arch-chroot "$target" grub-install --bootloader-id=Arch "$disk" 2>&1
    else
        echo "  → Обнаружена BIOS (MBR) система"
        arch-chroot "$target" grub-install --target=i386-pc --bootloader-id=Arch "$disk" 2>&1
        arch-chroot "$target" grub-install --bootloader-id=Arch "$disk" 2>&1
    fi
}

# Функция для генерации конфигурации GRUB (только для режима clean)
generate_grub_config() {
    local target=$1

    echo "  → Генерация конфигурации GRUB..."
    arch-chroot "$target" grub-mkconfig -o /boot/grub/grub.cfg 2>&1
}

# Функция для добавления другой ОС в GRUB (для режима side)
# Выполняется после mkinitcpio -P
add_other_os_to_grub() {
    local target=$1
    local existing_part=$2
    local existing_subvol=$3

    echo -e "\033[1;36m▶ Добавление существующей ОС в загрузчик...\033[0m"

    # Создаем директорию для монтирования
    mkdir -p "$target/os"

    # Монтируем корневой раздел существующей ОС
    if [ -n "$existing_subvol" ]; then
        mount -o rw,subvol="$existing_subvol" "$existing_part" "$target/os"
    else
        mount "$existing_part" "$target/os"
    fi

    if [ $? -eq 0 ]; then
        echo "  → Корневой раздел смонтирован в $target/os"

        # Создаем необходимые директории для os-prober
        mkdir -p "$target/var/lib/os-prober"
        mkdir -p "$target/var/run/os-prober"
        mkdir -p "$target/tmp/os-prober"
        touch "$target/var/lib/os-prober/labels"

        # Включаем os-prober в настройках GRUB
        arch-chroot "$target" sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
        arch-chroot "$target" sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
        if ! grep -q "^GRUB_DISABLE_OS_PROBER=false" "$target/etc/default/grub"; then
            echo "GRUB_DISABLE_OS_PROBER=false" >> "$target/etc/default/grub"
        fi

        # Монтируем необходимые файловые системы для работы os-prober
        mount --bind /dev "$target/os/dev"
        mount --bind /proc "$target/os/proc"
        mount --bind /sys "$target/os/sys"

        # Запускаем os-prober для поиска систем
        echo "  → Запуск os-prober..."
        arch-chroot "$target" os-prober 2>&1 | grep -v "No such file" | while read line; do
            echo "    $line"
        done

        # Размонтируем временные файловые системы
        umount "$target/os/sys"
        umount "$target/os/proc"
        umount "$target/os/dev"

        # Обновляем конфигурацию GRUB
        echo "  → Обновление конфигурации GRUB..."
        arch-chroot "$target" grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | grep -v "No such file" | while read line; do
            echo "    $line"
        done

        # Размонтируем корневой раздел существующей ОС
        umount "$target/os"
        rmdir "$target/os"

        echo -e "\033[1;32m    ✓ Существующая ОС добавлена в загрузчик\033[0m"
    else
        echo -e "\033[1;31m    ✗ Ошибка монтирования существующей ОС\033[0m"
    fi
}
