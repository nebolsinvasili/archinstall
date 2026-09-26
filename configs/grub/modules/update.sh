#!/usr/bin/env bash
# ============================================================================
# update.sh - Обновление конфигурации GRUB
# ============================================================================

# ============================================================================
# Обновление GRUB
# ============================================================================

update_grub() {
    # Обновляет конфигурацию GRUB
    log_info "Обновление GRUB..."
    
    if ! command -v grub-mkconfig &> /dev/null; then
        log_error "grub-mkconfig не найден"
        return 1
    fi
    
    if [[ ! -w "$(dirname "$GRUB_CFG")" ]]; then
        log_error "Нет прав на запись в $(dirname "$GRUB_CFG")"
        return 1
    fi
    
    log_info "Запуск: grub-mkconfig -o $GRUB_CFG"
    
    if grub-mkconfig -o "$GRUB_CFG" 2>&1; then
        log_ok "GRUB обновлен успешно"
        return 0
    else
        log_error "Ошибка при обновлении GRUB"
        return 1
    fi
}

# ============================================================================
# Проверка конфигурации
# ============================================================================

validate_grub_config() {
    # Проверяет валидность конфигурации GRUB
    if [[ ! -f "$GRUB_CFG" ]]; then
        log_error "Файл $GRUB_CFG не найден"
        return 1
    fi
    
    log_info "Проверка конфигурации..."
    
    if ! grep -q "menuentry" "$GRUB_CFG"; then
        log_warn "В конфигурации нет записей загрузки"
        return 1
    fi
    
    log_ok "Конфигурация валидна"
    return 0
}