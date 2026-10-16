#!/bin/bash
# ~/.config/hypr/scripts/toggle-takt.sh
# Bulletproof Takt Wayland Telemetry Deck Toggle

if pgrep -x takt >/dev/null 2>&1; then
    killall -q takt
else
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch "hl.dsp.exec_cmd(\"$(command -v takt || echo "$HOME/.local/bin/takt")\")" >/dev/null 2>&1 || takt >/dev/null 2>&1 &
    else
        takt >/dev/null 2>&1 &
    fi
fi
