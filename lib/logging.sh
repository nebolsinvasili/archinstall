#!/usr/bin/env bash
# ============================================================
#
# logging.sh
#
# Универсальный модуль логирования
#
# Требует:
#   colors.sh
#
# ============================================================

[[ -n "${__LOGGING_SH:-}" ]] && return
readonly __LOGGING_SH=1

source "$LIB_DIR/colors.sh"
source "$LIB_DIR/icons.sh"

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

LOG_INITIALIZED="${LOG_INITIALIZED:-0}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/log}"
LOG_FILE="${LOG_FILE:-}"
LOG_KEEP=5

LOG_TO_FILE=1
LOG_TO_CONSOLE=1

VERBOSE="${VERBOSE:-0}"

# ------------------------------------------------------------
# Levels
# ------------------------------------------------------------

declare -Ar LOG_COLORS=(
    [DEBUG]="$CLR_DEBUG"
    [INFO]="$CLR_INFO"
    [OK]="$CLR_OK"
    [WARN]="$CLR_WARN"
    [ERROR]="$CLR_ERROR"
)

declare -Ar LOG_ICONS=(
    [DEBUG]="$ICON_DEBUG"
    [INFO]="$ICON_INFO"
    [OK]="$ICON_OK"
    [WARN]="$ICON_WARN"
    [ERROR]="$ICON_ERROR"
)

# ------------------------------------------------------------
# Init
# ------------------------------------------------------------
log_init()
{
    if [[ "${LOG_INITIALIZED:-0}" -eq 1 &&
          -n "${LOG_FILE:-}" &&
          -f "$LOG_FILE" ]]; then
        return 0
    fi


    local program
    local timestamp
    local script_name
    local dir_name


    script_name="$(basename "${0%.*}")"
    dir_name="$(basename "${SCRIPT_DIR:-$ROOT_DIR}")"

    program="${dir_name}_${script_name}"

    timestamp="$(date +"%Y%m%d_%H%M%S")"


    # каталог логов конкретного модуля
    local module_log_dir

    module_log_dir="$LOG_DIR"


    # создаём полностью
    mkdir -p "$module_log_dir"


    LOG_FILE="$module_log_dir/${program}_${timestamp}.log"


    touch "$LOG_FILE" || {
        echo "Cannot create log: $LOG_FILE" >&2
        return 1
    }


    export LOG_FILE
    export LOG_INITIALIZED=1
}

_log()
{
    local level="$1"
    shift

    local message="$*"

    local icon
    local color


    case "$level" in

        INFO)
            icon="$ICON_INFO"
            color="$CLR_INFO"
            ;;

        OK)
            icon="$ICON_OK"
            color="$CLR_OK"
            ;;

        WARN)
            icon="$ICON_WARN"
            color="$CLR_WARN"
            ;;

        ERROR)
            icon="$ICON_ERROR"
            color="$CLR_ERROR"
            ;;

        DEBUG)
            icon="$ICON_DEBUG"
            color="$CLR_DEBUG"
            ;;

        *)
            icon="[?]"
            color=""
            ;;

    esac


    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"


    # Консоль с цветом
    printf "%b%s%b %s\n" \
        "$color" \
        "$icon" \
        "$C_RESET" \
        "$message"


    # Файл без ANSI цветов
    if [[ -n "${LOG_FILE:-}" ]]; then

        printf "[%s] [%s] %s\n" \
            "$timestamp" \
            "$level" \
            "$message" \
            >> "$LOG_FILE"

    fi
}

# ------------------------------------------------------------
# API
# ------------------------------------------------------------

for level in DEBUG INFO OK WARN ERROR
do

eval "
log_${level,,}()
{
    _log $level \"\$@\"
}
"

done

# ------------------------------------------------------------
# Title
# ------------------------------------------------------------

log_title() {

    local title="$*"

    printf "\n%b" "$CLR_TITLE"
    printf '============================================================\n'
    printf '%s\n' "$title"
    printf '============================================================%b\n' \
        "$C_RESET"


    if [[ -n "${LOG_FILE:-}" ]]; then

        {
            echo
            echo "============================================================"
            echo "$title"
            echo "============================================================"
        } >> "$LOG_FILE"

    fi
}

# ------------------------------------------------------------
# Separator
# ------------------------------------------------------------

log_separator() {

    printf "%b------------------------------------------------------------%b\n" \
        "$CLR_TITLE" \
        "$C_RESET"

    [[ -n "$LOG_FILE" ]] &&
        printf '%s\n' \
        "------------------------------------------------------------" \
        >>"$LOG_FILE"
}

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

log_enable_console()  { LOG_TO_CONSOLE=1; }
log_disable_console() { LOG_TO_CONSOLE=0; }

log_enable_file()     { LOG_TO_FILE=1; }
log_disable_file()    { LOG_TO_FILE=0; }

log_verbose()         { VERBOSE=1; }
log_quiet()           { VERBOSE=0; }
