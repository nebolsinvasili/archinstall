#!/usr/bin/env bash

set -euo pipefail

bspc config window_gap              ${BSPWM_WINDOW_GAP}

bspc config top_padding             ${BSPWM_TOP_PADDING}
bspc config bottom_padding          ${BSPWM_BOTTOM_PADDING}
bspc config left_padding            ${BSPWM_LEFT_PADDING}
bspc config right_padding           ${BSPWM_RIGHT_PADDING}

bspc config border_width            ${BSPWM_BORDER_WIDTH}
bspc config normal_border_color     "${BSPWM_NORMAL_BORDER_COLOR}"
bspc config active_border_color     "${BSPWM_ACTIVE_BORDER_COLOR}"
bspc config focused_border_color    "${BSPWM_FOCUSED_BORDER_COLOR}"
bspc config presel_feedback_color   "${BSPWM_PRESEL_BORDER_COLOR}"

bspc config split_ratio             ${BSPWM_SPLIT_RATIO}

bspc config automatic_scheme        "${BSPWM_AUTOMATIC_SCHEME}"
bspc config initial_polarity        "${BSPWM_INITIAL_POLARITY}"
