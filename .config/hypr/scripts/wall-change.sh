#!/bin/bash
# ~/.config/hypr/scripts/wall-change.sh
# Dynamic Wallpaper & Sanctuary Theme Switcher

DIR="$HOME/Pictures/wallpapers"
STATE_FILE="$HOME/.cache/awww_current_wall"
SCHEMES_DIR="$HOME/.config/wallust/colorschemes"

# Allow passing a specific image as $1, or cycle through DIR
if [ -n "$1" ] && [ -f "$1" ]; then
    NEXT_PIC="$1"
else
    shopt -s nullglob
    FILES=("$DIR"/*)
    if [ ${#FILES[@]} -eq 0 ]; then
        exit 1
    fi

    CURRENT_PIC=""
    if [ -f "$STATE_FILE" ]; then
        CURRENT_PIC=$(cat "$STATE_FILE")
    fi

    NEXT_INDEX=0
    for i in "${!FILES[@]}"; do
        if [[ "${FILES[$i]}" == "$CURRENT_PIC" ]]; then
            NEXT_INDEX=$(( (i + 1) % ${#FILES[@]} ))
            break
        fi
    done
    NEXT_PIC="${FILES[$NEXT_INDEX]}"
fi

# Save state
echo "$NEXT_PIC" > "$STATE_FILE"

# Apply wallpaper with high-refresh smooth transition
if command -v awww >/dev/null 2>&1; then
    awww img "$NEXT_PIC" \
        --transition-type outer \
        --transition-pos 0.5,0.5 \
        --transition-duration 0.8 \
        --transition-fps 165
fi

# Determine theme: Check for pinned scheme matching image basename
BG_NAME=$(basename "$NEXT_PIC")
BG_STEM="${BG_NAME%.*}"

if [ -f "$SCHEMES_DIR/${BG_STEM}.json" ]; then
    # Pinned Handcrafted Colorscheme (e.g. sanctuary)
    wallust cs "$BG_STEM" -q
else
    # Dynamic Algorithmic Extraction
    wallust run "$NEXT_PIC" -q
fi

# Live reload components
# 1. Hyprland borders & decoration
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 &
fi

# 2. Waybar CSS reload
killall -SIGUSR2 waybar >/dev/null 2>&1 || true

# 3. Kitty reload configuration on the fly
killall -SIGUSR1 kitty >/dev/null 2>&1 || true

exit 0