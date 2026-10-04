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
# У KDE Plasma и GNOME есть две версии: полная и облегчённая (минимальный
# набор пакетов: оболочка, терминал и файловый менеджер)
desktop_profile() {
    # тег может прийти из whiptail в кавычках, например "2"
    local tag="${1//\"/}"
    case "$tag" in
        1)  echo "KDE Plasma (DE, Wayland, полная)|plasma kde-applications plasma-wayland-protocols|dw" ;;
        2)  echo "KDE Plasma (DE, Wayland, облегчённая)|plasma konsole dolphin plasma-wayland-protocols|dw" ;;
        3)  echo "GNOME (DE, Wayland, полная)|gnome gnome-extra|dw" ;;
        4)  echo "GNOME (DE, Wayland, облегчённая)|gnome-shell gnome-terminal nautilus|dw" ;;
        5)  echo "LXQt (DE, Wayland)|lxqt breeze-icons lxqt-session|dw" ;;
        6)  echo "Cinnamon (DE, Wayland, экспериментально)|cinnamon|dw" ;;
        7)  echo "MATE (DE, Wayland, экспериментально)|mate mate-extra|dw" ;;
        8)  echo "Sway (WM, Wayland)|sway swaybg swaylock swayidle waybar foot|w" ;;
        9)  echo "Hyprland (WM, Wayland)|hyprland hyprlock waybar foot|w" ;;
        10) echo "niri (WM, Wayland)|niri waybar foot|w" ;;
        11) echo "River (WM, Wayland)|river waybar foot|w" ;;
        12) echo "Wayfire (WM, Wayland)|wayfire waybar foot|w" ;;
        13) echo "Qtile (WM, Wayland)|qtile waybar foot|w" ;;
        14) echo "KDE Plasma (DE, Xorg, полная)|plasma plasma-x11-session kde-applications|dX" ;;
        15) echo "KDE Plasma (DE, Xorg, облегчённая)|plasma plasma-x11-session konsole dolphin|dX" ;;
        16) echo "GNOME (DE, Xorg, полная)|gnome gnome-extra|dX" ;;
        17) echo "GNOME (DE, Xorg, облегчённая)|gnome-shell gnome-terminal nautilus|dX" ;;
        18) echo "XFCE (DE, Xorg)|xfce4 xfce4-goodies|dX" ;;
        19) echo "LXQt (DE, Xorg)|lxqt breeze-icons lxqt-session|dX" ;;
        20) echo "Cinnamon (DE, Xorg)|cinnamon|dX" ;;
        21) echo "MATE (DE, Xorg)|mate mate-extra|dX" ;;
        22) echo "i3 (WM, Xorg)|i3-wm i3status i3lock dmenu alacritty rofi picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|xs:i3" ;;
        23) echo "Openbox (WM, Xorg)|openbox tint2 alacritty nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid|x" ;;
        24) echo "bspwm (WM, Xorg)|bspwm sxhkd dmenu alacritty picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|x" ;;
        25) echo "dwm (WM, Xorg)|dwm dmenu alacritty picom nitrogen feh network-manager-applet volumeicon xss-lock polkit-gnome ttf-dejavu ttf-droid ttf-font-awesome|xs:dwm" ;;
        26) echo "Awesome (WM, Xorg)|awesome ttf-dejavu|x" ;;
        27) echo "Enlightenment (WM, Xorg)|enlightenment terminus-font|x" ;;
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
# Вариант (полная/облегчённая) в имени сохраняется:
# "KDE Plasma (DE, Wayland, облегчённая)" -> "KDE Plasma (облегчённая)"
desktop_short_name() {
    local info name inner variant
    info=$(desktop_profile "$1")
    [ -n "$info" ] || return 1
    name="${info%%|*}"
    case "$name" in
        *"("*")") ;;
        *) echo "$name"; return 0 ;;
    esac
    inner="${name#* (}"
    inner="${inner%)}"
    variant=""
    case "$inner" in
        *,*,*) variant="${inner##*, }" ;;
    esac
    name="${name%% (*}"
    if [ -n "$variant" ]; then
        name="$name ($variant)"
    fi
    echo "$name"
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
        "1"  "KDE Plasma (DE, Wayland, полная)" \
        "2"  "KDE Plasma (DE, Wayland, облегчённая)" \
        "3"  "GNOME (DE, Wayland, полная)" \
        "4"  "GNOME (DE, Wayland, облегчённая)" \
        "5"  "LXQt (DE, Wayland)" \
        "6"  "Cinnamon (DE, Wayland, экспериментально)" \
        "7"  "MATE (DE, Wayland, экспериментально)" \
        "8"  "Sway (WM, Wayland)" \
        "9"  "Hyprland (WM, Wayland)" \
        "10" "niri (WM, Wayland)" \
        "11" "River (WM, Wayland)" \
        "12" "Wayfire (WM, Wayland)" \
        "13" "Qtile (WM, Wayland)" \
        "14" "KDE Plasma (DE, Xorg, полная)" \
        "15" "KDE Plasma (DE, Xorg, облегчённая)" \
        "16" "GNOME (DE, Xorg, полная)" \
        "17" "GNOME (DE, Xorg, облегчённая)" \
        "18" "XFCE (DE, Xorg)" \
        "19" "LXQt (DE, Xorg)" \
        "20" "Cinnamon (DE, Xorg)" \
        "21" "MATE (DE, Xorg)" \
        "22" "i3 (WM, Xorg)" \
        "23" "Openbox (WM, Xorg)" \
        "24" "bspwm (WM, Xorg)" \
        "25" "dwm (WM, Xorg)" \
        "26" "Awesome (WM, Xorg)" \
        "27" "Enlightenment (WM, Xorg)"

    local dlg_w
    dlg_w=$(dialog_width)

    CHOICE=$(whiptail --title "Выбор рабочих столов и оконных менеджеров" \
                      --checklist "Пробел - отметить или снять отметку, Enter - подтвердить\nМожно выбрать несколько или оставить список пустым, KDE и GNOME есть облегчённые версии:" 24 "$dlg_w" 16 \
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
            3|4|16|17) return 0 ;;
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
