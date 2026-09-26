#!/usr/bin/env bash
#
# registry.sh
#
# Реестр менеджеров пакетов.
#
# Формат хранения:
#
#   MANAGERS["pacman"]="pkg_exists_pacman install_pacman"
#
# где
#
#   checker   — функция проверки существования пакета
#   installer — функция установки пакета
#

################################################################################
# register_manager
################################################################################

##
# Регистрирует менеджер пакетов.
#
# Usage:
#
#   register_manager \
#       pacman \
#       pkg_exists_pacman \
#       install_pacman
#
# Parameters:
#
#   $1 manager
#   $2 checker
#   $3 installer
#
register_manager() {

    local manager="$1"
    local checker="$2"
    local installer="$3"

    if [[ -z "$manager" ]]; then
        log_error "register_manager(): empty manager name."
        return 1
    fi

    if [[ -z "$checker" ]]; then
        log_error "register_manager(): empty checker for '$manager'."
        return 1
    fi

    if [[ -z "$installer" ]]; then
        log_error "register_manager(): empty installer for '$manager'."
        return 1
    fi

    MANAGERS["$manager"]="$checker $installer"
}

################################################################################
# validate_managers
################################################################################

##
# Проверяет корректность всех зарегистрированных менеджеров.
#
# Проверяется существование функций checker/installer.
#
validate_managers() {

    local manager
    local checker
    local installer

    for manager in "${!MANAGERS[@]}"; do

        read -r checker installer <<<"${MANAGERS[$manager]}"

        if ! declare -F "$checker" >/dev/null; then
            log_error "Manager '$manager': checker '$checker' is not defined."
            return 1
        fi

        if ! declare -F "$installer" >/dev/null; then
            log_error "Manager '$manager': installer '$installer' is not defined."
            return 1
        fi

    done
}

################################################################################
# resolve_managers
################################################################################

##
# Возвращает список менеджеров в порядке проверки.
#
# Правила:
#
# manager="auto"
#
#     pacman
#     yay
#     paru
#     ...
#
# manager="yay"
#
#     yay
#     pacman
#     paru
#     ...
#
# manager="paru"
#
#     paru
#     pacman
#     yay
#     ...
#
# Output:
#
# список менеджеров по одному в строке
#
resolve_managers() {

    local preferred="${1:-auto}"

    local manager

    if [[ "$preferred" != "auto" ]]; then

        if [[ -n "${MANAGERS[$preferred]:-}" ]]; then
            printf '%s\n' "$preferred"
        else
            log_error "Unknown package manager: $preferred"
            return 1
        fi

    fi

    for manager in "${!MANAGERS[@]}"; do

        [[ "$manager" == "$preferred" ]] && continue

        printf '%s\n' "$manager"

    done
}

################################################################################
# manager_checker
################################################################################

##
# Возвращает checker-функцию зарегистрированного менеджера.
#
# Parameters:
#
#   $1 manager
#
manager_checker() {

    local manager="$1"

    local checker
    local installer

    read -r checker installer <<<"${MANAGERS[$manager]}"

    printf '%s\n' "$checker"
}

################################################################################
# manager_installer
################################################################################

##
# Возвращает installer-функцию зарегистрированного менеджера.
#
# Parameters:
#
#   $1 manager
#
manager_installer() {

    local manager="$1"

    local checker
    local installer

    read -r checker installer <<<"${MANAGERS[$manager]}"

    printf '%s\n' "$installer"
}