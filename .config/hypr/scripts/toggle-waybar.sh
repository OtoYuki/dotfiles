#!/bin/bash
# ~/.config/hypr/scripts/toggle-waybar.sh
# Bulletproof Waybar Toggle

if pgrep -x waybar >/dev/null 2>&1; then
    killall -q waybar
else
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch 'hl.dsp.exec_cmd("waybar")' >/dev/null 2>&1 || waybar >/dev/null 2>&1 &
    else
        waybar >/dev/null 2>&1 &
    fi
fi
