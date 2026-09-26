#!/usr/bin/env bash
# ============================================================================
# core.sh - Основные функции и инициализация
# ============================================================================

# ============================================================================
# Конфигурация по умолчанию
# ============================================================================

# Пути к файлам GRUB
GRUB_CFG="${GRUB_CFG:-/boot/grub/grub.cfg}"
GRUB_DEFAULT="${GRUB_DEFAULT:-/etc/default/grub}"
GRUB_DIR="/etc/grub.d"

# Пути к утилитам
OS_PROBER="/usr/bin/os-prober"
GRUB_MKCONFIG="/usr/bin/grub-mkconfig"

# Директории
BACKUP_DIR="${BACKUP_DIR:-/var/backups/grub}"
TEMP_DIR="/tmp/grub-customizer"

# Параметры по умолчанию
DEFAULT_TIMEOUT="${DEFAULT_TIMEOUT:-5}"
DEFAULT_OS="Arch Linux"

# ============================================================================
# Инициализация окружения
# ============================================================================

init_environment() {
    log_info "Инициализация окружения..."
    
    # Создаем необходимые директории
    mkdir -p "$TEMP_DIR" 2>/dev/null || true
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    
    # Проверяем права на запись
    local grub_dir="$(dirname "$GRUB_CFG")"
    if [[ ! -w "$grub_dir" ]]; then
        log_error "Нет прав на запись в $grub_dir"
        return 1
    fi
    
    log_ok "Окружение инициализировано"
    return 0
}

# ============================================================================
# Проверка прав
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами root"
        log_info "Используйте: sudo $0"
        return 1
    fi
    
    log_debug "Проверка прав: OK"
    return 0
}

# ============================================================================
# Проверка зависимостей
# ============================================================================

check_dependencies() {
    local deps=(
        "grub-mkconfig"
        "os-prober"
        "blkid"
        "lsblk"
        "dialog"
    )
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -ne 0 ]]; then
        log_warn "Отсутствуют: ${missing[*]}"
        return 1
    fi
    
    log_debug "Зависимости проверены: OK"
    return 0
}
