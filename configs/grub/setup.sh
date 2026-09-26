#!/usr/bin/env bash
# ============================================================================
# grub-customizer.sh (setup.sh) - Интерактивный инструмент для настройки GRUB
# ============================================================================

set -euo pipefail

# ============================================================================
# Инициализация
# ============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# Определяем реального пользователя
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(eval echo ~$REAL_USER)"

# ============================================================================
# Проверка прав
# ============================================================================

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Этот скрипт должен запускаться с правами root"
    echo "Используйте: sudo $0"
    exit 1
fi

# ============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ
# ============================================================================

install_dependencies() {
    echo "[i] Проверка зависимостей..."
    
    local need_install=()
    
    # Проверяем dialog
    if ! command -v dialog &> /dev/null; then
        echo "[!] dialog не установлен"
        need_install+=("dialog")
    fi
    
    # Проверяем os-prober
    if ! command -v os-prober &> /dev/null; then
        echo "[!] os-prober не установлен"
        need_install+=("os-prober")
    fi
    
    # Проверяем grub-mkconfig
    if ! command -v grub-mkconfig &> /dev/null; then
        echo "[!] grub-mkconfig не найден (установите grub)"
        need_install+=("grub")
    fi
    
    # Если ничего не нужно - выходим
    if [[ ${#need_install[@]} -eq 0 ]]; then
        echo "[+] Все зависимости уже установлены"
        return 0
    fi
    
    echo "[i] Установка пакетов: ${need_install[*]}"
    
    if pacman -S --noconfirm "${need_install[@]}"; then
        echo "[+] Пакеты успешно установлены"
        return 0
    else
        echo "[x] Ошибка при установке пакетов"
        return 1
    fi
}

# ============================================================================
# Загрузка окружения (init.sh)
# ============================================================================

load_bootstrap() {
    local candidate="$SCRIPT_DIR"

    # Поиск корня репозитория по маркеру "pkg-installer"
    while [[ ! -d "$candidate/pkg-installer" && "$candidate" != "/" ]]; do
        candidate="$(dirname "$candidate")"
    done

    if [[ -f "$candidate/lib/init.sh" ]]; then
        echo "[+] Загрузка окружения из: $candidate/lib/init.sh"
        # shellcheck source=/dev/null
        source "$candidate/lib/init.sh"
        return 0
    fi

    echo "[!] init.sh не найден, создаю минимальный..."
    
    # Минимальные функции
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[0;34m'
    C_CYAN='\033[0;36m'
    
    log_info() { echo -e "${C_BLUE}[i]${C_RESET} $*"; }
    log_ok() { echo -e "${C_GREEN}[+]${C_RESET} $*"; }
    log_warn() { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
    log_error() { echo -e "${C_RED}[x]${C_RESET} $*"; }
    log_debug() { echo -e "${C_CYAN}[*]${C_RESET} $*"; }
    
    return 0
}

# ============================================================================
# Загрузка модулей
# ============================================================================

load_modules() {
    log_info "Загрузка модулей..."
    
    local modules=(
        "core.sh"
        "backup.sh"
        "detection.sh"
        "config.sh"
        "update.sh"
        "utils.sh"
        "menu.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="$MODULES_DIR/$module"
        if [[ -f "$module_path" ]]; then
            # shellcheck source=/dev/null
            source "$module_path"
            log_ok "Загружен модуль: $module"
        else
            log_error "Модуль не найден: $module_path"
            return 1
        fi
    done
    
    log_ok "Все модули загружены"
    return 0
}

# ============================================================================
# Основная функция
# ============================================================================

main() {
    echo "[i] Запуск GRUB Customizer..."
    echo "[i] Пользователь: $REAL_USER"
    
    # 1. Устанавливаем зависимости
    if ! install_dependencies; then
        echo "[x] Не удалось установить зависимости"
        exit 1
    fi
    
    # 2. Загружаем bootstrap
    load_bootstrap
    
    # 3. Загружаем модули
    if ! load_modules; then
        log_error "Не удалось загрузить модули"
        exit 1
    fi
    
    # 4. Инициализация окружения
    log_info "Инициализация окружения..."
    init_environment || exit 1
    
    # 5. Проверка dialog перед запуском
    if ! command -v dialog &> /dev/null; then
        log_error "dialog не установлен!"
        exit 1
    fi
    
    log_info "Запуск меню..."
    
    # 6. Запуск основного цикла
    main_loop
}

# ============================================================================
# Точка входа
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
