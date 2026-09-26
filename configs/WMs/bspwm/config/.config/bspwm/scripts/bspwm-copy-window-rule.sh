#!/bin/bash

# --- Клик по окну для выбора ---
echo "Нажмите на окно, для которого хотите создать правило..."
xid=$(xwininfo -int | awk '/Window id:/ {print $4; exit}')
[ -z "$xid" ] && {
  echo "Окно не выбрано"
  exit 1
}

TAB="$(printf '\t')"

# --- helper functions ---
mark() {
  sel="$1"
  shift
  out=""
  for v in "$@"; do
    [ "$v" = "$sel" ] && out="${out}*${v}" || out="${out}${v}"
    out="${out} | "
  done
  printf '%s' "${out% | }"
}

emit() {
  key="$1"
  value="$2"
  desc="$3"
  shift 3
  [ -z "$value" ] && return
  values="$(mark "$value" "$@")"
  printf '%s=%s%s# %s%s%s%s%s\n' \
    "$key" "$value" "$TAB" \
    "$key" "$TAB" "$desc" "$TAB" "$values"
}

# --- parsed data через xprop и xwininfo ---
class=$(xprop -id "$xid" WM_CLASS | awk -F'"' '{print $4}')
layer="normal"                      # можно подставить по умолчанию
sticky="false"                      # по умолчанию
desktop=$(bspc query -D -d focused) # текущий рабочий стол
monitor=$(bspc query -M -m focused) # текущий монитор
transient=$(xprop -id "$xid" WM_TRANSIENT_FOR | awk '{print $3}')
transient=${transient:-0}

# --- rectangle через xwininfo ---
rectangle=$(xwininfo -id "$xid" | awk '
  /Width:/ {w=$2}
  /Height:/ {h=$2}
  /Absolute upper-left X:/ {x=$4}
  /Absolute upper-left Y:/ {y=$4}
  END {print w "x" h "+" x "+" y}
')

# --- rule logic ---
once="-o"
manage="on"

if [ "$transient" != "0" ]; then
  state="floating"
  follow="off"
  focus="off"
  center="on"
  sticky="true"
  tab=""
  private=""
else
  state="floating"
  follow="on"
  focus="on"
  center="off"
  tab="last"
  private="false"
fi

# --- generate bspc rule ---
{
  printf '# bspwm rule for %s\n' "$class"
  printf '# Generated from clicked window\n\n'
  printf 'bspc rule -a %s %s \\\n' "$class" "$once"

  emit state "$state" "режим окна" tiled floating fullscreen \\
  emit layer "$layer" "слой отображения" below normal above \\
  emit tab "$tab" "позиция вкладки в контейнере" first prev next last \\
  emit rectangle "$rectangle" "геометрия WxH+X+Y" "WxH+X+Y" \\
  emit monitor "$monitor" "целевой монитор" "$monitor" \\
  emit desktop "$desktop" "целевой рабочий стол" "$desktop" \\
  emit follow "$follow" "забирать фокус при появлении" on off \\
  emit focus "$focus" "можно ли фокусировать окно" on off \\
  emit center "$center" "центрировать окно" on off \\
  emit sticky "$sticky" "видно на всех рабочих столах" true false \\
  emit private "$private" "не сохранять состояние" true false \\
  emit manage "$manage" "управляется bspwm" on off

} | sed '$ s/ \\//' | xclip -selection clipboard

notify-send "bspwm rule copied" "$class"
