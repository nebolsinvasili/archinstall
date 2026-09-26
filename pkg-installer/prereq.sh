#!/usr/bin/env bash
#
# prereq.sh
#
# Проверка и установка предустановленных пакетов (prerequisites)
# перед работой движка установки зависимостей.
#
# На текущий момент отвечает только за наличие jq.
#
# Требует:
#   root init.sh (log_*, utils.sh) и массив PREREQ_PACKAGES
#   из dependencies_installer.sh.
#

################################################################################
# Подготовка пакета
################################################################################

##
# ensure_prerequisite_package
#
# Устанавливает пакет через pacman, если он отсутствует.
#
# Parameters:
#   $1 - имя пакета
#
ensure_prerequisite_package() {

    local package="$1"

    if command_exists "$package"; then
        log_debug "Prerequisite package already installed: ${package}"
        return 0
    fi

    log_info "Installing prerequisite package: ${package}"

    if ! command_exists pacman; then
        log_error "pacman is not available. Unable to install '${package}'."
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] sudo pacman -S --needed ${package}"
        return 0
    fi

    sudo pacman -S --needed --noconfirm "$package"
}

################################################################################
# Проверка prereq-пакетов
################################################################################

##
# ensure_prereqs
#
# Проверяет наличие всех prereq-пакетов и доустанавливает недостающие.
#
# Используется массив PREREQ_PACKAGES,
# объявленный в dependencies_installer.sh.
#
ensure_prereqs() {

    local package

    for package in "${PREREQ_PACKAGES[@]}"; do
        ensure_prerequisite_package "$package"
    done
}