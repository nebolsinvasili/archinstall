#!/usr/bin/env bash
# ============================================================================
# detection.sh - Обнаружение других операционных систем
# ============================================================================

# ============================================================================
# Включение os-prober
# ============================================================================

enable_os_prober() {
    # Включает os-prober в конфигурации GRUB
    if [[ ! -f "$GRUB_DEFAULT" ]]; then
        log_error "Файл $GRUB_DEFAULT не найден"
        return 1
    fi
    
    log_info "Включение os-prober..."
    
    # Отключаем параметры, отключающие os-prober
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_DEFAULT" 2>/dev/null || true
    sed -i 's/^GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_DEFAULT" 2>/dev/null || true
    
    # Добавляем параметр, если отсутствует
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=" "$GRUB_DEFAULT"; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> "$GRUB_DEFAULT"
        log_info "Добавлен параметр GRUB_DISABLE_OS_PROBER=false"
    fi
    
    log_ok "os-prober включен"
    return 0
}

# ============================================================================
# Поиск ОС
# ============================================================================

detect_os() {
    # Поиск установленных ОС
    log_info "Поиск операционных систем..."
    
    # Включаем os-prober
    enable_os_prober || return 1
    
    # Запускаем os-prober
    local os_list=$(os-prober 2>/dev/null)
    
    if [[ -z "$os_list" ]]; then
        log_warn "Другие ОС не найдены"
        return 1
    fi
    
    # Выводим результаты
    echo ""
    echo -e "${CLR_TITLE}Найденные ОС:${C_RESET}"
    echo "----------------------------------------"
    
    local count=0
    echo "$os_list" | while IFS=: read -r device os_name rest; do
        count=$((count + 1))
        local os_type="Linux"
        [[ "$os_name" =~ "Windows" ]] && os_type="Windows"
        [[ "$os_name" =~ "macOS" ]] && os_type="macOS"
        
        echo -e "${CLR_INFO}[$count]${C_RESET} $os_name"
        echo -e "    Устройство: $device"
        echo -e "    Тип: $os_type"
        echo "----------------------------------------"
    done
    
    export DETECTED_OS_LIST="$os_list"
    log_ok "Найдено $count ОС"
    return 0
}

# ============================================================================
# Вспомогательные функции
# ============================================================================

has_other_os() {
    # Проверяет наличие других ОС
    local os_list=$(os-prober 2>/dev/null)
    [[ -n "$os_list" ]]
    return $?
}

get_os_name_by_index() {
    # Возвращает имя ОС по индексу
    local index="$1"
    
    if [[ -z "$index" ]] || [[ "$index" -lt 1 ]]; then
        log_error "Неверный индекс"
        return 1
    fi
    
    local os_entry=$(os-prober 2>/dev/null | sed -n "${index}p")
    
    if [[ -z "$os_entry" ]]; then
        log_error "ОС с индексом $index не найдена"
        return 1
    fi
    
    echo "$os_entry" | cut -d: -f2
    return 0
}