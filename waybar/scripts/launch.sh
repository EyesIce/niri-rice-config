#!/bin/bash
if ! pgrep -x waybar > /dev/null; then
    waybar &
fi
while inotifywait -e close_write ~/.config/waybar; do
    killall -SIGUSR2 waybar
done
