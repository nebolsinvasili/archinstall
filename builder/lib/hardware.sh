#!/usr/bin/env bash
# ============================================================
#
# hardware.sh
#
# Видеокарты: выбор драйвера и его установка
#
# Подключается из builder/archinstall, отдельно не запускается.
# ============================================================

[[ -n "${__HARDWARE_SH:-}" ]] && return
readonly __HARDWARE_SH=1

# Функция для выбора драйверов GPU (автоустановка)
select_gpu_auto() {
    CHOICE=$(whiptail --title "Выбор драйверов видеокарты" \
                      --menu "Выберите тип видеокарты:" 12 60 5 \
                      "1" "Intel" \
                      "2" "AMD" \
                      "3" "Nvidia dkms (рекомендуемый)" \
                      "4" "Nvidia open" \
                      "0" "Не устанавливать драйверы" \
                      3>&1 1>&2 2>&3 \
                      --ok-button "Выбрать" --cancel-button "Отмена")
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo "$CHOICE"
    return 0
}

# Функция для выбора драйвера видеокарты (ручная установка)
# Диалог общий с автоустановкой
select_gpu_manual() {
    select_gpu_auto
}


# Функция для установки драйверов AMD
install_amd_drivers() {
    local target=$1
    echo "  → Установка драйверов AMD..."
    arch-chroot "$target" pacman -S --noconfirm \
        mesa mesa-utils mesa-demos lib32-mesa lib32-mesa-utils \
        libgl lib32-libgl vulkan-radeon lib32-vulkan-radeon \
        vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools \
        vulkan-mesa-layers lib32-vulkan-mesa-layers vkd3d lib32-vkd3d \
        libva lib32-libva libva-utils libva-mesa-driver lib32-libva-mesa-driver \
        libvdpau lib32-libvdpau vdpauinfo xf86-video-amdgpu \
        opencl-headers ocl-icd lib32-ocl-icd nvtop corectrl \
        amf-headers openimagedenoise openvkl
}

# Функция для установки драйверов Intel
install_intel_drivers() {
    local target=$1
    echo "  → Установка драйверов Intel..."
    arch-chroot "$target" pacman -S --noconfirm \
        mesa mesa-utils mesa-demos lib32-mesa lib32-mesa-utils \
        libva lib32-libva libva-utils libva-mesa-driver lib32-libva-mesa-driver \
        vulkan-extra-tools vulkan-headers vulkan-extra-layers \
        vulkan-intel lib32-vulkan-intel vulkan-mesa-layers lib32-vulkan-mesa-layers \
        vulkan-icd-loader lib32-vulkan-icd-loader intel-media-driver \
        intel-compute-runtime intel-gmmlib opencl-headers intel-opencl-clang \
        intel-graphics-compiler libmfx vkd3d lib32-vkd3d intel-gpu-tools \
        vpl-gpu-rt lib32-libgl libgl openimagedenoise openvkl
}

# Функция для установки драйверов Nvidia
install_nvidia_drivers() {
    local target=$1
    local type=$2
    echo "  → Установка драйверов Nvidia..."
    if [ "$type" = "open" ]; then
        arch-chroot "$target" pacman -S --noconfirm \
            nvidia-open nvidia-utils lib32-nvidia-utils \
            nvidia-settings opencl-nvidia lib32-opencl-nvidia \
            vulkan-icd-loader lib32-vulkan-icd-loader
    else
        arch-chroot "$target" pacman -S --noconfirm \
            nvidia-dkms nvidia-utils lib32-nvidia-utils \
            nvidia-settings opencl-nvidia lib32-opencl-nvidia \
            vulkan-icd-loader lib32-vulkan-icd-loader
    fi
}
