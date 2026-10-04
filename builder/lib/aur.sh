#!/usr/bin/env bash
# ============================================================
#
# aur.sh
#
# Установка помощника AUR (yay) в установленную систему
#
# Схема повторяет managers/aur/setup.sh: git clone из AUR и сборка
# через makepkg, только внутри целевой системы и от её пользователя,
# так как makepkg не работает от root.
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__AUR_SH:-}" ]] && return
readonly __AUR_SH=1

# Функция для получения зависимостей сборки из PKGBUILD
# Читает PKGBUILD из стандартного ввода, печатает зависимости списком
# Учитывает многострочные массивы depends, makedepends и checkdepends
pkbuild_deps() {
    local flat key array

    flat=$(tr '\n' ' ')

    for key in depends makedepends checkdepends; do
        array=$(printf '%s' "$flat" | grep -oE "(^| )$key=\([^)]*\)" \
                | sed -E "s/.*\(([^)]*)\).*/\1/" | tr -d "'\"")
        if [ -n "$array" ]; then
            printf '%s ' "$array"
        fi
    done | tr -s ' ' '\n' | grep -v '^$' | awk '!seen[$0]++'
}

# Функция для установки yay в установленную систему
install_yay() {
    local target=$1
    local user=$2

    local build_dir="/tmp/yay-build"
    local deps pkg

    if [ -z "$user" ]; then
        echo -e "\033[1;33m  ! Yay пропущен: пользователь не создан\033[0m"
        return 1
    fi

    if arch-chroot "$target" command -v yay &> /dev/null; then
        echo "  → Yay уже установлен"
        return 0
    fi

    echo "  → Установка yay (помощник AUR)..."

    # git нужен для получения исходников, sudo - для сборки от пользователя
    arch-chroot "$target" pacman -S --noconfirm --needed git sudo

    arch-chroot "$target" rm -rf "$build_dir"
    arch-chroot "$target" mkdir -p "$build_dir/yay"
    arch-chroot "$target" chown "$user:$user" "$build_dir" "$build_dir/yay"

    arch-chroot "$target" sudo -u "$user" \
        git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"

    # зависимости для сборки берём из самого PKGBUILD, чтобы не хардкодить список
    deps=$(arch-chroot "$target" cat "$build_dir/yay/PKGBUILD" | pkbuild_deps)

    if [ -n "$deps" ]; then
        echo "  → Зависимости сборки: $(echo "$deps" | tr '\n' ' ')"
        # shellcheck disable=SC2086
        arch-chroot "$target" pacman -S --noconfirm --needed $deps
    fi

    # makepkg не работает от root, поэтому сборка от пользователя
    # без -s, чтобы не требовать пароль sudo для установки зависимостей
    if ! arch-chroot "$target" sudo -u "$user" \
            bash -c "cd '$build_dir/yay' && makepkg --noconfirm"; then
        echo -e "\033[1;31m  ✗ Сборка yay не удалась\033[0m"
        arch-chroot "$target" rm -rf "$build_dir"
        return 1
    fi

    if ! arch-chroot "$target" bash -c \
            "pkg=\$(find '$build_dir/yay' -name '*.pkg.tar.zst' | head -n 1); \
             [ -n \"\$pkg\" ] && pacman -U --noconfirm \"\$pkg\""; then
        echo -e "\033[1;31m  ✗ Установка собранного пакета yay не удалась\033[0m"
        arch-chroot "$target" rm -rf "$build_dir"
        return 1
    fi

    arch-chroot "$target" rm -rf "$build_dir"

    if arch-chroot "$target" command -v yay &> /dev/null; then
        echo -e "\033[1;32m  ✓ Yay установлен: $(arch-chroot "$target" sudo -u "$user" bash -c 'yay --version | head -n 1')\033[0m"
    else
        echo -e "\033[1;31m  ✗ Не удалось установить yay\033[0m"
        return 1
    fi
}