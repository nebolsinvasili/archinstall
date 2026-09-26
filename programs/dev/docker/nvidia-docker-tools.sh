#!/usr/bin/env bash
#
# nvidia-docker-tools.sh
#
# Установка и настройка NVIDIA Container Toolkit для Docker.
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

main() {
    log_info "Обновление пакетов и установка утилит..."
    yay -Syu
    yay -S curl gnupg2

    log_info "Добавление репозитория NVIDIA Container Toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    log_info "Установка nvidia-container-toolkit..."
    yay -S nvidia-container-toolkit
    yay -Syu

    log_info "Настройка NVIDIA Container Toolkit..."
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker

    log_ok "Проверка поддержки GPU в Docker..."
    docker run --gpus all nvidia/cuda:11.5.2-base-ubuntu20.04 nvidia-smi
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"