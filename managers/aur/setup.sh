#!/usr/bin/env bash
#
# default/install.sh
#
# Установка стандартного набора пакетов.
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
# Install AUR package manager (YAY)
# ============================================================
function install_aur_package_manager() {

  local build_dir="$HOME/yay"

  if [[ -d "$build_dir" ]]; then
    ${SUDO_CMD:-sudo} rm -rf "$build_dir"
  fi

  log_info "Cloning YAY repository"
  git clone https://aur.archlinux.org/yay.git "$build_dir"

  cd "$build_dir"
  log_info "Building and installing YAY"
  makepkg -si --noconfirm
  log_ok "YAY successfully installed"
}

# ============================================================
# Verify AUR package manager availability
# ============================================================
function check_aur_package_manager() {
  log_info "Checking YAY availability"
  if command -v yay >/dev/null 2>&1; then
    log_ok "YAY is installed and ready to use"
    yay --version | head -n 1
  else
    log_error "YAY not found in PATH.${RESET}"
    exit 1
  fi
}

# ============================================================
# Main
# ============================================================
main() {

    log_info "Installing AUR Package Manager..."

    "$PKG_INSTALLER_DIR/dependencies_installer.sh" \
        --file "$DEPENDENCIES_FILE" \
        "$@"\
 	&& install_aur_package_manager\
        && check_aur_package_manager
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
