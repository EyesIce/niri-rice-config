#!/bin/bash
# Emits HH:MM as pango markup: hours in the wallpaper colour, minutes lighter.
source ~/.config/hypr/wallpaper/colors.env 2>/dev/null
H="${COL_HOUR:-#dddddd}"
M="${COL_MIN:-#f0f0f0}"
printf '<span foreground="%s">%s:</span><span foreground="%s">%s</span>\n' \
    "$H" "$(date +%H)" "$M" "$(date +%M)"
