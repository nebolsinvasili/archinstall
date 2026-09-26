#!/usr/bin/env bash
#
# default/docker/config.sh
#
# Настройка Docker: группы, запуск службы и конфигурация.
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

# ============================================================
# Main
# ============================================================
main() {
    log_info "Configuring Docker..."

    # Создание группы docker, если её нет
    if ! getent group docker >/dev/null; then
        log_info "Creating docker group..."
        sudo groupadd docker
    fi

    # Добавление текущего пользователя в группу docker
    if ! groups "$USER" | grep -q "\bdocker\b"; then
        log_info "Adding user $USER to docker group..."
        sudo usermod -aG docker "$USER"
        log_warn "You precise to re-login or run 'newgrp docker' to apply group changes."
    fi

    # Включение и запуск службы Docker через systemd
    log_info "Enabling and starting Docker service..."
    sudo systemctl enable --now docker.service

    log_info "Docker configuration completed successfully!"
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
