#!/usr/bin/env bash
#
# default/office/libreoffice/install.sh
#
# Установка LibreOffice и развертывание конфигурации.
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

log_info "Installing LibreOffice..."
yay -S libreoffice-still-ru --needed --noconfirm \
        && [ -d config ] && cd "$SCRIPT_DIR" && stow -R -v -t "$HOME" config