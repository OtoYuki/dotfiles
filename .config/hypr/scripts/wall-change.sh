#!/bin/bash

# Your wallpaper directory
DIR="$HOME/pictures/wallpapers"

# File to store the currently active wallpaper
STATE_FILE="$HOME/.cache/awww_current_wall"

# Get a sorted list of all files in the directory
shopt -s nullglob
FILES=("$DIR"/*)

# Exit if no wallpapers are found
if [ ${#FILES[@]} -eq 0 ]; then
    exit 1
fi

# Read the last used wallpaper from the state file
CURRENT_PIC=""
if [ -f "$STATE_FILE" ]; then
    CURRENT_PIC=$(cat "$STATE_FILE")
fi

# Find the index of the current wallpaper, then calculate the next one
NEXT_INDEX=0
for i in "${!FILES[@]}"; do
    if [[ "${FILES[$i]}" == "$CURRENT_PIC" ]]; then
        # If we found the current one, the next index is i + 1
        # The modulo (%) makes it loop back to 0 when it hits the end
        NEXT_INDEX=$(( (i + 1) % ${#FILES[@]} ))
        break
    fi
done

# The chosen wallpaper
NEXT_PIC="${FILES[$NEXT_INDEX]}"

# Save it to the state file for next time
echo "$NEXT_PIC" > "$STATE_FILE"

# Set the new wallpaper with a transition
awww img "$NEXT_PIC" \
    --transition-type outer \
    --transition-pos 0.5,0.5 \
    --transition-duration 0.8 \
    --transition-fps 165