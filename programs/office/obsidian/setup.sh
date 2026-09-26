#!/usr/bin/env bash
#
# programs/office/obsidian/setup.sh
#
# Установка Obsidian и развертывание хранилища с настройками интерфейса и плагинов.
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

# Хранилище Obsidian — git-репозиторий в домашней папке пользователя.
export VAULT_REPO="${VAULT_REPO:-https://github.com/nebolsinvasili/Workspace.git}"
export VAULT_DIR="${VAULT_DIR:-$HOME/Workspace}"

# ============================================================
# clone_vault
# ============================================================
clone_vault() {
    if [[ -d "$VAULT_DIR/.git" ]]; then
        log_info "Обновление хранилища Obsidian: $VAULT_DIR"
        git -C "$VAULT_DIR" pull --ff-only
    elif [[ -e "$VAULT_DIR" ]] && [[ -n "$(ls -A "$VAULT_DIR" 2>/dev/null)" ]]; then
        log_error "Путь $VAULT_DIR существует и не является хранилищем Obsidian."
        return 1
    else
        log_info "Клонирование хранилища Obsidian: $VAULT_REPO"
        git clone "$VAULT_REPO" "$VAULT_DIR"
    fi

    mkdir -p "$VAULT_DIR/.obsidian"
}

# ============================================================
# deploy_config
#
# Разворачивает шаблон конфигурации Obsidian из config/ в .obsidian/
# хранилища. В отличие от остальных программ, копируем файлы, а не
# stow-симлинки: Obsidian сам перезаписывает эти файлы при сохранении
# настроек, поэтому ссылки были бы разорваны при первом же запуске.
# Существующие пользовательские настройки не перезаписываются —
# заменяются только отсутствующие, пустые ({} / []) или уже
# развёрнутые из шаблона файлы.
# ============================================================
deploy_config() {
    local src_root="$SCRIPT_DIR/config"
    local target_root="$VAULT_DIR/.obsidian"

    [[ -d "$src_root" ]] || return 0
    mkdir -p "$target_root"

    local src_file rel target_file content
    while IFS= read -r -d '' src_file; do
        rel="${src_file#"$src_root"/.obsidian/}"
        [[ "$rel" != "$src_file" ]] || continue
        target_file="$target_root/$rel"

        if [[ -e "$target_file" && ! -L "$target_file" ]]; then
            content="$(tr -d '[:space:]' < "$target_file" 2>/dev/null || true)"
            if [[ -s "$target_file" && "$content" != '{}' && "$content" != '[]' ]]; then
                log_warn "Оставляем пользовательский конфиг: $target_file"
                continue
            fi
        fi

        cp -f "$src_file" "$target_file"
        log_ok "Развёрнут конфиг: $target_file"
    done < <(find "$src_root" -type f -print0)
}

# ============================================================
# Main
# ============================================================
main() {
    log_info "Установка Obsidian и компонентов..."

    "$PKG_INSTALLER_DIR/dependencies_installer.sh" \
        --file "$DEPENDENCIES_FILE" \
        "$@" \
        && clone_vault \
        && deploy_config \
        && ./config.sh
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"