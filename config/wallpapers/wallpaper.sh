#!/bin/bash

# Configuration
WALL_DIR="$HOME/Pictures/wallpapers"
THEME_FILE="$HOME/.config/wallpapers/wallpaper.rasi"

# Check if wallpaper directory exists
if [ ! -d "$WALL_DIR" ]; then
    notify-send "Wallpaper Picker" "Error: Directory '$WALL_DIR' not found."
    exit 1
fi

# Build Rofi list: displays short names while passing hidden icon paths to the backend
selected_line=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | while read -r filepath; do
    # Strip path to keep the text label clean (e.g., "sunset.png")
    filename=$(basename "$filepath")
    
    # Rofi syntax: text-label\0icon\x1f/path/to/preview-image
    echo -en "$filename\0icon\x1f$filepath\n"
done | rofi -dmenu -theme "$THEME_FILE" -i -p "Wallpaper")

# Exit safely if the user escapes (ESC) or closes the menu
[ -z "$selected_line" ] && exit 0

# Reconstruct the absolute path to feed to feh
full_path="$WALL_DIR/$selected_line"

# Apply the wallpaper and save configuration for persistence
if [ -f "$full_path" ]; then
    feh --bg-fill "$full_path"
    
    # Optional: Send a desktop notification of the change
    notify-send "Wallpaper Changed" "Applied: $selected_line" -i "$full_path"
else
    notify-send "Wallpaper Picker" "Error: Could not apply selected image."
fi
