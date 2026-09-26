#!/usr/bin/env bash
#
# programs/office/obsidian/config.sh
#
# Настройка Obsidian: установка и включение плагинов в хранилище.
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

VAULT_DIR="${VAULT_DIR:-$HOME/Workspace}"
OBSIDIAN_DIR="$VAULT_DIR/.obsidian"
PLUGIN_NAME="terminal"
PLUGIN_REPO="polyipseity/obsidian-terminal"
PLUGIN_DIR="$OBSIDIAN_DIR/plugins/$PLUGIN_NAME"
COMMUNITY_PLUGINS_FILE="$OBSIDIAN_DIR/community-plugins.json"

# ============================================================
# install_terminal_plugin
# ============================================================
install_terminal_plugin() {
    if [[ ! -d "$OBSIDIAN_DIR" ]]; then
        log_warn "Каталог $OBSIDIAN_DIR не найден — установка плагинов пропущена."
        return 0
    fi

    if [[ -f "$PLUGIN_DIR/main.js" ]]; then
        log_info "Плагин $PLUGIN_NAME уже установлен: $PLUGIN_DIR"
        return 0
    fi

    mkdir -p "$PLUGIN_DIR"

    log_info "Определение последнего релиза $PLUGIN_REPO..."
    local tag
    tag="$(curl -fsSL "https://api.github.com/repos/$PLUGIN_REPO/releases/latest" | jq -r '.tag_name')"
    local base_url="https://github.com/$PLUGIN_REPO/releases/download/$tag"

    log_info "Установка плагина $PLUGIN_NAME ($tag)..."
    local asset
    for asset in manifest.json main.js styles.css; do
        curl -fsSL "$base_url/$asset" -o "$PLUGIN_DIR/$asset"
    done

    log_ok "Плагин $PLUGIN_NAME установлен: $PLUGIN_DIR"
}

# ============================================================
# enable_plugin
# ============================================================
enable_plugin() {
    if [[ -f "$COMMUNITY_PLUGINS_FILE" ]] \
        && jq -e 'index("terminal")' "$COMMUNITY_PLUGINS_FILE" >/dev/null 2>&1; then
        log_info "Плагин $PLUGIN_NAME уже включён в community-plugins.json"
        return 0
    fi

    if [[ -f "$COMMUNITY_PLUGINS_FILE" ]]; then
        jq '. + ["terminal"] | unique' "$COMMUNITY_PLUGINS_FILE" > "$COMMUNITY_PLUGINS_FILE.tmp"
        mv "$COMMUNITY_PLUGINS_FILE.tmp" "$COMMUNITY_PLUGINS_FILE"
    else
        printf '["terminal"]\n' > "$COMMUNITY_PLUGINS_FILE"
    fi

    log_ok "Плагин $PLUGIN_NAME добавлен в community-plugins.json"
}

# ============================================================
# configure_terminal_plugin
# ============================================================
configure_terminal_plugin() {
    if [[ ! -f "$PLUGIN_DIR/main.js" ]]; then
        log_warn "Плагин $PLUGIN_NAME не установлен — настройка пропущена."
        return 0
    fi

    local data_file="$PLUGIN_DIR/data.json"
    local vault_abs

    vault_abs="$(cd -- "$VAULT_DIR" && pwd)"
    [[ -f "$data_file" ]] || printf '{}\n' > "$data_file"

    jq --arg vault "$vault_abs" '
        .newInstanceBehavior = "newRightSplit"
        | .pinNewInstance = true
        | .defaultProfile = "openCode"
        | .profiles.openCode = (.profiles.openCode // {
            "type": "integrated",
            "name": "opencode",
            "executable": "/bin/bash",
            "args": ["--login", "-c", ("cd \"" + $vault + "\" && exec opencode")],
            "environment": [],
            "platforms": {"darwin": false, "linux": true, "win32": false},
            "pythonExecutable": "python3",
            "useWin32Conhost": true,
            "followTheme": true,
            "restoreHistory": false,
            "rightClickAction": "copyPaste",
            "successExitCodes": ["0", "SIGINT", "SIGTERM"],
            "terminalOptions": {"documentOverride": null}
        })
    ' "$data_file" > "$data_file.tmp"
    mv "$data_file.tmp" "$data_file"

    log_ok "Плагин $PLUGIN_NAME настроен: закреплённая правая сторона, профиль opencode ($vault_abs)"
}

# ============================================================
# Main
# ============================================================
main() {
    log_info "Конфигурация Obsidian: плагины..."

    install_terminal_plugin
    enable_plugin
    configure_terminal_plugin

    log_ok "Конфигурация Obsidian завершена."
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"