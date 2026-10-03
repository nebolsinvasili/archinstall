#!/usr/bin/env bash
# ============================================================
#
# pacman.sh
#
# Работа с pacman: настройка конфигов, обновление базы, зеркала
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__PACMAN_SH:-}" ]] && return
readonly __PACMAN_SH=1

# Функция для настройки pacman.conf на archiso
configure_archiso_pacman() {
    if [ -f /etc/pacman.conf ]; then
        sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
        if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
            sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
        fi
        sed -i 's/#Color/Color/' /etc/pacman.conf
        sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 6/' /etc/pacman.conf
    fi
}

# Функция для очистки блокировок pacman
cleanup_pacman_lock() {
    if [ -f /var/lib/pacman/db.lck ]; then
        rm -f /var/lib/pacman/db.lck
    fi
}

# Функция для настройки pacman в целевой системе
configure_pacman() {
    local target=$1
    sed -i "/\[multilib\]/,/Include/"'s/^#//' "$target/etc/pacman.conf"
    if ! grep -q "^ILoveCandy" "$target/etc/pacman.conf"; then
        sed -i '/^\[options\]/a ILoveCandy' "$target/etc/pacman.conf"
    fi
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 6/' "$target/etc/pacman.conf"
    sed -i 's/#Color/Color/' "$target/etc/pacman.conf"
    sed -i 's/#VerbosePkgLists/VerbosePkgLists/' "$target/etc/pacman.conf"
}

# Функция для обновления базы данных pacman
update_pacman_database() {
    echo -e "\033[1;36m▶ Обновление базы данных pacman...\033[0m"

    if [ -f /var/lib/pacman/db.lck ]; then
        echo -e "\033[1;33m  → Обнаружен файл блокировки db.lck, удаляем...\033[0m"
        rm -f /var/lib/pacman/db.lck
        echo -e "\033[1;32m  → Файл блокировки удален\033[0m"
    fi

    pacman -Sy --noconfirm 2>&1 | while read line; do
        echo "  $line"
    done

    echo -e "\033[1;32m✓ База данных обновлена\033[0m"
    echo ""
}

# Функция для сортировки зеркал
sort_mirrors() {
    print_banner
    echo ""
    echo -e "\033[1;33mСортировка зеркал ArchLinux...\033[0m"
    echo ""

    if ! command -v reflector &> /dev/null; then
        echo -e "\033[1;36m▶ Установка reflector...\033[0m"
        pacman -S --noconfirm reflector 2>&1
        echo -e "\033[1;32m✓ Reflector установлен\033[0m"
        echo ""
    fi

    if [ -f /etc/pacman.d/mirrorlist ]; then
        echo -e "\033[1;36m▶ Создание резервной копии mirrorlist...\033[0m"
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
        echo -e "\033[1;32m✓ Резервная копия создана\033[0m"
        echo ""
    fi

    echo -e "\033[1;36m▶ Сортировка зеркал...\033[0m"
    reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>&1

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m✓ Зеркала успешно отсортированы!\033[0m"
    else
        echo -e "\033[1;31m✗ Ошибка при сортировке зеркал\033[0m"
        if [ -f /etc/pacman.d/mirrorlist.backup ]; then
            cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
            echo -e "\033[1;32m✓ Резервная копия восстановлена\033[0m"
        fi
    fi

    echo ""
    update_pacman_database

    echo ""
    echo -e "\033[1;32m✅ Сортировка зеркал завершена!\033[0m"
    echo ""
    read -p "Нажмите Enter для возврата в главное меню..."
}
