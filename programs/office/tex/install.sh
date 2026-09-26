#!/usr/bin/env bash
#
# default/office/tex/install.sh
#
# Установка TeX Live и TeXstudio.
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

log_info "Установка пакетов без подтверждения..."
yay -S --needed --noconfirm \
    texlive-binextra \
    texlive-latexextra \
    texlive-formatsextra \
    texlive-bibtexextra \
    texlive-fontsextra \
    texlive-lang \
    biber \
    texstudio

sudo pacman -S --needed --noconfirm texlive-xetex

log_info "Развертывание конфигурации..."
cd "$SCRIPT_DIR" && [ -d config ] && stow -R -v -t "$HOME" config

log_info "Запуск тестов..."
cd "$SCRIPT_DIR" && [ -d test ] && (cd test && make all)
