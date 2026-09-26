#!/usr/bin/env bash
#
# proxy-setup.sh
#
# Настройка системного прокси с поддержкой конфигурационного файла.
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

usage() {
    cat <<EOF
Использование: $0 --user=<USERNAME> --pass=<PASSWORD> --host=<IP> --port=<PORT> [--global]
Параметры:
  --user       Логин для прокси
  --pass       Пароль для прокси
  --host       IP-адрес или домен прокси
  --port       Порт прокси
  --global     Установить глобально (в /etc/profile.d/proxy.sh)
  --config     Загрузить параметры из конфигурационного файла
  -h, --help   Показать эту справку и выйти

Примеры:
  $0 --user=alice --pass=secret --host=192.168.1.10 --port=8080 --global
  $0 --config=proxy.conf
EOF
    exit 1
}

SET_GLOBAL=false
CONFIG_FILE=""

# === Парсинг параметров ===
for arg in "$@"; do
    case $arg in
        --user=*)   PROXY_USER="${arg#*=}" ;;
        --pass=*)   PROXY_PASS="${arg#*=}" ;;
        --host=*)   PROXY_HOST="${arg#*=}" ;;
        --port=*)   PROXY_PORT="${arg#*=}" ;;
        --global)   SET_GLOBAL=true ;;
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        -h|--help)  usage ;;
        *) echo "Неизвестный параметр: $arg"; usage ;;
    esac
done

# === Если задан config-файл ===
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Ошибка: конфигурационный файл $CONFIG_FILE не найден!"
        exit 1
    fi
    log_ok "Загружаем настройки из $CONFIG_FILE"
    while IFS='=' read -r key value; do
        case "$key" in
            user)   PROXY_USER="$value" ;;
            pass)   PROXY_PASS="$value" ;;
            host)   PROXY_HOST="$value" ;;
            port)   PROXY_PORT="$value" ;;
            global) [[ "$value" =~ ^(true|1|yes)$ ]] && SET_GLOBAL=true ;;
        esac
    done < <(grep -v '^#' "$CONFIG_FILE" | grep .)
fi

# === Проверка обязательных параметров ===
if [[ -z "${PROXY_USER:-}" || -z "${PROXY_PASS:-}" || -z "${PROXY_HOST:-}" || -z "${PROXY_PORT:-}" ]]; then
    log_error "Ошибка: не все обязательные параметры заданы!"
    usage
fi

# === Переменные ===
PROXY_URL="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}/"

# === Настройка глобальная или локальная ===
if $SET_GLOBAL; then
    log_ok "Создание глобального конфига в /etc/profile.d/proxy.sh..."

    sudo tee /etc/profile.d/proxy.sh > /dev/null <<EOF
#!/bin/sh
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"
export ftp_proxy="${PROXY_URL}"
export no_proxy="localhost,127.0.0.1,::1"
EOF
    sudo chmod +x /etc/profile.d/proxy.sh

    log_ok "Обновление sudoers для сохранения proxy-переменных..."
    if ! sudo grep -q 'env_keep += "http_proxy https_proxy' /etc/sudoers; then
        echo 'Defaults env_keep += "http_proxy https_proxy ftp_proxy no_proxy"' | sudo tee -a /etc/sudoers
    else
        log_ok "sudo уже настроен для proxy-переменных"
    fi
else
    log_ok "Установка proxy-переменных только для текущего пользователя..."

    # Удаляем старые строки про proxy, если есть
    sed -i '/# Proxy settings/,+5d' ~/.bashrc

    # Добавляем новый блок
    cat >> ~/.bashrc <<EOF
# Proxy settings
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"
export ftp_proxy="${PROXY_URL}"
export no_proxy="localhost,127.0.0.1,::1"
EOF
    source ~/.bashrc
fi

# === Немедленное применение для текущего сеанса ===
log_ok "Применение proxy-переменных в текущем сеансе..."
export http_proxy="${PROXY_URL}"
export https_proxy="${PROXY_URL}"
export ftp_proxy="${PROXY_URL}"
export no_proxy="localhost,127.0.0.1,::1"

# === Проверка ===
log_ok "Проверка прокси-соединения через curl..."
if curl --silent https://api.ipify.org --max-time 10; then
    echo -e "\n[✓] Proxy is set up and working."
else
    log_warn "Proxy check failed."
fi

log_ok "Настройка прокси завершена. Перезагрузка или повторный вход полностью применят параметры."