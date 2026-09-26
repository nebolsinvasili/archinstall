#!/usr/bin/env bash
# ============================================================================
# config.sh - Настройка параметров GRUB
# ============================================================================

# ============================================================================
# Установка ОС по умолчанию
# ============================================================================

set_default_os() {
    # Устанавливает ОС по умолчанию
    local default_entry="$1"
    
    if [[ -z "$default_entry" ]]; then
        log_error "Не указана ОС по умолчанию"
        return 1
    fi
    
    if [[ ! -f "$GRUB_DEFAULT" ]]; then
        log_error "Файл $GRUB_DEFAULT не найден"
        return 1
    fi
    
    log_info "Установка ОС по умолчанию: $default_entry"
    
    if grep -q "^GRUB_DEFAULT=" "$GRUB_DEFAULT"; then
        sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"$default_entry\"/" "$GRUB_DEFAULT"
    else
        echo "GRUB_DEFAULT=\"$default_entry\"" >> "$GRUB_DEFAULT"
    fi
    
    log_ok "ОС по умолчанию: $default_entry"
    return 0
}

# ============================================================================
# Установка таймаута
# ============================================================================

set_timeout() {
    # Устанавливает таймаут загрузки
    local timeout="$1"
    
    if [[ -z "$timeout" ]] || ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        log_error "Некорректный таймаут: $timeout"
        return 1
    fi
    
    if [[ "$timeout" -lt 0 ]] || [[ "$timeout" -gt 300 ]]; then
        log_error "Таймаут должен быть 0-300 секунд"
        return 1
    fi
    
    if [[ ! -f "$GRUB_DEFAULT" ]]; then
        log_error "Файл $GRUB_DEFAULT не найден"
        return 1
    fi
    
    log_info "Установка таймаута: $timeout секунд"
    
    if grep -q "^GRUB_TIMEOUT=" "$GRUB_DEFAULT"; then
        sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$timeout/" "$GRUB_DEFAULT"
    else
        echo "GRUB_TIMEOUT=$timeout" >> "$GRUB_DEFAULT"
    fi
    
    log_ok "Таймаут установлен: $timeout секунд"
    return 0
}

# ============================================================================
# Просмотр текущих настроек
# ============================================================================

get_current_settings() {
    # Показывает текущие настройки
    echo ""
    echo -e "${CLR_TITLE}ТЕКУЩИЕ НАСТРОЙКИ GRUB${C_RESET}"
    echo "========================================"
    
    if [[ -f "$GRUB_DEFAULT" ]]; then
        echo -e "${CLR_INFO}Параметры /etc/default/grub:${C_RESET}"
        grep -v "^#" "$GRUB_DEFAULT" | grep -v "^$" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  Файл $GRUB_DEFAULT не найден"
    fi
    
    echo ""
    echo -e "${CLR_INFO}Доступные ОС:${C_RESET}"
    if [[ -f "$GRUB_CFG" ]]; then
        grep -E "menuentry|submenu" "$GRUB_CFG" | head -20 | while read -r line; do
            echo "  $line"
        done
    else
        echo "  Файл $GRUB_CFG не найден"
    fi
    
    echo ""
    echo -e "${CLR_INFO}Найденные ОС (os-prober):${C_RESET}"
    if has_other_os; then
        os-prober 2>/dev/null | while IFS=: read -r device os_name rest; do
            echo "  $os_name ($device)"
        done
    else
        echo "  Другие ОС не найдены"
    fi
}