#!/usr/bin/env bash
#
# update.sh
#
# Обновление менеджеров пакетов перед установкой.
#

set -euo pipefail


################################################################################
# update_manager
#
# Обновляет один менеджер пакетов.
#
# Parameters:
#   $1 - имя менеджера
#
################################################################################

update_manager() {
    local manager="$1"

    # Проверяем, установлена ли команда в системе (кроме pacman, он есть всегда)
    if [[ "$manager" != "pacman" ]] && ! command -v "$manager" &> /dev/null; then
        log_debug "Manager $manager is not installed. Skipping."
        return 0
     Keene
    fi

    case "$manager" in
         pacman)
             log_info "Updating pacman database..."
             sudo pacman -Sy
             ;;
          yay)
             log_info "Updating yay database..."
             yay -Sy
             ;;
          flatpak)
             log_info "Updating flatpak database..."
             flatpak update --appstream
             ;;
          cargo)
             log_info "Updating cargo registry..."
             cargo install-update -a
             ;;
          npm)
             log_info "Updating npm..."
             npm update -g
             ;;
          *)
             log_debug "No update handler for manager: $manager"
             ;;
     esac
}


################################################################################
# update_managers
#
# Обновляет все зарегистрированные менеджеры один раз.
#
################################################################################

update_managers()
{
    local manager


    log_info "Updating package managers..."


    for manager in "${!MANAGERS[@]}"; do

        update_manager "$manager"

    done


    log_info "Package managers updated."

}
