#!/usr/bin/env bash
# ============================================================
#
# user.sh
#
# Пользователи, оболочка по умолчанию и стандартные папки
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__USER_SH:-}" ]] && return
readonly __USER_SH=1

# Функция для создания пользователя (автоустановка)
create_user_account() {
    USERNAME=$(whiptail --title "Создание учетной записи" \
                        --inputbox "Введите имя пользователя:" 8 60 \
                        3>&1 1>&2 2>&3 \
                        --ok-button "Далее" --cancel-button "Отмена")
    if [ $? -ne 0 ] || [ -z "$USERNAME" ]; then
        return 1
    fi
    while true; do
        USERPASS=$(whiptail --title "Создание учетной записи" \
                            --passwordbox "Введите пароль для пользователя $USERNAME:" 8 60 \
                            3>&1 1>&2 2>&3 \
                            --ok-button "Далее" --cancel-button "Отмена")
        if [ $? -ne 0 ]; then
            return 1
        fi
        USERPASS_CONFIRM=$(whiptail --title "Создание учетной записи" \
                                    --passwordbox "Подтвердите пароль:" 8 60 \
                                    3>&1 1>&2 2>&3 \
                                    --ok-button "Далее" --cancel-button "Отмена")
        if [ $? -ne 0 ]; then
            return 1
        fi
        if [ "$USERPASS" = "$USERPASS_CONFIRM" ] && [ -n "$USERPASS" ]; then
            break
        else
            whiptail --title "Ошибка" --msgbox "Пароли не совпадают или пустые!" 8 40
        fi
    done
    ROOTPASS="$USERPASS"
    echo "$USERNAME:$USERPASS:$ROOTPASS"
    return 0
}

# Функция для создания пользователя
create_user_manual() {
    USERNAME=$(whiptail --title "Создание учетной записи" \
                        --inputbox "Введите имя пользователя:" 8 60 \
                        3>&1 1>&2 2>&3 \
                        --ok-button "Далее" --cancel-button "Отмена")
    if [ $? -ne 0 ] || [ -z "$USERNAME" ]; then
        return 1
    fi
    while true; do
        USERPASS=$(whiptail --title "Создание учетной записи" \
                            --passwordbox "Введите пароль для пользователя $USERNAME:" 8 60 \
                            3>&1 1>&2 2>&3 \
                            --ok-button "Далее" --cancel-button "Отмена")
        if [ $? -ne 0 ]; then
            return 1
        fi
        USERPASS_CONFIRM=$(whiptail --title "Создание учетной записи" \
                                    --passwordbox "Подтвердите пароль:" 8 60 \
                                    3>&1 1>&2 2>&3 \
                                    --ok-button "Далее" --cancel-button "Отмена")
        if [ $? -ne 0 ]; then
            return 1
        fi
        if [ "$USERPASS" = "$USERPASS_CONFIRM" ] && [ -n "$USERPASS" ]; then
            break
        else
            whiptail --title "Ошибка" --msgbox "Пароли не совпадают или пустые!" 8 40
        fi
    done
    echo "$USERNAME:$USERPASS:$USERPASS"
    return 0
}

# Функция для назначения zsh оболочкой по умолчанию для всех пользователей
set_default_shell() {
    local target=$1
    local shell="/bin/zsh"

    if [ ! -e "$target$shell" ]; then
        echo "  → Установка zsh..."
        arch-chroot "$target" pacman -S --noconfirm zsh
    fi

    if ! grep -qxF "$shell" "$target/etc/shells" 2>/dev/null; then
        echo "$shell" >> "$target/etc/shells"
    fi

    local users user current
    users=$(arch-chroot "$target" getent passwd | awk -F: '($1 == "root" || ($3 >= 1000 && $3 < 65534)) { print $1 }')

    for user in $users; do
        current=$(arch-chroot "$target" getent passwd "$user" | cut -d: -f7)
        if [ "$current" != "$shell" ]; then
            arch-chroot "$target" usermod -s "$shell" "$user"
            echo "  → Оболочка пользователя $user: $shell"
        else
            echo "  → Оболочка пользователя $user уже $shell"
        fi
    done
}

# Функция для создания стандартных пользовательских папок с английскими именами
# (XDG user dirs), чтобы локаль ru_RU не подставляла русские названия
configure_user_dirs() {
    local target=$1
    local user=$2

    local -a dirs=(
        Desktop
        Documents
        Downloads
        Music
        Pictures
        Public
        Templates
        Videos
    )

    # системный default для всех новых пользователей, включая root
    mkdir -p "$target/etc/xdg"
    cat > "$target/etc/xdg/user-dirs.conf" <<'EOF'
enabled=True
user-xdg-desktop-dir="$HOME/Desktop"
user-xdg-documents-dir="$HOME/Documents"
user-xdg-download-dir="$HOME/Downloads"
user-xdg-music-dir="$HOME/Music"
user-xdg-pictures-dir="$HOME/Pictures"
user-xdg-publicshare-dir="$HOME/Public"
user-xdg-templates-dir="$HOME/Templates"
user-xdg-videos-dir="$HOME/Videos"
EOF

    # то же в /etc/skel, чтобы новые пользователи получали английские папки
    mkdir -p "$target/etc/skel/.config"
    cat > "$target/etc/skel/.config/user-dirs.dirs" <<'EOF'
enabled=True
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

    if [ -z "$user" ] || [ ! -d "$target/home/$user" ]; then
        echo "  → Стандартные папки (XDG): только системный default"
        return 0
    fi

    local home="$target/home/$user"
    local dir

    echo "  → Создание стандартных папок пользователя $user (английские имена)..."

    mkdir -p "$home/.config"

    for dir in "${dirs[@]}"; do
        mkdir -p "$home/$dir"
    done

    cat > "$home/.config/user-dirs.dirs" <<'EOF'
# This file is written by xdg-user-dirs-update
# If you want to remove or change a directory, just edit the lines below.
enabled=True
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_VIDEOS_DIR="$HOME/Videos"
EOF

    arch-chroot "$target" chown -R "$user:$user" "/home/$user/.config"

    for dir in "${dirs[@]}"; do
        arch-chroot "$target" chown "$user:$user" "/home/$user/$dir"
    done
}
