#!/usr/bin/env bash
# ============================================================================
# backup.sh - Бэкап и восстановление конфигурации GRUB
# ============================================================================

# ============================================================================
# Создание бэкапа
# ============================================================================

backup_grub() {
    """
    Создает бэкап текущей конфигурации GRUB
    """
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/grub_backup_$timestamp"
    
    log_info "Создание бэкапа..."
    
    mkdir -p "$BACKUP_DIR" || {
        log_error "Не удалось создать $BACKUP_DIR"
        return 1
    }
    
    if [[ -f "$GRUB_CFG" ]]; then
        cp "$GRUB_CFG" "$backup_path.cfg" || {
            log_error "Не удалось скопировать $GRUB_CFG"
            return 1
        }
        log_ok "Бэкап создан: $backup_path.cfg"
    else
        log_warn "Файл $GRUB_CFG не найден"
    fi
    
    if [[ -f "$GRUB_DEFAULT" ]]; then
        cp "$GRUB_DEFAULT" "$backup_path.default" || {
            log_error "Не удалось скопировать $GRUB_DEFAULT"
            return 1
        }
        log_ok "Бэкап создан: $backup_path.default"
    else
        log_warn "Файл $GRUB_DEFAULT не найден"
    fi
    
    log_ok "Бэкап завершен: $backup_path"
    return 0
}

# ============================================================================
# Восстановление из бэкапа
# ============================================================================

restore_grub() {
    """
    Восстанавливает конфигурацию из бэкапа
    """
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
        log_error "Файл бэкапа не найден: $backup_file"
        return 1
    fi
    
    log_info "Восстановление из бэкапа: $backup_file"
    
    cp "$backup_file" "$GRUB_CFG" || {
        log_error "Не удалось восстановить $GRUB_CFG"
        return 1
    }
    
    local default_backup="${backup_file%.cfg}.default"
    if [[ -f "$default_backup" ]]; then
        cp "$default_backup" "$GRUB_DEFAULT" || {
            log_warn "Не удалось восстановить $GRUB_DEFAULT"
        }
    fi
    
    log_ok "Восстановление завершено"
    return 0
}

# ============================================================================
# Очистка старых бэкапов
# ============================================================================

clean_old_backups() {
    """
    Удаляет старые бэкапы, оставляя только последние N
    Возвращает количество удаленных файлов
    """
    local keep_count="${1:-5}"
    local deleted_count=0
    
    log_info "Очистка старых бэкапов (оставляю $keep_count)"
    
    local backups=($(ls -t "$BACKUP_DIR"/*.cfg 2>/dev/null))
    local total=${#backups[@]}
    
    if [[ $total -le $keep_count ]]; then
        log_info "Всего $total бэкапов, очистка не требуется"
        echo "0"
        return 0
    fi
    
    local to_delete=$((total - keep_count))
    for ((i=keep_count; i<total; i++)); do
        local file="${backups[$i]}"
        local default_file="${file%.cfg}.default"
        
        log_info "Удаляю старый бэкап: $(basename "$file")"
        rm -f "$file"
        deleted_count=$((deleted_count + 1))
        
        if [[ -f "$default_file" ]]; then
            rm -f "$default_file"
        fi
    done
    
    log_ok "Удалено $deleted_count старых бэкапов"
    echo "$deleted_count"
    return 0
}
