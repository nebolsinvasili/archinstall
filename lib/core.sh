#!/usr/bin/env bash
#
# core.sh
#
# Определение корня проекта и основных каталогов.
#
# Требует:
#   ROOT_DIR и LIB_DIR из lib/init.sh
#

[[ -n "${__CORE_SH:-}" ]] && return
readonly __CORE_SH=1

# ---------------------------------------------------------------------
# Каталоги
# ---------------------------------------------------------------------

export PKG_INSTALLER_DIR="$ROOT_DIR/pkg-installer"
export CONFIGS_DIR="$ROOT_DIR/configs"
export CACHE_DIR="$ROOT_DIR/cache"
export TMP_DIR="$ROOT_DIR/tmp"
export LOG_DIR="${LOG_DIR:-$ROOT_DIR/log}"

mkdir -p \
    "$CACHE_DIR" \
    "$LOG_DIR" \
    "$TMP_DIR"