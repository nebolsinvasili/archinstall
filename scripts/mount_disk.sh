#!/usr/bin/env bash
#
# mount_disk.sh
#
# Автомонтирование USB-диска по метке (LABEL) через /etc/fstab.
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

# Начальные настройки по умолчанию
LABEL="Seagate-Basic"
MOUNT_POINT="/mnt/$LABEL"
FSTAB_FILE="/etc/fstab"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="/home/$USER_NAME"
LINK="$USER_HOME/$LABEL"
USER_UID=$(id -u "$USER_NAME")
DRY_RUN=false
CREATE_SYMLINK=false
DEVICE=""

# Функция для показа справки
show_help() {
  cat <<EOF
Использование:
  $0 [опции]

Опции:
  -s, --symlink          Создать символическую ссылку в домашней директории пользователя
  -h, --help             Показать эту справку
  --label=<LABEL>        Указать имя метки устройства (по умолчанию $LABEL)
  --mount-point=<DIR>    Указать точку монтирования (по умолчанию $MOUNT_POINT)
  --dry-run              Показать, что будет сделано, но не выполнять реальные изменения
  --select-disk          Позволяет выбрать диск для монтирования

Пример:
  sudo $0 --symlink
  sudo $0 --label=MyDrive --mount-point=/mnt/CustomMount --dry-run
EOF
}

# Функция для обработки аргументов командной строки
parse_args() {
  for arg in "$@"; do
    case "$arg" in
      -s|--symlink)
        CREATE_SYMLINK=true
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      --label=*)
        LABEL="${arg#*=}"
        MOUNT_POINT="/mnt/$LABEL"
        LINK="$USER_HOME/$LABEL"
        ;;
      --mount-point=*)
        MOUNT_POINT="${arg#*=}"
        LINK="$USER_HOME/$LABEL"
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      --select-disk)
        select_disk
        ;;
      *)
        echo "Неизвестный параметр: $arg"
        show_help
        exit 1
        ;;
    esac
  done
}

# Функция для выбора диска
select_disk() {
  log_info "Доступные диски:"
  # Используем lsblk для отображения устройств с метками (если они есть)
  lsblk -o NAME,SIZE,LABEL,MOUNTPOINT

  echo -n "Введите имя устройства (например, sda1): "
  read DEVICE

  # Проверка, существует ли устройство
  if [[ -z "$DEVICE" ]] || ! lsblk | grep -q "$DEVICE"; then
    log_error "Устройство не найдено, попробуйте снова."
    exit 1
  fi

  log_ok "Выбран диск: /dev/$DEVICE"

  # Попытка извлечь метку устройства
  LABEL=$(lsblk -no LABEL /dev/$DEVICE || true)

  # Если метка пуста, используем имя устройства как метку
  if [[ -z "$LABEL" ]]; then
    LABEL="$DEVICE"
    log_info "Метка не найдена, использую имя устройства ($DEVICE) как метку."
  fi

  MOUNT_POINT="/mnt/$LABEL"
  LINK="$USER_HOME/$LABEL"
}

# Функция для проверки прав пользователя
check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "Запусти через sudo"
    exit 1
  fi
}

# Функция для поиска устройства по LABEL
find_device() {
  if [[ -z "$DEVICE" ]]; then
    DEVICE=$(blkid -L "$LABEL" || true)
  fi

  if [[ -z "$DEVICE" ]]; then
    log_error "Диск с LABEL=$LABEL не найден"
    exit 1
  fi
}

# Функция для обновления fstab
update_fstab() {
  mkdir "$MOUNT_POINT"

  COMMENT="# /dev/$DEVICE"
  ENTRY="LABEL=$LABEL  $MOUNT_POINT  auto  nofail,x-systemd.automount,user  0  2"

  if grep -qE "^[^#]*LABEL=$LABEL[[:space:]]+$MOUNT_POINT" "$FSTAB_FILE"; then
    log_info "Запись с LABEL=$LABEL найдена"

    LINE_NUM=$(grep -nE "^[^#]*LABEL=$LABEL[[:space:]]+$MOUNT_POINT" "$FSTAB_FILE" | cut -d: -f1)
    PREV_LINE_NUM=$((LINE_NUM - 1))
    PREV_LINE=$(sed -n "${PREV_LINE_NUM}p" "$FSTAB_FILE")

    if [[ "$PREV_LINE" != "$COMMENT" ]]; then
      log_info "Комментарий отличается, перезаписываем..."
      if [[ "$DRY_RUN" == false ]]; then
        sed -i "${PREV_LINE_NUM}s|.*|$COMMENT|" "$FSTAB_FILE"
      fi
    else
      log_info "Комментарий соответствует, менять не нужно"
    fi
  else
    log_info "Запись отсутствует, добавляю комментарий и запись"
    if [[ "$DRY_RUN" == false ]]; then
      {
        echo
        echo "$COMMENT"
        echo "$ENTRY"
      } >>"$FSTAB_FILE"
    fi
  fi
}

# Функция для применения изменений fstab
apply_fstab() {
  if [[ "$DRY_RUN" == false ]]; then
    systemctl daemon-reload
    mount -a
  else
    log_info "[dry-run] systemctl daemon-reload и mount -a пропущены."
  fi
}

# Функция для создания символической ссылки
create_symlink() {
  if [[ "$CREATE_SYMLINK" == true ]]; then
    if [[ ! -L "$LINK" ]]; then
      log_info "Создаём симлинк: $LINK -> $MOUNT_POINT"
      if [[ "$DRY_RUN" == false ]]; then
        ln -s "$MOUNT_POINT" "$LINK"
        chown -h "$USER_NAME:$USER_NAME" "$LINK"
      fi
    else
      log_info "Симлинк уже существует: $LINK"
    fi
  fi
}

# Функция для отправки уведомления
notify_user() {
  MSG="$LABEL доступен в $MOUNT_POINT"
  [[ "$CREATE_SYMLINK" == true ]] && MSG="$MSG (симлинк: $LINK)"

  if [[ "$DRY_RUN" == false ]]; then
    sudo -u "$USER_NAME" \
      DISPLAY=:0 \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_UID/bus" \
      notify-send \
      -i drive-harddisk-usb \
      "USB диск настроен" \
      "$MSG"
  else
    log_info "[dry-run] notify-send пропущен: $MSG"
  fi
}

# Основная логика скрипта
main() {
  parse_args "$@"
  check_root
  find_device
  update_fstab
  apply_fstab
  create_symlink
  notify_user
}

main "$@"