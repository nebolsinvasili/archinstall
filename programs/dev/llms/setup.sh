#!/usr/bin/env bash
#
# default/llms/install.sh
#
# Установка Ollama и opencode — локальные LLM и AI-ассистент в терминале.
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
# Main
# ============================================================
main() {
    log_info "Installing Ollama and opencode..."

    "$PKG_INSTALLER_DIR/dependencies_installer.sh" \
        --file "$DEPENDENCIES_FILE" \
        "$@" \
        && ./config.sh \
        && [ -d config ] && stow -R -v -t ~/.config config
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"