#!/usr/bin/env bash
# ~/.config/hypr/scripts/powermenu.sh
# Bespoke Sanctuary / takt Industrial Session & Power Menu

options="󰌾  01 // LOCK\n󰤄  02 // SUSPEND\n󰍃  03 // LOGOUT\n󰜉  04 // REBOOT\n󰐥  05 // SHUTDOWN"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "SESSION //" -theme-str 'window { width: 340px; } listview { lines: 5; }')

case "$chosen" in
    *"LOCK"*)
        hyprlock
        ;;
    *"SUSPEND"*)
        hyprlock &
        sleep 0.5
        systemctl suspend
        ;;
    *"LOGOUT"*)
        if command -v uwsm >/dev/null 2>&1; then
            uwsm stop
        else
            hyprctl dispatch exit
        fi
        ;;
    *"REBOOT"*)
        systemctl reboot
        ;;
    *"SHUTDOWN"*)
        systemctl poweroff
        ;;
esac
