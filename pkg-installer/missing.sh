#!/usr/bin/env bash

[[ -n "${__MISSING_SH:-}" ]] && return
readonly __MISSING_SH=1

MISSING_DIR="${MISSING_DIR:-${SCRIPT_DIR:-$(pwd)}}"
MISSING_FILE="${MISSING_FILE:-}"
MISSING_KEEP="${MISSING_KEEP:-2}"
MISSING_INITIALIZED=0

_missing_init() {

    (( MISSING_INITIALIZED )) && return 0

    mkdir -p "$MISSING_DIR"

    local ts
    ts="$(date +"%Y%m%d_%H%M%S")"

    MISSING_FILE="$MISSING_DIR/missingApps_${ts}.log"

    : > "$MISSING_FILE"

    local -a files

    mapfile -t files < <(
        ls -1t "$MISSING_DIR"/missingApps_*.log 2>/dev/null || true
    )

    local i

    for ((i=MISSING_KEEP; i<${#files[@]}; ++i)); do
        rm -f "${files[i]}"
    done

    export MISSING_FILE
    export MISSING_INITIALIZED=1
}

missing_write() {

    _missing_init

    printf "%s\n" "$1" >> "$MISSING_FILE"
}

missing_exists() {
    [[ -n "${MISSING_FILE:-}" && -s "$MISSING_FILE" ]]
}