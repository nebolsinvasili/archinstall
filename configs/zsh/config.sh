#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

# Поиск корня репозитория по маркеру "pkg-installer" и подключение окружения.
ROOT_DIR="$SCRIPT_DIR"
while [[ ! -d "$ROOT_DIR/pkg-installer" && "$ROOT_DIR" != "/" ]]; do
    ROOT_DIR="$(dirname "$ROOT_DIR")"
done

[[ -f "$ROOT_DIR/lib/init.sh" ]] || {
    echo "Не найден корень проекта (маркер 'pkg-installer')." >&2
    exit 1
}

source "$ROOT_DIR/lib/init.sh"

# ============================================================
# Progress bar
# ============================================================
progress_bar() {
    local duration="${1:-3}"
    local width=30

    local delay
    delay=$(awk "BEGIN{printf \"%.3f\", ${duration}/${width}}")

    for ((i=0; i<=width; i++)); do
        local percent=$((i*100/width))

        printf "\r${C_CYAN}Загрузка:${C_RESET} ["

        printf "%${i}s" "" | tr ' ' '#'
        printf "%$((width-i))s" "" | tr ' ' '-'

        printf "] %3d%%" "$percent"

        sleep "$delay"
    done

    printf "\n"
}

# ============================================================
# User selection
# ============================================================
choose_user() {

    local users=()

    mapfile -t users < <(
        getent passwd |
        awk -F: '$6 ~ "^/home/" {print $1}'
    )

    if [[ ${#users[@]} -eq 0 ]]; then
        echo "Не найдено пользователей." >&2
        return 1
    fi

    log_info "Выберите пользователя:" >&2

    local i
    for i in "${!users[@]}"; do
        printf "  ${C_YELLOW}%2d)${C_RESET} %s\n" \
            "$((i+1))" "${users[$i]}" >&2
    done

    printf "  ${C_YELLOW}%2d)${C_RESET} root\n" 0 >&2

    local choice

    read -rp "Введите номер [1]: " choice
    choice=${choice:-1}

    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        echo "Некорректный ввод." >&2
        return 1
    fi

    if ((choice == 0)); then
        echo "root /root"
        return 0
    fi

    if ((choice < 1 || choice > ${#users[@]})); then
        echo "Некорректный выбор." >&2
        return 1
    fi

    local user="${users[$((choice-1))]}"

    echo "$user /home/$user"
}

# ============================================================
# Shell selection
# ============================================================
choose_shell() {

    local shells=()

    mapfile -t shells < <(grep '^/' /etc/shells)

    echo >&2
    echo "Доступные shell:" >&2

    local i

    for i in "${!shells[@]}"; do
        printf "  ${C_YELLOW}%2d)${C_RESET} %s\n" \
            "$((i+1))" "${shells[$i]}" >&2
    done

    local choice

    read -rp "Введите номер [1]: " choice
    choice=${choice:-1}

    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        echo "Некорректный ввод." >&2
        return 1
    fi

    if ((choice < 1 || choice > ${#shells[@]})); then
        echo "Некорректный выбор." >&2
        return 1
    fi

    echo "${shells[$((choice-1))]}"
}

# ============================================================
# Change shell
# ============================================================
change_shell() {

    local user="$1"
    local shell="$2"

    if ! grep -qxF "$shell" /etc/shells; then
        log_error "Shell отсутствует в /etc/shells: $shell"
        return 1
    fi

    current_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"

    if [[ "$current_shell" == "$NEWSHELL" ]]; then
        log_info "Shell уже установлен: $NEWSHELL"
    else
        if sudo chsh -s "$NEWSHELL" "$TARGET_USER"; then
            log_ok "Shell изменён."
        else
            log_error "Ошибка смены shell."
            exit 1
        fi
    fi
}

# ============================================================
# Install dotfiles
# ============================================================
install_dotfiles() {

    local target="$1"

    stow \
        --adopt \
        -R \
        -d "$SCRIPT_DIR" \
        -t "$TARGET_HOME" \
        config
}

# ============================================================
# Main
# ============================================================
main() {
    
    log_info "Changing shell..."

    local TARGET_USER
    local TARGET_HOME
    local NEWSHELL

    if ! read -r TARGET_USER TARGET_HOME < <(choose_user); then
        log_error "Выбор пользователя отменён."
        exit 1
    fi

    log_info "Пользователь: $TARGET_USER"
    log_info "Домашний каталог: $TARGET_HOME"

    if ! NEWSHELL=$(choose_shell); then
        log_error "Выбор shell отменён."
        exit 1
    fi

    log_info "Выбран shell: $NEWSHELL"

    change_shell "$TARGET_USER" "$NEWSHELL"

    log_info "Устанавливаем dotfiles..."

    install_dotfiles "$TARGET_HOME"

    log_ok "Dotfiles установлены."

    progress_bar 2

    log_ok "Установка успешно завершена."

    if [[ "$TARGET_USER" == "$(whoami)" ]]; then
        exec "$NEWSHELL" -l
    fi
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"