#!/usr/bin/env bash
#
# default/ssh/config.sh
#
# Интерактивная генерация SSH ключей, настройка агента и линковка конфигурации.
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

# ============================================================
# Select SSH key type
# Populates associative array: key_info[type], key_info[bits]
# ============================================================
select_key_type() {
    declare -n key_info_ref=$1

    log_info "Select SSH key type:"
    echo "  1) Ed25519   (recommended, modern and secure)"
    echo "  2) RSA 4096  (legacy compatibility)"
    echo "  3) ECDSA 521 (optional, less common)"

    read -r -p "Selection: " key_choice
    key_choice=${key_choice:-1}

    case "$key_choice" in
        1) key_info_ref[type]="ed25519"; key_info_ref[bits]="" ;;
        2) key_info_ref[type]="rsa";     key_info_ref[bits]=4096 ;;
        3) key_info_ref[type]="ecdsa";   key_info_ref[bits]=521 ;;
        *)
            log_warn "Invalid selection. Defaulting to Ed25519."
            key_info_ref[type]="ed25519"
            key_info_ref[bits]="" ;;
    esac
}

# ============================================================
# Input email (used as key comment)
# Returns via stdout
# ============================================================
input_email() {
    read -r -p "Enter email address for key comment [no-reply@example.com]: " user_email
    user_email=${user_email:-"no-reply@example.com"}
    echo "$user_email"
}

# ============================================================
# Input key file path
# Args: key_type
# Returns via stdout
# ============================================================
input_keyfile() {
    local key_type="$1"
    local default_keyfile="$HOME/.ssh/id_${key_type}"

    read -r -p "Enter key file path [${default_keyfile}]: " keyfile
    keyfile=${keyfile:-$default_keyfile}
    echo "$keyfile"
}

# ============================================================
# Check for existing key files and optionally create backups
# Args: keyfile
# ============================================================
check_existing_keyfile() {
    local keyfile="$1"
    local backup_file=""

    if [[ -f "$keyfile" ]]; then
        log_warn "Key file already exists: $keyfile"
        read -r -p "Create a backup before overwriting? [Y/n]: " backup
        backup=${backup:-Y}

        if [[ "$backup" =~ ^([yY]|[yY][eE][sS])$ ]]; then
            backup_file="${keyfile}.bak_$(date +%s)"
            local backup_pubfile="${keyfile}.pub.bak_$(date +%s)"

            mv "$keyfile" "$backup_file"
            [[ -f "${keyfile}.pub" ]] && mv "${keyfile}.pub" "$backup_pubfile"

            log_ok "Existing key backed up to: $backup_file"
        else
            log_warn "Existing key will be overwritten without backup."
            rm -f "$keyfile"
        fi
    fi

    echo "$backup_file"
}

# ============================================================
# Input passphrase
# Returns via stdout
# ============================================================
input_passphrase() {
    local passphrase passphrase2
    local max_repeat_attempts=3
    local repeat_attempt

    while :; do
        read -s -p "Enter passphrase (leave empty for no passphrase): " passphrase >&2
        printf "\n" >&2

        if [[ -z "$passphrase" ]]; then
            log_warn "Empty passphrase selected. Private key will not be encrypted." >&2
            echo ""
            return 0
        fi

        repeat_attempt=1
        while (( repeat_attempt <= max_repeat_attempts )); do
            read -s -p "Confirm passphrase (${repeat_attempt}/${max_repeat_attempts}): " passphrase2 >&2
            printf "\n" >&2

            if [[ "$passphrase" == "$passphrase2" ]]; then
                echo "$passphrase"
                return 0
            fi

            log_error "Passphrases do not match." >&2
            ((repeat_attempt++))
        done

        log_warn "Maximum confirmation attempts exceeded. Restarting passphrase entry." >&2
    done
}

# ============================================================
# Confirm key creation
# ============================================================
confirm_creation() {
    local type="$1"
    local bits="$2"
    local email="$3"
    local keyfile="$4"

    log_info "The following SSH key will be created:"
    printf "  Type : %s %s\n" "$type" "${bits:+(${bits}-bit)}"
    printf "  Email: %s\n" "$email"
    printf "  File : %s\n" "$keyfile"

    read -r -p "Proceed with key generation? [Y/n]: " confirm
    confirm=${confirm:-Y}

    [[ "$confirm" =~ ^([yY]|[yY][eE][sS])$ ]] || {
        log_error "Operation cancelled by user."
        return 1
    }
}

# ============================================================
# Generate SSH key
# ============================================================
generate_key() {
    local type="$1"
    local bits="$2"
    local keyfile="$3"
    local email="$4"
    local passphrase="$5"

    mkdir -p "$(dirname "$keyfile")"
    chmod 700 "$(dirname "$keyfile")"

    log_info "Generating SSH key..."

    if [[ -z "$bits" ]]; then
        ssh-keygen -t "$type" -C "$email" -f "$keyfile" -N "$passphrase"
    else
        ssh-keygen -t "$type" -b "$bits" -C "$email" -f "$keyfile" -N "$passphrase"
    fi

    log_ok "SSH key successfully generated."
}

# ============================================================
# Add key to ssh-agent
# ============================================================
add_to_agent() {
    local keyfile="$1"

    log_info "Starting ssh-agent and adding key..."

    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true

    [[ -f "$keyfile" ]] || {
        log_error "Private key file not found: $keyfile"
        return 1
    }

    ssh-add "$keyfile"
    log_ok "Key added to ssh-agent."
}

# ============================================================
# Display public key and copy to clipboard
# ============================================================
show_and_copy_pubkey() {
    local keyfile="$1"
    local pubkey="${keyfile}.pub"

    # Безопасный вывод строк с дефисами
    printf "\n%s\n" "----- BEGIN PUBLIC KEY -----"
    cat "$pubkey"
    printf "%s\n\n" "----- END PUBLIC KEY -----"

    if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        wl-copy < "$pubkey" && log_ok "Public key copied to clipboard (Wayland)."
    elif command -v xclip >/dev/null 2>&1; then
        xclip -selection clipboard < "$pubkey" && log_ok "Public key copied to clipboard (X11)."
    elif command -v pbcopy >/dev/null 2>&1; then
        pbcopy < "$pubkey" && log_ok "Public key copied to clipboard (macOS)."
    else
        log_warn "Clipboard utility not available. Copy the key manually."
    fi
}

# ============================================================
# Вспомогательные функции для работы с GitHub
# ============================================================

# 1. Функция открытия браузера
open_github_settings() {
    local keys_url="https://github.com/settings/keys"

    # Проверяем наличие графической сессии
    if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
        return 1
    fi

    read -r -p "Open GitHub settings now in your browser? [Y/n]: " open_browser
    open_browser=${open_browser:-Y}

    if [[ "$open_browser" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        log_info "Opening GitHub SSH settings..."
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$keys_url" >/dev/null 2>&1 &
        elif command -v open >/dev/null 2>&1; then
            open "$keys_url" >/dev/null 2>&1 &
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "$keys_url" >/dev/null 2>&1 &
        fi
        return 0
    fi

    return 1
}

# 2. Функция автоматической проверки соединения
verify_ssh_connection() {
    printf "\n%s\n" "--> Action required: Paste the key (Ctrl+V) on the GitHub page and save it."
    read -r -p "Once you are done and ready to verify, press [ENTER] to continue..."

    log_info "Verifying SSH connection to GitHub..."
    printf "%s\n" "Running: ssh -T git@github.com"
    echo "--------------------------------------------------------"
    
    # Отключаем строгую проверку ошибок (set -e), так как ssh -T возвращает код 1 при успехе
    set +e
    ssh -T -o StrictHostKeyChecking=accept-new git@github.com
    set -e
    
    echo "--------------------------------------------------------"
}

# 3. Главный диспетчер инструкций
show_instructions() {
    log_ok "SSH key generation completed successfully."
    
    local keys_url="https://github.com/settings/keys"
    printf "%s\n" "Your public key is already copied to the clipboard!"
    printf "Add the key at:  %s\n\n" "$keys_url"

    # Проверяем, открыл ли пользователь сайт. Если да — запускаем проверку.
    if open_github_settings; then
        verify_ssh_connection
    else
        log_info "Skipping automatic verification. You can verify later using: ssh -T git@github.com"
    fi
}

# ============================================================
# Main function
# ============================================================
main() {
    log_info "SSH Configuration started"

    # 1. Сбор параметров
    declare -A key_info
    select_key_type key_info

    local user_email
    user_email="$(input_email)"

    local keyfile
    keyfile="$(input_keyfile "${key_info[type]}")"

    check_existing_keyfile "$keyfile"

    local passphrase
    passphrase="$(input_passphrase)"

    # 2. Подтверждение и генерация
    confirm_creation "${key_info[type]}" "${key_info[bits]}" "$user_email" "$keyfile"
    generate_key "${key_info[type]}" "${key_info[bits]}" "$keyfile" "$user_email" "$passphrase"

    # 3. Применение конфигурации ~/.ssh/config через stow (если папка config существует)
    if [ -d "$SCRIPT_DIR/config" ]; then
        log_info "Restoring SSH configurations via stow..."
        cd "$SCRIPT_DIR"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        stow -R -v -t "$HOME/.ssh" config
        [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
    fi

    # 4. Добавление в агент и вывод ключа
    add_to_agent "$keyfile"
    show_and_copy_pubkey "$keyfile"
    show_instructions
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
