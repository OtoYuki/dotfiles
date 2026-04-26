#!/usr/bin/env bash

# ~/.config/hypr/scripts/screenshot.sh
# Robust screenshot script for Hyprland that ensures saving to file and clipboard.

MODE=$1
SAVEDIR=$2

if [ -z "$MODE" ]; then
    echo "Usage: $0 [region|output|window] [output_dir]"
    exit 1
fi

# Fallback to default if directory not provided
if [ -z "$SAVEDIR" ]; then
    SAVEDIR="$HOME/Pictures/Screenshots"
fi

# Ensure directory exists
mkdir -p "$SAVEDIR"

# Use hyprshot for the actual capture logic.
# -s (silent) to suppress its default notification.
# We use the '--' flag to run a custom command after the screenshot is taken.
# hyprshot passes the absolute path of the saved file as the first argument to that command.
hyprshot -m "$MODE" -o "$SAVEDIR" -z -s -- bash -c '
    FILE_PATH="$1"
    # Copy to clipboard
    wl-copy --type image/png < "$FILE_PATH"
    
    # Send custom notification
    notify-send "Screenshot Captured" "Saved to $(basename "$FILE_PATH") and copied to clipboard." -i "$FILE_PATH" -a "Hyprshot"
' --
