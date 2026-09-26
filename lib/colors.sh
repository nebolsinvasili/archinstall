#!/usr/bin/env bash
# ============================================================
#
# colors.sh
#
# ANSI colors
#
# ============================================================

[[ -n "${__COLORS_SH:-}" ]] && return
readonly __COLORS_SH=1


if command -v tput >/dev/null 2>&1 && [[ "$(tput colors)" -ge 8 ]]; then

    C_BLACK="$(tput setaf 0)"
    C_RED="$(tput setaf 1)"
    C_GREEN="$(tput setaf 2)"
    C_YELLOW="$(tput setaf 3)"
    C_BLUE="$(tput setaf 4)"
    C_MAGENTA="$(tput setaf 5)"
    C_CYAN="$(tput setaf 6)"
    C_WHITE="$(tput setaf 7)"

    C_BOLD="$(tput bold)"
    C_RESET="$(tput sgr0)"

else

    C_BLACK=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_MAGENTA=""
    C_CYAN=""
    C_WHITE=""

    C_BOLD=""
    C_RESET=""

fi


# ------------------------------------------------------------
# Logger colors
# ------------------------------------------------------------

CLR_DEBUG="${C_BLUE}"
CLR_INFO="${C_CYAN}"
CLR_OK="${C_BOLD}${C_GREEN}"
CLR_WARN="${C_BOLD}${C_YELLOW}"
CLR_ERROR="${C_BOLD}${C_RED}"
CLR_TITLE="${C_BOLD}${C_MAGENTA}"

export \
    CLR_DEBUG \
    CLR_INFO \
    CLR_OK \
    CLR_WARN \
    CLR_ERROR \
    CLR_TITLE \
    C_RESET