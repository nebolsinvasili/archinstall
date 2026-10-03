#!/usr/bin/env bash
#
# default/install.sh
#
# Установка стандартного набора пакетов.
#

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

DEPENDENCIES_FILE="$SCRIPT_DIR/dependencies.json"

# ============================================================
# Usage
# ============================================================
usage() {

    cat <<EOF
${C_CYAN}Установка zsh${C_RESET}

${C_CYAN}Использование:${C_RESET}
  $0 [-n] [-v] [-h] [пользователь...]

${C_CYAN}Аргументы:${C_RESET}
  пользователь   учётная запись для перевода на zsh
                  (несколько - через пробел или запятую, без аргументов - все)

${C_CYAN}Примеры:${C_RESET}
  $0                zsh для всех пользователей
  $0 tester         zsh только для tester
  $0 tester,svc     zsh для tester и svc
  $0 -n             установка пакетов в режиме dry-run
EOF
}

# ============================================================
# Main
# ============================================================
main() {

    local -a installer_args=()
    local -a users=()

    # флаги уходят установщику пакетов, остальное - список пользователей
    while (($#)); do
        case "$1" in

            -h|--help)

                usage
                return 0
                ;;

            -*)
                installer_args+=("$1")
                shift
                ;;

            *)

                users+=("$1")
                shift
                ;;

        esac
    done

    log_info "Install shell..."

    if ((${#users[@]})); then
        log_info "Пользователи: ${users[*]}"
    else
        log_info "Пользователи: все"
    fi

    "$PKG_INSTALLER_DIR/dependencies_installer.sh" \
        --file "$DEPENDENCIES_FILE" \
        "${installer_args[@]}"

    "$SCRIPT_DIR/config.sh" ${users[@]+"${users[@]}"}
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
