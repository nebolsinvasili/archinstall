#!/usr/bin/env bash
#
# default/langs/python/install.sh
#
# Установка Pyenv, Poetry и настроек Python-окружения.
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

log_info "Installing Pyenv and Poetry..."
yay -S pyenv poetry tk --needed --noconfirm

log_info "Configuring Poetry (virtualenvs.in-project)..."
poetry config virtualenvs.in-project true

cat << 'EOF' >> ~/.zshrc
# ------ PYENV ------
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
EOF

log_ok "Python environment configured."