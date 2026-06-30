#!/bin/bash
# Emits the date as pango markup: weekday in the hour colour, the rest lighter.
#   e.g. "Tuesday, 30 June 2026"
source ~/.config/hypr/wallpaper/colors.env 2>/dev/null
H="${COL_HOUR:-#dddddd}"
M="${COL_MIN:-#f0f0f0}"
printf '<span foreground="%s">%s,</span> <span foreground="%s">%s</span>\n' \
    "$H" "$(date '+%A')" "$M" "$(date '+%d %B %Y')"
