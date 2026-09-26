#!/usr/bin/env bash
# ============================================================================
# menu.sh - Интерактивный интерфейс на Dialog (ПОЛНАЯ ВЕРСИЯ)
# ============================================================================

# ============================================================================
# Отображение главного меню (Dialog)
# ============================================================================

show_main_menu() {
    local choice
    
    if ! command -v dialog &> /dev/null; then
        echo "ERROR: dialog не найден!"
        return 1
    fi
    
    choice=$(dialog --clear \
        --backtitle 'GRUB Customizer for Arch Linux' \
        --title 'Управление загрузчиком' \
        --menu "Выберите действие:" \
        20 60 10 \
        "1" "Поиск и добавление других ОС" \
        "2" "Настройка ОС по умолчанию" \
        "3" "Настройка таймаута загрузки" \
        "4" "Показать текущие настройки" \
        "5" "Создать бэкап" \
        "6" "Восстановить из бэкапа" \
        "7" "Обновить GRUB" \
        "8" "Очистить старые бэкапы" \
        "9" "Выход" \
        3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "9"
        return 0
    fi
    
    echo "$choice"
}

# ============================================================================
# 1. ПОИСК И ДОБАВЛЕНИЕ ДРУГИХ ОС
# ============================================================================

search_and_add_os() {
    log_info "Поиск других ОС..."
    
    # Создаем бэкап
    backup_grub || return 1
    
    # Поиск ОС
    if detect_os; then
        log_ok "Найдены другие операционные системы"
        
        # Обновляем GRUB
        if update_grub; then
            dialog --title "Успех" \
                --msgbox "GRUB обновлен с добавленными ОС\n\nТеперь вы можете выбрать ОС по умолчанию в меню 2" \
                10 50
            log_ok "GRUB обновлен"
        else
            dialog --title "Ошибка" \
                --msgbox "Ошибка при обновлении GRUB" \
                8 50
            return 1
        fi
    else
        dialog --title "Информация" \
            --msgbox "Другие ОС не найдены" \
            8 50
        return 1
    fi
    
    return 0
}

# ============================================================================
# 2. НАСТРОЙКА ОС ПО УМОЛЧАНИЮ
# ============================================================================

get_grub_os_list() {
    # Получает список всех ОС из grub.cfg
    local os_list=()
    
    if [[ ! -f "$GRUB_CFG" ]]; then
        return 1
    fi
    
    # Извлекаем все menuentry
    local entries=$(grep -E "^menuentry|^submenu" "$GRUB_CFG" | sed 's/^.*"\(.*\)".*$/\1/' 2>/dev/null)
    
    if [[ -z "$entries" ]]; then
        return 1
    fi
    
    echo "$entries"
    return 0
}

get_current_default() {
    # Получает текущую ОС по умолчанию из /etc/default/grub
    if [[ -f "$GRUB_DEFAULT" ]]; then
        local default=$(grep "^GRUB_DEFAULT=" "$GRUB_DEFAULT" | cut -d'"' -f2 2>/dev/null)
        if [[ -n "$default" ]]; then
            echo "$default"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

show_os_selection_menu() {
    # Отображает список ОС для выбора по умолчанию
    local menu_items=()
    local count=0
    local current_default=$(get_current_default)
    
    # Получаем список ОС из GRUB
    local os_list=$(get_grub_os_list)
    
    if [[ -z "$os_list" ]]; then
        dialog --title "Ошибка" \
            --msgbox "Не удалось получить список ОС из GRUB\n\nПопробуйте обновить GRUB" \
            10 50
        return 1
    fi
    
    # Добавляем ОС в меню
    local default_marker=""
    while IFS= read -r os_name; do
        os_name=$(echo "$os_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ "$os_name" == "$current_default" ]] || [[ "$count" == "$current_default" ]]; then
            default_marker=" (ТЕКУЩАЯ)"
        else
            default_marker=""
        fi
        
        menu_items+=("$count" "$os_name$default_marker")
        count=$((count + 1))
    done <<< "$os_list"
    
    if [[ ${#menu_items[@]} -eq 0 ]]; then
        dialog --title "Ошибка" \
            --msgbox "Нет доступных ОС для выбора" \
            8 50
        return 1
    fi
    
    local choice
    choice=$(dialog --clear \
        --title "Выбор ОС по умолчанию" \
        --menu "Текущая ОС по умолчанию: $current_default\n\nВыберите ОС для загрузки по умолчанию:" \
        20 70 10 \
        "${menu_items[@]}" \
        3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$choice" ]]; then
        return 1
    fi
    
    echo "$choice"
    return 0
}

set_default_os_advanced() {
    # Устанавливает ОС по умолчанию с поддержкой индексов и имен
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
    
    if [[ "$default_entry" =~ ^[0-9]+$ ]]; then
        local default_value="$default_entry"
    else
        local default_value="\"$default_entry\""
    fi
    
    if grep -q "^GRUB_DEFAULT=" "$GRUB_DEFAULT"; then
        sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=$default_value/" "$GRUB_DEFAULT"
    else
        echo "GRUB_DEFAULT=$default_value" >> "$GRUB_DEFAULT"
    fi
    
    log_ok "ОС по умолчанию: $default_entry"
    return 0
}

set_default_os_interactive() {
    # Интерактивная настройка ОС по умолчанию
    log_info "Настройка ОС по умолчанию..."
    
    local current_default=$(get_current_default)
    log_info "Текущая ОС по умолчанию: $current_default"
    
    local choice=$(show_os_selection_menu)
    
    if [[ -z "$choice" ]]; then
        log_warn "Выбор отменен"
        return 1
    fi
    
    local os_list=$(get_grub_os_list)
    local selected_os=""
    local count=0
    
    while IFS= read -r os_name; do
        os_name=$(echo "$os_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ "$count" == "$choice" ]]; then
            selected_os="$os_name"
            break
        fi
        count=$((count + 1))
    done <<< "$os_list"
    
    if [[ -z "$selected_os" ]]; then
        log_error "Не удалось найти выбранную ОС"
        dialog --title "Ошибка" \
            --msgbox "Не удалось найти выбранную ОС" \
            8 50
        return 1
    fi
    
    dialog --title "Подтверждение" \
        --yesno "Установить ОС по умолчанию:\n\n$selected_os\n\nТекущая ОС: $current_default" \
        12 60
    
    if [[ $? -ne 0 ]]; then
        log_info "Установка отменена"
        return 0
    fi
    
    if set_default_os_advanced "$selected_os"; then
        log_info "Обновление GRUB..."
        update_grub
        
        dialog --title "Успех" \
            --msgbox "ОС по умолчанию установлена:\n\n$selected_os\n\nGRUB обновлен" \
            10 50
        
        log_ok "ОС по умолчанию установлена: $selected_os"
        return 0
    else
        log_error "Не удалось установить ОС по умолчанию"
        dialog --title "Ошибка" \
            --msgbox "Не удалось установить ОС по умолчанию" \
            8 50
        return 1
    fi
}

# ============================================================================
# 3. НАСТРОЙКА ТАЙМАУТА ЗАГРУЗКИ
# ============================================================================

set_timeout_interactive() {
    # Интерактивная настройка таймаута загрузки
    log_info "Настройка таймаута..."
    
    # Получаем текущий таймаут
    local current_timeout="5"
    if [[ -f "$GRUB_DEFAULT" ]]; then
        local timeout_value=$(grep "^GRUB_TIMEOUT=" "$GRUB_DEFAULT" | cut -d'=' -f2 2>/dev/null)
        if [[ -n "$timeout_value" ]]; then
            current_timeout="$timeout_value"
        fi
    fi
    
    local tempfile=$(mktemp)
    
    dialog \
        --title "Настройка таймаута" \
        --inputbox "Введите таймаут загрузки в секундах (0-300):\n\nТекущий таймаут: $current_timeout секунд" \
        12 60 "$current_timeout" \
        2>&1 >"$tempfile"
    
    local exit_code=$?
    local timeout=$(cat "$tempfile")
    rm -f "$tempfile"
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$timeout" ]]; then
        log_warn "Настройка отменена"
        return 1
    fi
    
    if [[ "$timeout" =~ ^[0-9]+$ ]] && [[ "$timeout" -ge 0 ]] && [[ "$timeout" -le 300 ]]; then
        set_timeout "$timeout"
        update_grub > /dev/null 2>&1
        
        dialog --title "Успех" \
            --msgbox "Таймаут установлен: $timeout секунд\n\nОбновление GRUB выполнено" \
            10 50
        
        log_ok "Таймаут установлен: $timeout секунд"
        return 0
    else
        dialog --title "Ошибка" \
            --msgbox "Неверное значение!\n\nВведите число от 0 до 300" \
            10 50
        return 1
    fi
}

# ============================================================================
# 4. ПОКАЗАТЬ ТЕКУЩИЕ НАСТРОЙКИ
# ============================================================================

show_current_settings() {
    # Показывает текущие настройки GRUB
    log_info "Показ текущих настроек..."
    
    local settings_info=""
    
    # Параметры из /etc/default/grub
    settings_info+="╔═══════════════════════════════════════════════════╗\n"
    settings_info+="║           ПАРАМЕТРЫ /etc/default/grub           ║\n"
    settings_info+="╚═══════════════════════════════════════════════════╝\n"
    
    if [[ -f "$GRUB_DEFAULT" ]]; then
        local params=$(grep -v "^#" "$GRUB_DEFAULT" | grep -v "^$" | head -15)
        if [[ -n "$params" ]]; then
            settings_info+="$params\n"
        else
            settings_info+="  (пусто)\n"
        fi
    else
        settings_info+="  Файл $GRUB_DEFAULT не найден\n"
    fi
    
    settings_info+="\n"
    
    # Доступные ОС
    settings_info+="╔═══════════════════════════════════════════════════╗\n"
    settings_info+="║              ДОСТУПНЫЕ ОС В GRUB                ║\n"
    settings_info+="╚═══════════════════════════════════════════════════╝\n"
    
    if [[ -f "$GRUB_CFG" ]]; then
        local os_list=$(grep -E "menuentry|submenu" "$GRUB_CFG" | sed 's/^.*"\(.*\)".*$/- \1/' | head -10)
        if [[ -n "$os_list" ]]; then
            settings_info+="$os_list\n"
        else
            settings_info+="  (нет записей)\n"
        fi
    else
        settings_info+="  Файл $GRUB_CFG не найден\n"
    fi
    
    settings_info+="\n"
    
    # Найденные ОС через os-prober
    settings_info+="╔═══════════════════════════════════════════════════╗\n"
    settings_info+="║          НАЙДЕННЫЕ ОС (os-prober)               ║\n"
    settings_info+="╚═══════════════════════════════════════════════════╝\n"
    
    if has_other_os; then
        local os_prober_list=$(os-prober 2>/dev/null | while IFS=: read -r device os_name rest; do
            echo "- $os_name ($device)"
        done)
        settings_info+="$os_prober_list\n"
    else
        settings_info+="  Другие ОС не найдены\n"
    fi
    
    settings_info+="\n"
    
    # Текущая ОС по умолчанию
    local current_default=$(get_current_default)
    settings_info+="ОС по умолчанию: $current_default\n"
    
    # Текущий таймаут
    if [[ -f "$GRUB_DEFAULT" ]]; then
        local timeout_value=$(grep "^GRUB_TIMEOUT=" "$GRUB_DEFAULT" | cut -d'=' -f2 2>/dev/null)
        settings_info+="Таймаут: ${timeout_value:-5} секунд\n"
    fi
    
    dialog --title "Текущие настройки GRUB" \
        --scrollbar \
        --msgbox "$settings_info" \
        25 70
    
    log_ok "Настройки показаны"
}

# ============================================================================
# 6. ВОССТАНОВЛЕНИЕ ИЗ БЭКАПА
# ============================================================================

restore_from_backup_interactive() {
    # Интерактивное восстановление из бэкапа
    log_info "Восстановление из бэкапа..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        dialog --title "Ошибка" \
            --msgbox "Директория бэкапов не существует" \
            8 50
        return 1
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/*.cfg 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        dialog --title "Информация" \
            --msgbox "Нет доступных бэкапов" \
            8 50
        return 1
    fi
    
    local menu_items=()
    local i=0
    for backup in "${backups[@]}"; do
        i=$((i + 1))
        local size=$(du -h "$backup" 2>/dev/null | cut -f1)
        local date=$(stat -c '%y' "$backup" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
        local name=$(basename "$backup")
        menu_items+=("$i" "$name [$size] $date")
    done
    
    local tempfile=$(mktemp)
    
    dialog \
        --title "Восстановление из бэкапа" \
        --menu "Выберите бэкап для восстановления:" \
        20 70 10 \
        "${menu_items[@]}" \
        2>&1 >"$tempfile"
    
    local exit_code=$?
    local choice=$(cat "$tempfile")
    rm -f "$tempfile"
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$choice" ]]; then
        log_warn "Восстановление отменено"
        return 1
    fi
    
    local backup_file="${backups[$((choice-1))]}"
    
    dialog --title "Подтверждение" \
        --yesno "Восстановить GRUB из бэкапа?\n\n$(basename "$backup_file")" \
        10 60
    
    if [[ $? -ne 0 ]]; then
        log_info "Восстановление отменено"
        return 0
    fi
    
    if restore_grub "$backup_file"; then
        update_grub > /dev/null 2>&1
        dialog --title "Успех" \
            --msgbox "GRUB успешно восстановлен из бэкапа\n\n$(basename "$backup_file")" \
            10 50
        log_ok "Восстановление завершено"
    else
        dialog --title "Ошибка" \
            --msgbox "Ошибка при восстановлении GRUB" \
            8 50
        log_error "Ошибка восстановления"
        return 1
    fi
}

# ============================================================================
# 8. ОЧИСТКА СТАРЫХ БЭКАПОВ
# ============================================================================

clean_old_backups_interactive() {
    # Интерактивная очистка старых бэкапов
    log_info "Очистка старых бэкапов..."
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        dialog --title "Ошибка" \
            --msgbox "Директория бэкапов не существует" \
            8 50
        return 1
    fi
    
    local total_backups=$(ls -1 "$BACKUP_DIR"/*.cfg 2>/dev/null | wc -l)
    
    if [[ $total_backups -eq 0 ]]; then
        dialog --title "Информация" \
            --msgbox "Нет бэкапов для очистки" \
            8 50
        return 0
    fi
    
    local tempfile=$(mktemp)
    
    dialog \
        --title "Очистка бэкапов" \
        --inputbox "Всего бэкапов: $total_backups\n\nСколько бэкапов оставить (по умолчанию 5):" \
        12 60 "5" \
        2>&1 >"$tempfile"
    
    local exit_code=$?
    local keep_count=$(cat "$tempfile")
    rm -f "$tempfile"
    
    if [[ $exit_code -ne 0 ]] || [[ -z "$keep_count" ]]; then
        log_warn "Очистка отменена"
        return 1
    fi
    
    if [[ "$keep_count" =~ ^[0-9]+$ ]] && [[ "$keep_count" -gt 0 ]]; then
        local deleted=$(clean_old_backups "$keep_count")
        dialog --title "Успех" \
            --msgbox "Очистка завершена\n\nОставлено бэкапов: $keep_count\nУдалено: $deleted" \
            10 50
        log_ok "Очистка завершена, оставлено $keep_count бэкапов"
        return 0
    else
        dialog --title "Ошибка" \
            --msgbox "Неверное значение!\n\nВведите положительное число" \
            10 50
        return 1
    fi
}

# ============================================================================
# ОСНОВНОЙ ЦИКЛ
# ============================================================================

main_loop() {
    # Основной цикл программы
    log_info "Запуск основного цикла..."
    
    if ! command -v dialog &> /dev/null; then
        log_error "dialog не установлен!"
        return 1
    fi
    
    while true; do
        local choice=$(show_main_menu)
        
        log_debug "Выбрана опция: $choice"
        
        case $choice in
            "1")
                search_and_add_os
                ;;
            "2")
                set_default_os_interactive
                ;;
            "3")
                set_timeout_interactive
                ;;
            "4")
                show_current_settings
                ;;
            "5")
                dialog --title "Подтверждение" \
                    --yesno "Создать бэкап текущей конфигурации GRUB?" \
                    8 50
                
                if [[ $? -eq 0 ]]; then
                    backup_grub
                    dialog --title "Успех" \
                        --msgbox "Бэкап успешно создан\n\nДиректория: $BACKUP_DIR" \
                        10 50
                fi
                ;;
            "6")
                restore_from_backup_interactive
                ;;
            "7")
                dialog --title "Подтверждение" \
                    --yesno "Обновить конфигурацию GRUB?" \
                    8 50
                
                if [[ $? -eq 0 ]]; then
                    update_grub
                    dialog --title "Успех" \
                        --msgbox "GRUB успешно обновлен" \
                        8 50
                fi
                ;;
            "8")
                clean_old_backups_interactive
                ;;
            "9"|"")
                dialog --title "Выход" \
                    --yesno "Выйти из GRUB Customizer?" \
                    8 50
                
                if [[ $? -eq 0 ]]; then
                    log_info "Выход из программы"
                    clear
                    exit 0
                fi
                ;;
            *)
                log_warn "Неизвестная опция: $choice"
                ;;
        esac
        
        # Пауза перед возвратом в меню
        echo ""
        echo -n "Нажмите Enter для продолжения..."
        read -r
    done
}
