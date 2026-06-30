#!/usr/bin/env bash
# ~/.config/waybar/scripts/network-selector.sh
# Wi-Fi picker — shown under waybar, includes per-network signal icons + wifi toggle

THEME="/home/teo/.config/rofi/network-selector.rasi"

# Signal dBm-percent → NF wifi-arc glyph (1–4 arcs)
sig_icon() {
    local s=$(( $1 + 0 ))
    if   (( s >= 75 )); then printf '󰤨'   # 4 arcs
    elif (( s >= 50 )); then printf '󰤥'   # 3 arcs
    elif (( s >= 25 )); then printf '󰤢'   # 2 arcs
    else                     printf '󰤟'   # 1 arc
    fi
}

# ── Current state ────────────────────────────────────────────
WIFI_ON=$(nmcli -t -f WIFI radio 2>/dev/null | head -1)
ACTIVE=$(nmcli -t -f NAME,TYPE con show --active 2>/dev/null \
         | awk -F: '$2 == "802-11-wireless" { print $1; exit }')

# ── Build item lists (parallel arrays) ──────────────────────
declare -a DISP   # display strings
declare -a META   # action keys
declare -a URGENT # indices for urgent (toggle) styling

idx=0

if [[ "$WIFI_ON" == "enabled" ]]; then
    declare -A seen
    while IFS= read -r rawline; do
        # nmcli -t escapes literal ':' as '\:'; replace before splitting
        _sep=$'\x01'
        line="${rawline//\\:/$_sep}"
        SSID=$(cut -d: -f1 <<< "$line" | tr "$_sep" ':')
        SIG=$( cut -d: -f2 <<< "$line")
        SEC=$( cut -d: -f3 <<< "$line")

        [[ -z "$SSID" || "$SSID" == "--" ]] && continue
        [[ -n "${seen[$SSID]}" ]] && continue
        seen["$SSID"]=1

        ICON=$(sig_icon "${SIG:-0}")
        # NF nf-md-lock (U+F033E) for secured, two spaces for open
        LOCK=$([[ -n "$SEC" && "$SEC" != "--" ]] && printf '\xF3\xB0\x8C\xBE ' || printf '  ')
        MARK=$([[ "$SSID" == "$ACTIVE" ]] && printf '✓ ' || printf '  ')

        DISP+=( "${MARK}${ICON}${LOCK}${SSID}" )
        META+=( "NET:${SSID}" )
        (( idx++ ))
    done < <(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan no 2>/dev/null \
             | sort -t: -k2 -rn)
fi

# WiFi toggle — always last, styled urgent so it visually stands apart
if [[ "$WIFI_ON" == "enabled" ]]; then
    DISP+=( "󰖪   Turn WiFi off" )
    META+=( "TOGGLE_OFF" )
else
    DISP+=( "󰖩   Turn WiFi on" )
    META+=( "TOGGLE_ON" )
fi
URGENT+=( "$idx" )

# ── Launch rofi ─────────────────────────────────────────────
# Header passed via -mesg pango markup (message widget = known rofi type, always renders)
# -format i  → 0-based index of selected item
# -u IDX     → mark toggle row urgent for visual distinction
MESG="<span font='JetBrainsMono NFM Bold 14'>󰖩  Wi-Fi Networks</span>"$'\n'"<span font='Inter Regular 11' foreground='#7a7a94'>  Select a network</span>"

SEL_IDX=$(
    printf '%s\n' "${DISP[@]}" \
    | rofi -dmenu \
           -theme          "$THEME" \
           -p              "" \
           -no-custom \
           -format         i \
           -mesg           "$MESG" \
           -u              "$(IFS=,; printf '%s' "${URGENT[*]}")"
)

# Empty or negative index = user pressed Esc
[[ -z "$SEL_IDX" || "$SEL_IDX" -lt 0 ]] 2>/dev/null && exit 0
[[ ! "$SEL_IDX" =~ ^[0-9]+$ ]] && exit 0

ACTION="${META[$SEL_IDX]}"

# ── Handle selection ─────────────────────────────────────────
case "$ACTION" in
    TOGGLE_OFF)
        nmcli radio wifi off
        ;;
    TOGGLE_ON)
        nmcli radio wifi on
        ;;
    NET:*)
        SSID="${ACTION#NET:}"
        # Use saved connection profile if one exists
        if nmcli -t -f NAME con show 2>/dev/null | grep -qxF "$SSID"; then
            if nmcli con up id "$SSID" &>/dev/null; then
                notify-send -i network-wireless "WiFi" "Connected to $SSID"
            else
                notify-send -i dialog-error "WiFi" "Failed to connect to $SSID"
            fi
        else
            # New network — prompt for password via rofi
            PASS=$(rofi -dmenu \
                       -theme    "$THEME" \
                       -p        "Password for \"$SSID\":" \
                       -password \
                       -lines    0)
            [[ -z "$PASS" ]] && exit 0
            if nmcli device wifi connect "$SSID" password "$PASS" &>/dev/null; then
                notify-send -i network-wireless "WiFi" "Connected to $SSID"
            else
                notify-send -i dialog-error "WiFi" "Failed to connect to $SSID"
            fi
        fi
        ;;
esac
