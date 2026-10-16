#!/bin/bash
# ~/.config/hypr/scripts/toggle-takt.sh
# Bulletproof Takt Wayland Telemetry Deck Toggle

if pgrep -x takt >/dev/null 2>&1; then
    killall -q takt
else
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch 'hl.dsp.exec_cmd("/home/s1re/.local/bin/takt")' >/dev/null 2>&1 || "$HOME/.local/bin/takt" >/dev/null 2>&1 &
    else
        "$HOME/.local/bin/takt" >/dev/null 2>&1 &
    fi
fi
