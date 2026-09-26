#!/usr/bin/env bash
#
# cli.sh
#
# Разбор аргументов командной строки.
#

################################################################################
# print_usage
################################################################################

##
# Краткая справка.
#
print_usage() {

cat <<EOF
Usage:
    dependencies_installer.sh [OPTIONS]

Options:

    -f, --file FILE
        JSON-файл с описанием зависимостей.

    -n, --dry-run
        Не выполнять установку.
        Показывает, какие действия будут выполнены.

    -v, --verbose
        Подробный вывод.

    -h, --help
        Показать справку.
EOF

}

################################################################################
# show_help
################################################################################

##
# Полная справка.
#
show_help() {

cat <<EOF
Dependencies Installer

Расширяемый модуль установки зависимостей из JSON.

Поддерживаемые возможности

  • произвольная вложенность JSON
  • наследование manager
  • наследование enabled
  • несколько пакетных менеджеров
  • режим auto
  • DRY RUN
  • параллельная установка
  • запись отсутствующих пакетов

Пример

    dependencies_installer.sh \\
        --file dependencies.json

Проверка

    dependencies_installer.sh \\
        --file dependencies.json \\
        --dry-run

Подробный вывод

    dependencies_installer.sh \\
        --file dependencies.json \\
        --verbose

EOF

}

##
# Разбор аргументов командной строки.
#
# Parameters:
#   $1 - имя массива для сохранения списка программ
#   $2... - аргументы командной строки
#
# Return:
#   0 - успешно
#   1 - ошибка
#
parse_args()
{
    local output_array="$1"
    shift

    declare -n packages_ref="$output_array"

    DEPENDENCIES_FILE=""
    DRY_RUN=false
    VERBOSE=false

    packages_ref=()

    while (($#)); do

        case "$1" in

            -f|--file)

                shift

                [[ $# -eq 0 ]] && {
                    log_error "--file requires an argument."
                    return 1
                }

                DEPENDENCIES_FILE="$1"
                shift
                ;;

            -p|--prog)

                shift

                [[ $# -eq 0 ]] && {
                    log_error "--prog requires at least one package."
                    return 1
                }

                while (($#)); do

                    [[ "$1" == -* ]] && break

                    packages_ref+=("$1")

                    shift

                done
                ;;

            -n|--dry-run)

                DRY_RUN=true
                shift
                ;;

            -v|--verbose)

                VERBOSE=true
                shift
                ;;

            -h|--help)

                show_help
                exit 0
                ;;

            --)

                shift
                break
                ;;

            -*)

                log_error "Unknown option: $1"
                return 1
                ;;

            *)

                log_error "Unexpected argument: $1"
                return 1
                ;;

        esac

    done


    #
    # Проверка режима работы
    #

    if [[ -n "$DEPENDENCIES_FILE" && ${#packages_ref[@]} -gt 0 ]]; then
        log_error "--file and --prog cannot be used together."
        return 1
    fi

    if [[ -z "$DEPENDENCIES_FILE" && ${#packages_ref[@]} -eq 0 ]]; then
        log_error "Specify either --file or --prog."
        return 1
    fi

    if [[ -n "$DEPENDENCIES_FILE" && ! -f "$DEPENDENCIES_FILE" ]]; then
        log_error "File not found: $DEPENDENCIES_FILE"
        return 1
    fi

    return 0
}