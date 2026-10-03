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
# Usage
# ============================================================
usage() {

    cat <<EOF
${C_CYAN}Установка zsh${C_RESET}

${C_CYAN}Использование:${C_RESET}
  $0 [-h] [пользователь...]

${C_CYAN}Аргументы:${C_RESET}
  пользователь   учётная запись (можно указать несколько через пробел или запятую)

${C_CYAN}Примеры:${C_RESET}
  $0                      zsh для всех пользователей
  $0 tester               zsh только для tester
  $0 tester,svc           zsh для tester и svc
  $0 -n                   установка пакетов в режиме dry-run
EOF
}

# ============================================================
# zsh
# ============================================================
ensure_zsh_installed() {

    if command -v zsh >/dev/null 2>&1; then
        log_ok "zsh уже установлен."
        return 0
    fi

    log_info "Устанавливаем zsh..."

    if [[ $EUID -eq 0 ]]; then
        pacman -S --noconfirm zsh
    else
        sudo pacman -S --noconfirm zsh
    fi
}

# Без записи в /etc/shells chsh откажется назначать zsh
ensure_zsh_in_shells() {

    if grep -qxF /bin/zsh /etc/shells; then
        return 0
    fi

    log_info "Добавляем /bin/zsh в /etc/shells..."

    if [[ $EUID -eq 0 ]]; then
        echo /bin/zsh >> /etc/shells
    else
        echo /bin/zsh | sudo tee -a /etc/shells >/dev/null
    fi
}

# Пользователи для обработки: переданный список или, если он пуст,
# Если список пользователей не передан - берём root и все учётные записи
# с UID 1000-65534, иначе используем только переданный список
list_shell_users() {

    local -a requested=("$@")

    if [[ ${#requested[@]} -eq 0 ]]; then
        getent passwd |
            awk -F: '($1 == "root" || ($3 >= 1000 && $3 < 65534)) { print $1 }'
        return 0
    fi

    local user name resolved=()
    local -a names=()

    # список мог прийти как "tester,svc"
    for user in "${requested[@]}"; do
        names+=("${user//,/ }")
    done

    for name in ${names[@]}; do
        user="$(getent passwd "$name" | cut -d: -f1)"

        if [[ -z "$user" ]]; then
            log_error "Пользователь не найден: $name."
            return 1
        fi

        resolved+=("$user")
    done

    printf '%s\n' "${resolved[@]}"
}

apply_shell() {

    local user="$1"
    local shell="$2"

    if [[ $EUID -eq 0 ]]; then
        usermod -s "$shell" "$user"
    else
        sudo usermod -s "$shell" "$user"
    fi
}

# zsh оболочкой по умолчанию: для переданных пользователей или для всех
set_shell_for_users() {

    local shell="/bin/zsh"
    local user current found
    local changed=0
    local failed=0
    local -a users=()

    if ! found="$(list_shell_users "$@")"; then
        return 1
    fi

    mapfile -t users < <(printf '%s\n' "$found" | grep -v '^$' | sort -u)

    if [[ ${#users[@]} -eq 0 ]]; then
        log_error "Не найдено пользователей для обработки."
        return 1
    fi

    for user in "${users[@]}"; do
        current="$(getent passwd "$user" | cut -d: -f7)"

        if [[ "$current" == "$shell" ]]; then
            log_info "Оболочка пользователя $user уже $shell."
            continue
        fi

        if apply_shell "$user" "$shell"; then
            log_ok "Оболочка пользователя $user: $shell"
            changed=1
        else
            log_error "Не удалось сменить оболочку пользователя $user."
            failed=$(( failed + 1 ))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_error "Оболочка не изменена у $failed пользователей."
    elif [[ $changed -eq 0 ]]; then
        log_info "Смена оболочки не требуется."
    fi
}

# ============================================================
# Main
# ============================================================
main() {

    local -a users=()

    while (($#)); do
        case "$1" in

            -h|--help)

                usage
                return 0
                ;;

            -*)
                # флаги установщика пакетов (например -n) не касаются zsh
                shift
                ;;

            *)

                users+=("$1")
                shift
                ;;

        esac
    done

    log_info "Changing shell..."

    ensure_zsh_installed
    ensure_zsh_in_shells
    set_shell_for_users "${users[@]}"

    log_ok "Установка успешно завершена."
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
