#!/usr/bin/env bash
set -euo pipefail

replace_line_regex() {
  local file backup=1 regex newline

  show_help() {
    cat <<'EOF'
Usage:
  replace_line_regex [OPTIONS] REGEX NEW_LINE

Options:
  -f, --file FILE     Target file (required)
  -n, --no-backup     Do not create .bak file
  -h, --help          Show help

Description:
  Replaces the ENTIRE line if REGEX matches.
  REGEX is POSIX ERE.
EOF
  }

  while [ $# -gt 0 ]; do
    case "$1" in
    -f | --file)
      file="$2"
      shift 2
      ;;
    -n | --no-backup)
      backup=0
      shift
      ;;
    -h | --help)
      show_help
      return 0
      ;;
    --)
      shift
      break
      ;;
    *) break ;;
    esac
  done

  [ $# -eq 2 ] || {
    echo "error: REGEX and NEW_LINE required" >&2
    return 1
  }
  [ -n "${file:-}" ] || {
    echo "error: --file is required" >&2
    return 2
  }
  [ -f "$file" ] || {
    echo "error: file not found: $file" >&2
    return 3
  }

  regex="$1"
  newline="$2"

  if [ "$backup" -eq 1 ]; then
    sed -E -i.bak "/$regex/c\\$newline" "$file"
  else
    sed -E -i "/$regex/c\\$newline" "$file"
  fi
}

replace_regex() {
  local file backup=1 regex replacement flags="g"

  show_help() {
    cat <<'EOF'
Usage:
  replace_regex [OPTIONS] REGEX REPLACEMENT

Options:
  -f, --file FILE     Target file (required)
  -n, --no-backup     Do not create .bak file
  -1                  Replace only first match per line
  -h, --help          Show help

Description:
  Performs regex substitution using POSIX ERE.
  Supports capture groups (\1, \2, ...).
EOF
  }

  while [ $# -gt 0 ]; do
    case "$1" in
    -f | --file)
      file="$2"
      shift 2
      ;;
    -n | --no-backup)
      backup=0
      shift
      ;;
    -1)
      flags=""
      shift
      ;;
    -h | --help)
      show_help
      return 0
      ;;
    --)
      shift
      break
      ;;
    *) break ;;
    esac
  done

  [ $# -eq 2 ] || {
    echo "error: REGEX and REPLACEMENT required" >&2
    return 1
  }
  [ -n "${file:-}" ] || {
    echo "error: --file is required" >&2
    return 2
  }
  [ -f "$file" ] || {
    echo "error: file not found: $file" >&2
    return 3
  }

  regex="$1"
  replacement="$2"

  if [ "$backup" -eq 1 ]; then
    sed -E -i.bak "s|$regex|$replacement|$flags" "$file"
  else
    sed -E -i "s|$regex|$replacement|$flags" "$file"
  fi
}

picom_conf_file="$HOME/.config/bspwm/config/picom/picom.conf"
picom_animations_file="$HOME/.config/bspwm/config/picom/picom-animations.conf"

# --- Shadows ---
replace_regex -f "$picom_conf_file" \
  '^shadow\s*=.*' \
  "shadow = ${PICOM_SHADOW_SWITCH}"

replace_regex -f "$picom_conf_file" \
  '^shadow-color\s*=.*' \
  "shadow-color = \"${PICOM_SHADOW_COLOR}\""

# --- Fading ---
replace_regex -f "$picom_conf_file" \
  '^fading\s*=.*' \
  "fading = ${PICOM_FADING_SWITCH}"

# --- Opacity ---
replace_regex -f "$picom_conf_file" \
  '^active-opacity\s*=.*' \
  "active-opacity = ${PICOM_ACTIVE_OPACITY}"

replace_regex -f "$picom_conf_file" \
  '^inactive-opacity\s*=.*' \
  "inactive-opacity = ${PICOM_INACTIVE_OPACITY}"

replace_regex -f "$picom_conf_file" \
  '^frame-opacity\s*=.*' \
  "frame-opacity = ${PICOM_FRAME_OPACITY}"

# --- Geometry ---
replace_regex -f "$picom_conf_file" \
  '^corner-radius\s*=.*' \
  "corner-radius = ${PICOM_CORNER_RADIUS}"

# --- Blur ---
replace_regex -f "$picom_conf_file" \
  '^blur-background\s*=.*' \
  "blur-background = ${PICOM_BLUR_SWITCH}"

replace_regex -f "$picom_conf_file" \
  '^blur-method\s*=.*' \
  "blur-method = \"${PICOM_BLUR_METHOD}\""

replace_regex -f "$picom_conf_file" \
  '^blur-size\s*=.*' \
  "blur-size = ${PICOM_BLUR_SIZE}"

replace_regex -f "$picom_conf_file" \
  '^deviation\s*=.*' \
  "deviation = ${PICOM_BLUR_DEVIATION}"

replace_regex -f "$picom_conf_file" \
  '^blur-strength\s*=.*' \
  "blur-strength = ${PICOM_BLUR_STRENGTH}"

# --- Animations include ---
replace_line_regex -f "$picom_conf_file" \
  'picom-animations' \
  "${PICOM_ANIMATIONS_SWITCH}include \"picom-animations.conf\""
