#!/usr/bin/env bash
#
# default/llms/config.sh
#
# Настройка Ollama, opencode и Whispering: службы, скачивание моделей и конфигурация.
# Голосовой ввод текста (Whispering): выбор и загрузка моделей распознавания речи.
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

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
OPENCODE_CONFIG_FILE="$OPENCODE_CONFIG_DIR/opencode.json"

OLLAMA_BASE_URL="http://localhost:11434"

OLLAMA_READY=false
OLLAMA_CONTEXT_SET=false

declare -ag SELECTED_MODELS=()
declare -ag SELECTED_NAMES=()

# ============================================================
# Model choices: "tag|display name|description"
# ============================================================
declare -a MODEL_CHOICES=(
    "qwen3-coder:32b|Qwen3 Coder 32B|~21 GB VRAM, мощный кодер (рекомендуется)"
    "qwen3-coder:8b|Qwen3 Coder 8B|~6 GB VRAM, хороший баланс скорости и качества"
    "qwen3-coder:4b|Qwen3 Coder 4B|~4 GB VRAM, для слабого железа"
    "deepseek-r1:14b|DeepSeek R1 14B|~9 GB VRAM, сильные рассуждения"
    "llama3.1:8b|Llama 3.1 8B|~5 GB VRAM, универсальная"
)

# ============================================================
# Wait for Ollama API
# ============================================================
wait_for_ollama() {
    log_info "Waiting for Ollama API to become ready..."
    local i
    for i in {1..15}; do
        if curl -fsS "$OLLAMA_BASE_URL" >/dev/null 2>&1; then
            log_ok "Ollama API is available."
            OLLAMA_READY=true
            return 0
        fi
        sleep 1
    done
    log_warn "Ollama API not responding yet."
    return 1
}

# ============================================================
# Enable and start Ollama service
# ============================================================
setup_ollama_service() {
    log_info "Enabling and starting Ollama service..."

    sudo systemctl enable --now ollama.service

    if ! wait_for_ollama; then
        return 0
    fi

    # Увеличение контекста (num_ctx) — открытый контекст важен для работы инструментов opencode.
    local override_dir="/etc/systemd/system/ollama.service.d"
    local override_file="$override_dir/override.conf"
    local answer

    log_info "opencode требует достаточно большой контекст для корректных вызовов инструментов."
    read -r -p "Set Ollama context length to 32768 tokens? [Y/n]: " answer
    answer=${answer:-Y}

    if [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        sudo mkdir -p "$override_dir"
        if [[ -f "$override_file" ]] && sudo grep -q "OLLAMA_CONTEXT_LENGTH=32768" "$override_file" 2>/dev/null; then
            log_info "Context length is already configured in $override_file"
        elif [[ -f "$override_file" ]]; then
            printf 'Environment=OLLAMA_CONTEXT_LENGTH=32768\n' | sudo tee -a "$override_file" >/dev/null
            log_ok "Updated drop-in: $override_file"
        else
            printf '[Service]\nEnvironment=OLLAMA_CONTEXT_LENGTH=32768\n' | sudo tee "$override_file" >/dev/null
            log_ok "Created drop-in: $override_file"
        fi

        sudo systemctl daemon-reload
        sudo systemctl restart ollama.service
        wait_for_ollama || true
        OLLAMA_CONTEXT_SET=true
    fi
}

# ============================================================
# Interactive model selection
# Populates globals: SELECTED_MODELS, SELECTED_NAMES
# ============================================================
select_models() {
    local choice
    local idx=1
    local entry tag name desc

    log_info "Select models to download:"
    for entry in "${MODEL_CHOICES[@]}"; do
        IFS='|' read -r tag name desc <<< "$entry"
        printf "  %d) %-22s %s\n" "$idx" "$name" "$desc"
        ((idx++))
    done
    printf "  c) Custom model tag\n"
    printf "  s) Skip downloading models\n"

    read -r -p "Selection (comma-separated numbers, e.g. 1,3; default: 1): " choice
    choice=${choice:-1}

    SELECTED_MODELS=()
    SELECTED_NAMES=()

    case "$choice" in
        s|S|skip)
            log_info "Model download skipped."
            return 0
            ;;
        c|C|custom)
            read -r -p "Enter model tag (e.g. qwen3-coder:30b): " custom_tag
            if [[ -z "$custom_tag" ]]; then
                log_error "Model tag cannot be empty. Skipping model download."
                return 0
            fi
            SELECTED_MODELS=("$custom_tag")
            SELECTED_NAMES=("$custom_tag")
            ;;
        *)
            local num
            for num in ${choice//,/ }; do
                num="$(trim "$num")"
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#MODEL_CHOICES[@]} )); then
                    entry="${MODEL_CHOICES[$((num - 1))]}"
                    IFS='|' read -r tag name desc <<< "$entry"
                    SELECTED_MODELS+=("$tag")
                    SELECTED_NAMES+=("$name")
                else
                    log_warn "Invalid selection: $num"
                fi
            done
            ;;
    esac

    if [[ "${#SELECTED_MODELS[@]}" -eq 0 ]]; then
        log_info "No models selected."
    fi
}

# ============================================================
# Pull selected models via ollama
# ============================================================
pull_models() {
    if [[ "$OLLAMA_READY" != true ]]; then
        log_warn "Ollama API unavailable — skipping model downloads. Use 'ollama pull <model>' later."
        return 0
    fi

    local model
    for model in "${SELECTED_MODELS[@]}"; do
        log_info "Pulling model: $model"
        ollama pull "$model"
        log_ok "Model '$model' pulled successfully."
    done
}

# ============================================================
# Generate opencode config for the Ollama provider
# ============================================================
configure_opencode() {
    if [[ "${#SELECTED_MODELS[@]}" -eq 0 ]]; then
        log_info "No models selected — skipping opencode provider configuration."
        return 0
    fi

    mkdir -p "$OPENCODE_CONFIG_DIR"

    local default_model="${SELECTED_MODELS[0]}"
    local -a entries=()
    local i

    for i in "${!SELECTED_MODELS[@]}"; do
        entries+=("$(jq -nc --arg id "${SELECTED_MODELS[$i]}" --arg name "${SELECTED_NAMES[$i]}" '{id: $id, name: $name}')")
    done

    local models_json
    models_json="$(jq -nc 'reduce inputs as $m ({}; .[$m.id] = {name: $m.name})' <<<"$(printf '%s\n' "${entries[@]}")")"

    jq -n \
        --argjson models "$models_json" \
        --arg default_model "ollama/${default_model}" \
        '{
            "$schema": "https://opencode.ai/config.json",
            "model": $default_model,
            "provider": {
                "ollama": {
                    "npm": "@ai-sdk/openai-compatible",
                    "name": "Ollama (local)",
                    "options": {
                        "baseURL": "http://localhost:11434/v1"
                    },
                    "models": $models
                }
            }
        }' > "$OPENCODE_CONFIG_FILE"

    log_ok "opencode config written to: $OPENCODE_CONFIG_FILE"
}

# ============================================================
# Whispering (голосовой ввод текста)
# ============================================================
WHISPER_BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# Варианты моделей: "имя файла|название|описание"
declare -a WHISPER_MODEL_CHOICES=(
    "ggml-large-v3-turbo.bin|large-v3-turbo|~1.6 ГБ, максимальная точность для диктовки (рекомендуется)"
    "ggml-large-v3.bin|large-v3|~3 ГБ, полная модель, максимальная точность"
    "ggml-large-v3-q5_0.bin|large-v3-q5_0|~1 ГБ, компромисс скорость/качество"
    "ggml-medium.bin|medium|~1.5 ГБ, быстрее, чуть ниже точность"
)

declare -ag SELECTED_WHISPER_MODELS=()

# Определяет каталог данных Whispering (Epicenter).
resolve_whisper_data_dir() {
    if [[ -n "${EPICENTER_DATA_DIR:-}" && "${EPICENTER_DATA_DIR}" != "" ]]; then
        echo "${EPICENTER_DATA_DIR}"
        return 0
    fi
    if [[ -n "${XDG_DATA_HOME:-}" ]]; then
        echo "${XDG_DATA_HOME}/so.epicenter"
        return 0
    fi
    echo "$HOME/.local/share/so.epicenter"
}

# Интерактивный выбор моделей для Whispering.
select_whisper_models() {
    local choice
    local idx=1
    local entry tag name desc

    log_info "Выберите модели для Whispering (скачиваются при установке):"
    for entry in "${WHISPER_MODEL_CHOICES[@]}"; do
        IFS='|' read -r tag name desc <<< "$entry"
        printf "  %d) %-18s %s\n" "$idx" "$name" "$desc"
        ((idx++))
    done
    printf "  c) Своё имя файла модели\n"
    printf "  s) Пропустить (скачать модель в приложении)\n"

    read -r -p "Выбор (список через запятую, напр. 1,2; по умолчанию: 1): " choice
    choice=${choice:-1}

    SELECTED_WHISPER_MODELS=()

    case "$choice" in
        s|S|skip)
            log_info "Загрузка моделей Whispering пропущена."
            return 0
            ;;
        c|C|custom)
            read -r -p "Введите имя файла модели (напр. ggml-large-v3-turbo.bin): " custom_model
            if [[ -z "$custom_model" ]]; then
                log_error "Имя файла модели не может быть пустым. Пропуск загрузки."
                return 0
            fi
            SELECTED_WHISPER_MODELS=("$custom_model")
            ;;
        *)
            local num
            for num in ${choice//,/ }; do
                num="$(trim "$num")"
                if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#WHISPER_MODEL_CHOICES[@]} )); then
                    entry="${WHISPER_MODEL_CHOICES[$((num - 1))]}"
                    IFS='|' read -r tag name desc <<< "$entry"
                    SELECTED_WHISPER_MODELS+=("$tag")
                else
                    log_warn "Некорректный выбор: $num"
                fi
            done
            ;;
    esac

    if [[ "${#SELECTED_WHISPER_MODELS[@]}" -eq 0 ]]; then
        log_info "Модели Whispering не выбраны."
    fi
}

# Скачивание выбранных моделей Whispering в каталог данных приложения.
download_whisper_models() {
    if [[ "${#SELECTED_WHISPER_MODELS[@]}" -eq 0 ]]; then
        return 0
    fi

    local data_dir
    data_dir="$(resolve_whisper_data_dir)"
    local models_dir="$data_dir/models"

    mkdir -p "$models_dir"

    local model_file
    for model_file in "${SELECTED_WHISPER_MODELS[@]}"; do
        log_info "Скачивание модели: $model_file"
        if curl -fL --retry 3 --progress-bar \
            -o "$models_dir/$model_file" \
            "$WHISPER_BASE_URL/$model_file"; then
            log_ok "Модель '$model_file' скачана в $models_dir"
        else
            log_warn "Не удалось скачать '$model_file'. Скачайте её позже в приложении Whispering."
        fi
    done
}

# Настройка Whispering: каталог моделей, выбор и загрузка моделей.
setup_whispering() {
    log_ok "Настройка Whispering (голосовой ввод текста)..."

    log_info "Каталог данных Whispering: $(resolve_whisper_data_dir)"

    select_whisper_models
    download_whisper_models
}
show_summary() {
    log_ok "Ollama and opencode configuration completed successfully!"

    printf "\n%s\n" "Detailed summary:"
    if [[ "$OLLAMA_CONTEXT_SET" == true ]]; then
        printf "  - Ollama context length: 32768 tokens (%s)\n" "/etc/systemd/system/ollama.service.d/override.conf"
    fi
    if [[ "${#SELECTED_MODELS[@]}" -gt 0 ]]; then
        printf "  - Installed models:\n"
        local model
        for model in "${SELECTED_MODELS[@]}"; do
            printf "      * %s\n" "$model"
        done
        printf "  - Default opencode model: ollama/%s\n" "${SELECTED_MODELS[0]}"
    fi

    printf "\n%s\n" "Next steps:"
    printf "  - Run 'opencode' to start the AI assistant.\n"
    log_warn "If opencode is already running, quit and restart it to apply the new configuration."
}

# ============================================================
# Main
# ============================================================
main() {
    log_info "LLM Configuration started"

    setup_ollama_service
    select_models
    pull_models
    configure_opencode
    show_summary
}

# ============================================================
# Entry point
# ============================================================
[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"