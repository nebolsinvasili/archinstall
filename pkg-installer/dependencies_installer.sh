#!/usr/bin/env bash
#
# dependencies_installer.sh
#
# Public API модуля установки зависимостей.
#
# Pipeline:
#   parse_args
#       ↓
#   ensure_prereqs
#       ↓
#   validate_managers
#       ↓
#   install_dependency_tree
#
# Все остальные функции располагаются в отдельных модулях.
#

set -euo pipefail

################################################################################
# Globals
################################################################################

declare -Ag MANAGERS=()

DRY_RUN=false
VERBOSE=false

DEPENDENCIES_FILE=""

PREREQ_PACKAGES=(
    dialog
    jq
)

################################################################################
# Module directory
################################################################################

readonly DEPENDENCIES_INSTALLER_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd
)"

################################################################################
# Load modules
################################################################################

source "$(dirname "$DEPENDENCIES_INSTALLER_DIR")/lib/init.sh"

source "${DEPENDENCIES_INSTALLER_DIR}/prereq.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/update.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/registry.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/missing.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/parser.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/cli.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/installer.sh"

################################################################################
# Load package managers
################################################################################

source "${DEPENDENCIES_INSTALLER_DIR}/managers/pacman.sh"
source "${DEPENDENCIES_INSTALLER_DIR}/managers/yay.sh"
#source "${DEPENDENCIES_INSTALLER_DIR}/managers/paru.sh"
#source "${DEPENDENCIES_INSTALLER_DIR}/managers/apt.sh"
#source "${DEPENDENCIES_INSTALLER_DIR}/managers/dnf.sh"
#source "${DEPENDENCIES_INSTALLER_DIR}/managers/zypper.sh"

################################################################################
# Register built-in managers
################################################################################

register_manager pacman \
    pkg_exists_pacman \
    install_pacman

register_manager yay \
    pkg_exists_yay \
    install_yay

# register_manager paru \
#     pkg_exists_paru \
#     install_paru

# register_manager apt \
#     pkg_exists_apt \
#     install_apt

# register_manager dnf \
#     pkg_exists_dnf \
#     install_dnf

# register_manager zypper \
#     pkg_exists_zypper \
#     install_zypper

################################################################################
# Public API
################################################################################

##
# install_dependencies
#
# Главная публичная функция модуля.
#
# Выполняет:
#
#   1. Разбор аргументов командной строки.
#   2. Проверку prereq-пакетов (jq при необходимости) — см. prereq.sh.
#   3. Проверку корректности зарегистрированных менеджеров.
#   4. Разбор дерева зависимостей.
#   5. Установку найденных пакетов.
#
# Usage:
#
#   install_dependencies "$@"
#

##
# Главная точка входа.
#
install_dependencies() {
    local -a cli_packages=()

    parse_args cli_packages "$@" # || return 1

    validate_managers

    update_managers

    if ((${#cli_packages[@]})); then


        install_block \
            "cli" \
            "auto" \
            "${cli_packages[@]}"


    else
        
        if [[ ! -f "$DEPENDENCIES_FILE" ]]; then

            log_error "ERROR: dependencies file not found:"
            echo "$DEPENDENCIES_FILE"
            exit 1
        fi
        
        install_dependency_tree \
            "$DEPENDENCIES_FILE"

    fi

    show_install_report
}

# ============================================================
# Main
# ============================================================
main()
{   
    ensure_prereqs
    install_dependencies "$@"
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
