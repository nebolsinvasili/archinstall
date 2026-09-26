#!/usr/bin/env bash
#############################
#		Emilia Theme		#
#############################
# Copyright (C) 2021-2025 gh0stzk <z0mbi3.zk@protonmail.com>
# https://github.com/gh0stzk/dotfiles

export LC_NUMERIC=C

# ============================================================
# General colorscheme
# ============================================================

background="#1d1d1d"
foreground="#deddda"

selection_background="#303030"
selection_foreground="#c0bfbc"

accent_color="#222330"
arch_icon="#0f94d2"

# =========================================
# Adwaita Dark Unified Theme (with alpha)
# =========================================

# Base
BG_HEX="#1d1d1d"
FG_HEX="#deddda"

SEL_BG_HEX="#303030"
SEL_FG_HEX="#c0bfbc"

URL_HEX="#1a5fb4"

# ANSI palette
BLACK="$BG_HEX"
RED="#ed333b"
GREEN="#57e389"
YELLOW="#ff7800"
BLUE="#62a0ea"
MAGENTA="#9141ac"
CYAN="#5bc8af"
WHITE="$FG_HEX"

BLACK_B="#9a9996"
RED_B="#f66151"
GREEN_B="#8ff0a4"
YELLOW_B="#ffa348"
BLUE_B="#99c1f1"
MAGENTA_B="#dc8add"
CYAN_B="#93ddc2"
WHITE_B="#f6f5f4"

# UI
BORDER_ACTIVE="#282828"
BORDER_INACTIVE="$background"
URGENT="#ed333b"

# Alpha
ALPHA_BG=0.88
ALPHA_FG=1.0
ALPHA_POPUP=0.94
ALPHA_BORDER=0.9

# RGBA helpers
rgba() {
  hex=${1#"#"}
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  printf "rgba(%d,%d,%d,%.2f)" "$r" "$g" "$b" "$2"
}

BG_RGBA=$(rgba "$BG_HEX" "$ALPHA_BG")
FG_RGBA=$(rgba "$FG_HEX" "$ALPHA_FG")
POPUP_RGBA=$(rgba "$BG_HEX" "$ALPHA_POPUP")
BORDER_RGBA=$(rgba "$BORDER_ACTIVE" "$ALPHA_BORDER")

# ============================================================
# Bspwm options
# ============================================================

BSPWM_WINDOW_GAP="6"

BSPWM_TOP_PADDING="0"
BSPWM_BOTTOM_PADDING="0"
BSPWM_LEFT_PADDING="0"
BSPWM_RIGHT_PADDING="0"

BSPWM_BORDER_WIDTH="1"
BSPWM_NORMAL_BORDER_COLOR="$BORDER_INACTIVE"
BSPWM_ACTIVE_BORDER_COLOR="$BORDER_INACTIVE"
BSPWM_FOCUSED_BORDER_COLOR="$BORDER_ACTIVE"
BSPWM_PRESEL_BORDER_COLOR="$BORDER_INACTIVE"

BSPWM_SPLIT_RATIO="0.50"

BSPWM_AUTOMATIC_SCHEME="longest_side"
BSPWM_INITIAL_POLARITY="second_child"

# ============================================================
# Picom options
# ============================================================

PICOM_SHADOW_SWITCH="true"
PICOM_SHADOW_COLOR="$background"

PICOM_FADING_SWITCH="true"

PICOM_ACTIVE_OPACITY="0.95"
PICOM_INACTIVE_OPACITY="0.95"
PICOM_FRAME_OPACITY="0.95"

PICOM_CORNER_RADIUS="12"

PICOM_BLUR_SWITCH="true"
PICOM_BLUR_METHOD="dual_kawase"
PICOM_BLUR_SIZE="1"
PICOM_BLUR_DEVIATION="10"
PICOM_BLUR_STRENGTH="1"

PICOM_ANIMATIONS_SWITCH="@" # (@ = enable) (# = disable)

# Terminal font & size
term_font_size="10"
term_font_name="JetBrainsMono Nerd Font"

# Dunst
dunst_offset='(20, 60)'
dunst_origin='top-right'
dunst_transparency='0'
dunst_corner_radius='6'
dunst_font='JetBrainsMono NF Medium 9'
dunst_border='0'
dunst_frame_color="$accent_color"
dunst_icon_theme="WhiteSur-dark"
# Dunst animations
dunst_close_preset="fly-out"
dunst_close_direction="up"
dunst_open_preset="fly-in"
dunst_open_direction="up"

# Rofi menu font and colors
rofi_font="JetBrainsMono NF Bold 9"
rofi_background="$background"
rofi_bg_alt="$accent_color"
rofi_background_alt="${background}E0"
rofi_fg="$foreground"

rofi_selected="$foreground"
rofi_active="$GREEN"
rofi_urgent="$RED"

# Screenlocker
sl_bg="${background}"
sl_fg="${foreground}"
sl_ring="${BLACK}"
sl_wrong="${RED}"
sl_date="${foreground}"
sl_verify="${GREEN}"

# Gtk theme
gtk_theme="WhiteSur-Dark"
gtk_icons="WhiteSur-dark"
gtk_cursor="Qogir-cursors"
gtk_cursor_size="16"
geany_theme="z0mbi3-TokyoNight"

# Wallpaper engine
# Available engines:
# - Random  (Set a random wallpaper from Walls rice directory)
# - CustomDir   (Set a random wallpaper from the directory you specified)
# - Default (Sets a specific image as wallpaper) *Default
# - Animated (Set an animated wallpaper. "mp4, mkv, gif")
# - Slideshow (Change randomly every 15 minutes your wallpaper from Walls rice directory)
ENGINE="Default"

CUSTOM_DIR="/path/to/your/wallpapers/directory"
DEFAULT_WALL="/home/nebolsinvasili/.config/bspwm/rices/work/wallpapers/lw5hznq0oaj91.png"
ANIMATED_WALL="$HOME/.config/bspwm/config/assets/animated_wall.mp4"
