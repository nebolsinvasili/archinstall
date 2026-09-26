#!/usr/bin/env bash
# default/drivers/nvidia/install.sh
# Автоматическая установка драйверов NVIDIA с полной очисткой и обновлением системы

set -euo pipefail

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi

ROOT_DIR="$SCRIPT_DIR"
while [[ ! -d "$ROOT_DIR/pkg-installer" && "$ROOT_DIR" != "/" ]]; do
    ROOT_DIR="$(dirname "$ROOT_DIR")"
done

[[ -f "$ROOT_DIR/lib/init.sh" ]] || {
    echo "Не найден корень проекта (маркер 'pkg-installer')." >&2
    exit 1
}

source "$ROOT_DIR/lib/init.sh"

# ------------------------------------------------------------
# Определение PCI-ID видеокарты
# ------------------------------------------------------------
get_gpu_pci_id() {
    lspci -nn | grep -E "VGA|3D" | head -n1 | sed -E 's/.*\[(10de:[0-9a-f]{4})\].*/\1/' || true
}

# ------------------------------------------------------------
# Выбор базового имени пакета
# ------------------------------------------------------------
select_nvidia_base() {
    local pci_id="$1"
    if [[ -z "$pci_id" ]]; then
        echo "nvidia"
        return
    fi

    case "$pci_id" in
        # Fermi – 390xx
        10de:0a80|10de:0a8c|10de:0dc0|10de:0de0)
            echo "nvidia-390xx" ;;
        # Kepler – 470xx
        10de:1180|10de:1184|10de:1188|10de:1189|10de:11b0|10de:11b4|10de:11b7|10de:11ba|10de:11c0|10de:11c2|10de:11c4|10de:11c6|10de:11c8|10de:11ca|10de:11cc|10de:11ce|10de:11d0|10de:11d2|10de:11d4|10de:11d6|10de:11d8|10de:11da|10de:11dc|10de:11de|10de:11e0|10de:11e2|10de:11e3|10de:11e4|10de:11e5|10de:11e6|10de:11e7|10de:11e8|10de:11e9|10de:11ea|10de:11eb|10de:11ec|10de:11ed|10de:11ee|10de:11ef|10de:11f0|10de:11f1|10de:11f2|10de:11f3|10de:11f4|10de:11f5|10de:11f6|10de:11f7|10de:11f8|10de:11f9|10de:11fa|10de:11fb|10de:11fc|10de:11fd|10de:11fe|10de:11ff)
            echo "nvidia-470xx" ;;
        # Все остальные – последняя стабильная
        *)
            echo "nvidia" ;;
    esac
}

# ------------------------------------------------------------
# Основной процесс
# ------------------------------------------------------------
log_ok "Определение видеокарты..."
GPU_PCI_ID="$(get_gpu_pci_id)"
if [[ -n "$GPU_PCI_ID" ]]; then
    log_info "Найден GPU: $GPU_PCI_ID"
else
    log_warn "Не удалось определить PCI‑ID. Будет использована последняя стабильная версия."
fi

BASE="$(select_nvidia_base "$GPU_PCI_ID")"
log_ok "Выбрана база драйвера: $BASE"

# Формируем список пакетов для установки
if [[ "$BASE" == "nvidia" ]]; then
    PACKAGES=(
        "nvidia-dkms"
        "nvidia-utils"
        "lib32-nvidia-utils"
        "nvidia-settings"
        "opencl-nvidia"
        "lib32-opencl-nvidia"
        "nvtop"
    )
else
    PACKAGES=(
        "${BASE}-dkms"
        "${BASE}-utils"
        "lib32-${BASE}-utils"
        "${BASE}-settings"
        "opencl-${BASE}"
        "lib32-opencl-${BASE}"
        "nvtop"
    )
fi

log_info "Будут установлены пакеты: ${PACKAGES[*]}"

# ------------------------------------------------------------
# Полное обновление системы (чтобы избежать конфликтов зависимостей)
# ------------------------------------------------------------
log_ok "Обновление системы перед установкой драйверов..."
sudo pacman -Syu --noconfirm

# ------------------------------------------------------------
# Полная очистка старых пакетов NVIDIA и CUDA
# ------------------------------------------------------------
log_ok "Поиск всех установленных пакетов, связанных с NVIDIA или CUDA (кроме nvtop и linux-firmware)..."
OLD_PKGS=$(pacman -Q | grep -iE "nvidia|cuda" | grep -v -E "nvtop|linux-firmware" | awk '{print $1}' || true)
if [[ -n "$OLD_PKGS" ]]; then
    log_warn "Обнаружены старые пакеты: $OLD_PKGS"
    log_ok "Удаляем их перед установкой новых (включая CUDA)..."
    sudo pacman -Rns --noconfirm $OLD_PKGS 2>/dev/null || true
else
    log_info "Старых пакетов NVIDIA/CUDA не найдено."
fi

# Дополнительная проверка, чтобы убедиться, что не осталось lib32-opencl-nvidia*
REMAINING=$(pacman -Q | grep -E "lib32.*opencl.*nvidia" | awk '{print $1}' || true)
if [[ -n "$REMAINING" ]]; then
    log_warn "Найдены оставшиеся пакеты opencl: $REMAINING, удаляем принудительно..."
    sudo pacman -Rdd --noconfirm $REMAINING 2>/dev/null || true
fi

# ------------------------------------------------------------
# Установка новых драйверов
# ------------------------------------------------------------
log_ok "Установка драйверов через yay..."
yay -S --needed --noconfirm "${PACKAGES[@]}"

# Если был удалён linux-firmware-nvidia, переустановим linux-firmware
if ! pacman -Q linux-firmware &>/dev/null; then
    log_warn "Пакет linux-firmware был удалён, переустанавливаем..."
    sudo pacman -S --needed --noconfirm linux-firmware
fi

# Обновление initramfs
log_ok "Обновление initramfs..."
sudo mkinitcpio -P

# Блокировка модуля nouveau (если ещё не заблокирован)
if [[ ! -f /etc/modprobe.d/blacklist-nouveau.conf ]]; then
    log_ok "Блокировка модуля nouveau..."
    echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf >/dev/null
    sudo dracut --force 2>/dev/null || true
fi

# ------------------------------------------------------------
# CUDA (опционально)
# ------------------------------------------------------------
printf "Хотите установить CUDA? [y/N]: "
read -r answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    log_ok "Установка CUDA..."
    yay -S --needed --noconfirm cuda cudnn opencv-cuda
    log_ok "CUDA установлена."
else
    log_info "Установка CUDA пропущена."
fi

# ------------------------------------------------------------
# Проверка статуса
# ------------------------------------------------------------
log_ok "Проверка видеокарты и драйвера:"
lspci -k | grep -A 3 -E "(VGA|3D)"
echo ""
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi || log_warn "Драйвер загружен, но nvidia-smi завершился с ошибкой. Попробуйте перезагрузить систему."
else
    log_warn "nvidia-smi не найден. Возможно, драйвер не активирован. Перезагрузите ПК."
fi
