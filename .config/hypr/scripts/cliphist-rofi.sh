#!/usr/bin/env bash

# ~/.config/hypr/scripts/cliphist-rofi.sh
# Advanced Clipboard Manager with Shortcuts, Action Menus, and Rich Previews (Image & Text).

tmp_dir="/tmp/cliphist-$USER"
mkdir -p "$tmp_dir"

# Logger to help verify activity
echo "$(date): Script called" >> "$tmp_dir/log.txt"

function preview_entry() {
    local selection=$1
    local id
    id=$(echo "$selection" | cut -f1)
    
    if [[ "$selection" == *"[[ binary data"* ]]; then
        # IMAGE PREVIEW
        local img_path="$tmp_dir/$id-full.png"
        cliphist decode "$id" > "$img_path"
        hyprctl dispatch exec "[float;size 70% 70%;center] kitty --title 'Clipboard Preview' -e bash -c 'kitty +kitten icat --align center \"$img_path\"; echo -e \"\n\n  [Preview] Press Enter to close...\"; read'"
    else
        # TEXT PREVIEW
        local txt_path="$tmp_dir/$id.txt"
        cliphist decode "$id" > "$txt_path"
        # Use bat for syntax highlighting and nice formatting
        hyprctl dispatch exec "[float;size 70% 70%;center] kitty --title 'Clipboard Preview' -e bash -c 'bat --color=always --style=full \"$txt_path\"; echo -e \"\n\n  [Preview] Press Enter to close...\"; read'"
    fi
    
    # Wait for the window to actually open (avoid race conditions)
    sleep 0.4
    
    # Wait for the window to be closed before returning to Rofi
    while hyprctl clients -j | jq -e ".[] | select(.title == \"Clipboard Preview\")" >/dev/null 2>&1; do
        sleep 0.2
    done
    
    # Cleanup temp files
    rm -f "$tmp_dir/$id"*
}

function copy_entry() {
    local id=$1
    cliphist decode "$id" | wl-copy
}

function delete_entry() {
    local selection=$1
    cliphist delete <<< "$selection"
}

# Main Loop: Allows "Go Back" functionality and persistence
while true; do
    # 1. Main Selection Menu
    # Custom keys: Alt+P (10), Alt+C (11), Alt+D (12)
    selection=$(cliphist list | head -n 100 | while read -r line; do
        id=$(echo "$line" | cut -f1)
        if [[ "$line" == *"[[ binary data"* ]]; then
            icon="$tmp_dir/$id.png"
            if [ ! -f "$icon" ]; then
                cliphist decode "$id" > "$icon"
                if command -v magick >/dev/null; then
                    magick "$icon" -thumbnail 64x64^ -gravity center -extent 64x64 "$icon"
                elif command -v convert >/dev/null; then
                    convert "$icon" -thumbnail 64x64^ -gravity center -extent 64x64 "$icon"
                fi
            fi
            echo -en "$line\0icon\x1f$icon\n"
        else
            echo -en "$line\n"
        fi
    done | rofi -dmenu -p "Clipboard [Alt+P] Preview [Alt+C] Copy" -i -show-icons \
        -kb-custom-1 "Alt+p" \
        -kb-custom-2 "Alt+c" \
        -kb-custom-3 "Alt+d")
    
    exit_code=$?
    
    # If Rofi was closed or nothing selected
    [ -z "$selection" ] && exit
    
    id=$(echo "$selection" | cut -f1)
    
    # Handle Custom Shortcuts (Work for both text and images)
    if [ $exit_code -eq 10 ]; then # Alt+P: Instant Preview
        preview_entry "$selection"
        continue
    elif [ $exit_code -eq 11 ]; then # Alt+C: Instant Copy
        copy_entry "$id"
        exit
    elif [ $exit_code -eq 12 ]; then # Alt+D: Instant Delete
        delete_entry "$selection"
        continue
    fi
    
    # Handle Standard Selection (Enter)
    if [[ "$selection" == *"[[ binary data"* ]]; then
        # Action Menu for images
        while true; do
            action=$(echo -e "󰌌 Go Back\n󰆏 Copy to Clipboard\n󰈈 View Full Preview\n󰆴 Delete from History" | rofi -dmenu -p "Action Menu" -i -show-icons)
            
            case "$action" in
                *"Go Back"*) break ;; 
                *"Copy"*)
                    copy_entry "$id"
                    exit
                    ;;
                *"View"*)
                    preview_entry "$selection"
                    ;;
                *"Delete"*)
                    delete_entry "$selection"
                    break
                    ;;
                "") break ;;
            esac
        done
    else
        # Text copies immediately for maximum speed
        copy_entry "$id"
        exit
    fi
done
