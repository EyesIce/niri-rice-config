#!/usr/bin/env bash
# Keyboard-layout indicator + toggle for waybar. Works under both niri and
# Hyprland (waybar is shared between them). `get` prints JSON for the custom
# module; `toggle` cycles to the next configured layout and refreshes waybar.

short() {
    case "$1" in
        *Italian*|it|IT) echo "IT" ;;
        *US*|*English*|us) echo "US" ;;
        *) echo "${1:0:2}" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

have_niri() { command -v niri    >/dev/null && niri msg version   >/dev/null 2>&1; }
have_hypr() { command -v hyprctl >/dev/null && hyprctl version    >/dev/null 2>&1; }

get() {
    local name=""
    if have_niri; then
        name=$(niri msg --json keyboard-layouts | jq -r '.names[.current_idx]')
    elif have_hypr; then
        name=$(hyprctl -j devices | jq -r 'first(.keyboards[] | select(.main)) | .active_keymap')
    fi
    [ -z "$name" ] || [ "$name" = "null" ] && name="??"
    printf '{"text":"%s","tooltip":"Keyboard layout: %s\\nClick to switch"}\n' \
        "$(short "$name")" "$name"
}

toggle() {
    if have_niri; then
        niri msg action switch-layout next
    elif have_hypr; then
        local kbd
        kbd=$(hyprctl -j devices | jq -r 'first(.keyboards[] | select(.main)) | .name')
        hyprctl switchxkblayout "$kbd" next
    fi
    pkill -RTMIN+8 waybar 2>/dev/null  # instant module refresh
}

case "$1" in
    toggle) toggle ;;
    *)      get ;;
esac
