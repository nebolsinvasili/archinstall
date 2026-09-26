#!/usr/bin/env bash
#
# init.sh
#
# Единая точка подключения окружения проекта.
#
# Каждый установщик сам находит корень репозитория (маркер "pkg-installer")
# и подключает этот файл. Модуль идемпотентен: повторное подключение
# безопасно.
#
# Порядок подключения модулей важен:
#
#   core.sh         — корень, каталоги, mkdir
#   env.sh          — PATH и локаль
#   colors.sh       — ANSI-цвета
#   icons.sh        — иконки для лога
#   logging.sh      — логирование (log_*)
#   utils.sh        — общие утилиты
#   path_helpers.sh — project_path / config_path / lib_path
#

[[ -n "${__INIT_SH:-}" ]] && return
readonly __INIT_SH=1

set -euo pipefail

# ---------------------------------------------------------------------
# Расположение модуля (источник истины для LIB_DIR и ROOT_DIR)
# ---------------------------------------------------------------------

INIT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LIB_DIR="$INIT_DIR"
export ROOT_DIR="$(dirname "$LIB_DIR")"

# ---------------------------------------------------------------------
# Подключение модулей
# ---------------------------------------------------------------------

source "$LIB_DIR/core.sh"
source "$LIB_DIR/env.sh"
source "$LIB_DIR/colors.sh"
source "$LIB_DIR/icons.sh"
source "$LIB_DIR/logging.sh" && log_init
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/path_helpers.sh"