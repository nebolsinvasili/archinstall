#!/usr/bin/env bash
# ============================================================
#
# desktop.sh
#
# Рабочие столы и оконные менеджеры: профили, установка, вход в систему
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__DESKTOP_SH:-}" ]] && return
readonly __DESKTOP_SH=1

# Функция для получения параметров выбранного профиля рабочего стола или WM
# Формат: "название|пакеты|флаги"
# Флаги: dw - рабочий стол Wayland (добавляется firefox), dX - рабочий стол Xorg
#        (полный набор xorg), w - WM Wayland, x - WM Xorg (минимальный набор),
#        xs:имя - WM Xorg без файла сессии, для него создаются .xinitrc и .desktop
desktop_profile() {
    # тег может прийти из whiptail в кавычках, например "2"
    local tag="${1//\"/}"
    case "$tag" in
        1)  echo "KDE Plasma (DE, Wayland)|plasma kde-applications plasma-wayland-protocols|dw" ;;
        2)  echo "GNOME (DE, Wayland)|gnome gnome-extra|dw" ;;
        3)  echo "LXQt (DE, Wayland)|lxqt breeze-icons lxqt-session|dw" ;;
        4)  echo "Cinnamon (DE, Wayland)|cinnamon|dw" ;;
        5)  echo "MATE (DE, Wayland)|mate mate-extra|dw" ;;
        6)  echo "Sway (WM, Wayland)|sway swaybg swaylock swayidle waybar foot|w" ;;
        7)  echo "Hyprland (WM, Wayland)|hyprland hyprlock waybar foot|w" ;;
        8)  echo "niri (WM, Wayland)|niri waybar foot|w" ;;
        9)  echo "River (WM, Wayland)|river waybar foot|w" ;;
        10) echo "Wayfire (WM, Wayland)|wayfire waybar foot|w" ;;
        11) echo "Qtile (WM, Wayland)|qtile waybar foot|w" ;;
        12) echo "KDE Plasma (DE, Xorg)|plasma kde-applications|dX" ;;
        13) echo "GNOME (DE, Xorg)|gnome gnome-extra|dX" ;;
        14) echo "XFCE (DE, Xorg)|xfce4 xfce4-goodies|dX" ;;
        15) echo "LXQt (DE, Xorg)|lxqt breeze-icons lxqt-session|dX" ;;
        16) echo "Cinnamon (DE, Xorg)|cinnamon|dX" ;;
        17) echo "MATE (DE, Xorg)|mate mate-extra|dX" ;;
        18) echo "i3 (WM, Xorg)|i3-wm i3status i3lock dmenu alacritty rofi picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|xs:i3" ;;
        19) echo "Openbox (WM, Xorg)|openbox tint2 alacritty nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid|x" ;;
        20) echo "bspwm (WM, Xorg)|bspwm sxhkd dmenu alacritty picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|x" ;;
        21) echo "dwm (WM, Xorg)|dwm dmenu alacritty picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|xs:dwm" ;;
        22) echo "Awesome (WM, Xorg)|awesome ttf-dejavu|x" ;;
        23) echo "Enlightenment (WM, Xorg)|enlightenment terminus-font|x" ;;
        *)  echo "" ;;
    esac
}

# Функция для получения списка названий выбранных профилей
desktop_list_names() {
    local tag info name result=""
    for tag in $1; do
        info=$(desktop_profile "$tag")
        [ -n "$info" ] || continue
        name="${info%%|*}"
        if [ -n "$result" ]; then
            result="$result, $name"
        else
            result="$name"
        fi
    done
    echo "$result"
}

# Короткое имя профиля без указания типа и графического стека
desktop_short_name() {
    local info name
    info=$(desktop_profile "$1")
    [ -n "$info" ] || return 1
    name="${info%%|*}"
    echo "${name%% (*}"
}

# Список коротких имён выбранных профилей через запятую
desktop_list_short_names() {
    local tag name result=""
    for tag in $1; do
        name=$(desktop_short_name "$tag") || continue
        [ -n "$name" ] || continue
        if [ -n "$result" ]; then
            result="$result, $name"
        else
            result="$name"
        fi
    done
    echo "$result"
}

# Значение для пункта меню: имена выбранных профилей, при нехватке места - счётчик остатка
desktops_menu_value() {
    local maxlen="${2:-50}"
    local list item line="" suffix="" i=0 total sep=0
    local -a names=()
    list=$(desktop_list_short_names "$1")
    if [ -z "$list" ]; then
        echo "Не устанавливать"
        return 0
    fi
    while [ -n "$list" ]; do
        item="$list"
        case "$list" in
            *,*) item="${list%%,*}"; list="${list#*, }" ;;
            *) list="" ;;
        esac
        names+=("$item")
    done
    total=${#names[@]}
    while [ $i -lt $total ]; do
        suffix=""
        if [ $(( total - i )) -gt 1 ]; then
            suffix=", ещё $(( total - i - 1 ))"
        fi
        sep=0
        [ $i -gt 0 ] && sep=2
        if [ $(( ${#line} + ${#names[$i]} + ${#suffix} + sep )) -le "$maxlen" ]; then
            if [ $i -gt 0 ]; then
                line="$line, ${names[$i]}"
            else
                line="${names[$i]}"
            fi
            i=$(( i + 1 ))
        else
            break
        fi
    done
    if [ $i -lt $total ]; then
        line="$line, ещё $(( total - i ))"
    fi
    printf '%s' "$line"
}

# Значение для экрана подтверждения: все выбранные профили одной строкой
desktops_summary() {
    local result
    result=$(desktop_list_names "$1")
    if [ -z "$result" ]; then
        echo "Не устанавливать"
    else
        echo "$result"
    fi
}

# Функция для формирования пунктов чеклиста с отметками текущего выбора
# Результат: CHECKLIST_ARGS=(tag описание статус ...)
build_checklist_args() {
    local current=" $1 "
    shift
    CHECKLIST_ARGS=()
    while [ $# -ge 2 ]; do
        local tag="$1"
        local desc="$2"
        shift 2
        local status="off"
        case "$current" in
            *" $tag "*) status="on" ;;
        esac
        CHECKLIST_ARGS+=("$tag" "$desc" "$status")
    done
}

# Функция для выбора рабочих столов и оконных менеджеров, можно выбрать несколько
# Отметка и снятие отметки выполняются пробелом
select_desktops() {
    build_checklist_args "$1" \
        "1"  "KDE Plasma (DE, Wayland)" \
        "2"  "GNOME (DE, Wayland)" \
        "3"  "LXQt (DE, Wayland)" \
        "4"  "Cinnamon (DE, Wayland, экспериментально)" \
        "5"  "MATE (DE, Wayland, экспериментально)" \
        "6"  "Sway (WM, Wayland)" \
        "7"  "Hyprland (WM, Wayland)" \
        "8"  "niri (WM, Wayland)" \
        "9"  "River (WM, Wayland)" \
        "10" "Wayfire (WM, Wayland)" \
        "11" "Qtile (WM, Wayland)" \
        "12" "KDE Plasma (DE, Xorg)" \
        "13" "GNOME (DE, Xorg)" \
        "14" "XFCE (DE, Xorg)" \
        "15" "LXQt (DE, Xorg)" \
        "16" "Cinnamon (DE, Xorg)" \
        "17" "MATE (DE, Xorg)" \
        "18" "i3 (WM, Xorg)" \
        "19" "Openbox (WM, Xorg)" \
        "20" "bspwm (WM, Xorg)" \
        "21" "dwm (WM, Xorg)" \
        "22" "Awesome (WM, Xorg)" \
        "23" "Enlightenment (WM, Xorg)"

    local dlg_w
    dlg_w=$(dialog_width)

    CHOICE=$(whiptail --title "Выбор рабочих столов и оконных менеджеров" \
                      --checklist "Пробел - отметить или снять отметку, Enter - подтвердить\nМожно выбрать несколько или оставить список пустым:" 24 "$dlg_w" 16 \
                      "${CHECKLIST_ARGS[@]}" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    # whiptail возвращает теги чеклиста в кавычках ("2" "3") - убираем их
    echo "${CHOICE//\"/}"
    return 0
}

# Функция для получения названия диспетчера входа по его коду
display_manager_name() {
    case "$1" in
        "1") echo "Ly (терминальный)" ;;
        "2") echo "SDDM" ;;
        "3") echo "GDM" ;;
        "4") echo "LightDM" ;;
        "0") echo "Не устанавливать" ;;
        *) echo "Не выбран" ;;
    esac
}

# Функция для выбора диспетчера входа (автоустановка)
select_display_manager_auto() {
    CHOICE=$(whiptail --title "Выбор диспетчера входа" \
                      --menu "Выберите менеджер входа в систему:\n\nLy - терминальный, самый быстрый (по умолчанию)" 17 70 5 \
                      "1" "Ly (терминальный, по умолчанию)" \
                      "2" "SDDM (KDE Plasma)" \
                      "3" "GDM (GNOME)" \
                      "4" "LightDM (XFCE, Cinnamon, MATE)" \
                      "0" "Не устанавливать" \
                      --default-item "1" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo "$CHOICE"
    return 0
}

# Функция для выбора диспетчера входа (ручная установка)
# Диалог общий с автоустановкой
select_display_manager_manual() {
    select_display_manager_auto
}


# Функция для проверки наличия в списке GNOME
desktop_list_has_gnome() {
    local tag
    for tag in $1; do
        case "$tag" in
            2|13) return 0 ;;
        esac
    done
    return 1
}

# Функция для проверки наличия в списке WM без собственного файла сессии
desktop_list_has_bare_wm() {
    local tag info flags
    for tag in $1; do
        info=$(desktop_profile "$tag")
        [ -n "$info" ] || continue
        flags="${info##*|}"
        case "$flags" in
            xs:*) return 0 ;;
        esac
    done
    return 1
}

# Функция для настройки запуска оконного менеджера без файла сессии
setup_wm_session() {
    local target=$1
    local user=$2
    local wm=$3

    if [ -z "$user" ]; then
        return 0
    fi

    if [ ! -f "$target/home/$user/.xinitrc" ]; then
        cat > "$target/home/$user/.xinitrc" <<EOF
#!/bin/sh
exec $wm
EOF
        arch-chroot "$target" chown "$user:$user" "/home/$user/.xinitrc"
        arch-chroot "$target" chmod +x "/home/$user/.xinitrc"
    fi

    mkdir -p "$target/usr/share/xsessions"
    cat > "$target/usr/share/xsessions/$wm.desktop" <<EOF
[Desktop Entry]
Name=$wm
Comment=Оконный менеджер $wm
Exec=/usr/bin/$wm
Type=Application
DesktopNames=$wm
EOF
}

# Функция для настройки автоматического запуска графической сессии на tty1
setup_tty_autostart() {
    local target=$1
    local user=$2

    if [ -z "$user" ]; then
        return 0
    fi

    # файл входа зависит от оболочки: zsh читает .zprofile, bash - .bash_profile
    local shell
    local rc_file=".bash_profile"
    shell=$(arch-chroot "$target" getent passwd "$user" | cut -d: -f7)
    case "$shell" in
        */zsh) rc_file=".zprofile" ;;
    esac

    cat >> "$target/home/$user/$rc_file" <<EOF

if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    startx
fi
EOF
    arch-chroot "$target" chown "$user:$user" "/home/$user/$rc_file"
}

# Функция для установки выбранных рабочих столов и оконных менеджеров
install_desktop_group() {
    local target=$1
    local list=$2
    local user=$3
    local packages=""
    local need_wayland=0
    local need_xorg=0
    local need_xorg_full=0
    local need_firefox=0
    local tag info name rest pkgs flags wm

    if [ -z "$list" ]; then
        return 0
    fi

    for tag in $list; do
        info=$(desktop_profile "$tag")
        if [ -z "$info" ]; then
            echo -e "\033[1;33m  ! Неизвестный вариант DE/WM: $tag\033[0m"
            continue
        fi
        name="${info%%|*}"
        rest="${info#*|}"
        pkgs="${rest%%|*}"
        flags="${rest##*|}"
        echo "  → Установка: $name"
        packages="$packages $pkgs"
        case "$flags" in
            dw|dX) need_firefox=1 ;;
        esac
        case "$flags" in
            dw|w) need_wayland=1 ;;
        esac
        case "$flags" in
            dX) need_xorg=1; need_xorg_full=1 ;;
            x|xs:*) need_xorg=1 ;;
        esac
        case "$flags" in
            xs:*)
                wm="${flags#xs:}"
                echo "  → Настройка запуска $wm..."
                setup_wm_session "$target" "$user" "$wm"
                ;;
        esac
    done

    if [ "$need_wayland" -eq 1 ]; then
        packages="$packages wayland xorg-xwayland"
    fi
    if [ "$need_xorg_full" -eq 1 ]; then
        packages="$packages xorg"
    fi
    if [ "$need_xorg" -eq 1 ] && [ "$need_xorg_full" -eq 0 ]; then
        packages="$packages xorg-server xorg-xinit"
    fi
    if [ "$need_firefox" -eq 1 ]; then
        packages="$packages firefox"
    fi

    if [ -z "$packages" ]; then
        return 0
    fi

    echo "  → Установка пакетов..."
    arch-chroot "$target" pacman -S --noconfirm $packages
}

# Функция для установки диспетчера входа
install_display_manager() {
    local target=$1
    local dm=$2
    local desktops=$3

    if [ "$dm" != "3" ] && desktop_list_has_gnome "$desktops"; then
        echo -e "\033[1;33m  ! Для GNOME рекомендуется GDM, с другими менеджерами входа часть функций может не работать\033[0m"
    fi

    case "$dm" in
        "1")
            echo "  → Установка диспетчера входа Ly..."
            arch-chroot "$target" pacman -S --noconfirm ly
            arch-chroot "$target" systemctl enable ly.service
            ;;
        "2")
            echo "  → Установка диспетчера входа SDDM..."
            arch-chroot "$target" pacman -S --noconfirm sddm sddm-kcm
            arch-chroot "$target" systemctl enable sddm.service
            ;;
        "3")
            echo "  → Установка диспетчера входа GDM..."
            arch-chroot "$target" pacman -S --noconfirm gdm
            arch-chroot "$target" systemctl enable gdm.service
            ;;
        "4")
            echo "  → Установка диспетчера входа LightDM..."
            arch-chroot "$target" pacman -S --noconfirm lightdm lightdm-gtk-greeter
            arch-chroot "$target" systemctl enable lightdm.service
            ;;
        *)
            echo "  → Диспетчер входа не устанавливается"
            ;;
    esac
}
