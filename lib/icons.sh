#!/usr/bin/env bash
#
# icons.sh
#
# Иконки для вывода в консоль и файлы лога.
#

[[ -n "${__ICONS_SH:-}" ]] && return
readonly __ICONS_SH=1
ICON_INFO="[i]"
ICON_OK="[+]"
ICON_WARN="[!]"
ICON_ERROR="[x]"
ICON_DEBUG="[*]"

# if [[ "${TERM:-}" == "dumb" ]]; then

#     ICON_INFO="[i]"
#     ICON_OK="[+]"
#     ICON_WARN="[!]"
#     ICON_ERROR="[x]"
#     ICON_DEBUG="[*]"

# else

#     ICON_INFO="ℹ"
#     ICON_OK="✔"
#     ICON_WARN="⚠"
#     ICON_ERROR="✖"
#     ICON_DEBUG="*"

# fi

# ============================================================
# File icons
# ============================================================
ICON_FILE_INFO="[INFO]"
ICON_FILE_OK="[OK]"
ICON_FILE_WARN="[WARN]"
ICON_FILE_ERROR="[ERROR]"
ICON_FILE_DEBUG="[DEBUG]"