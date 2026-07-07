#!/usr/bin/env bash

# Set directories
ICON_DIR="$HOME/.config/polybar/icons"
THEME_FILE="$HOME/.config/polybar/rofi/powermenu.rasi"

# Build our choices with icons
shutdown="Shutdown\x00icon\x1f${ICON_DIR}/PowerOff.png"
reboot="Reboot\x00icon\x1f${ICON_DIR}/Reboot.png"
reload="Reload\x00icon\x1f${ICON_DIR}/reload.png"
logout="Logout\x00icon\x1f${ICON_DIR}/Logout.png"
lock="Lock\x00icon\x1f${ICON_DIR}/Lock.png"

# Send choices safely to Rofi (added $lock here)
chosen=$(printf "%b\n" "$shutdown" "$reboot" "$reload" "$logout" "$lock" | rofi -dmenu -i -p "Power Menu:" -theme "$THEME_FILE")

# Handle options
case "$chosen" in
    *Shutdown*)
        systemctl poweroff
        ;;
    *Reboot*)
        systemctl reboot
        ;;
    *Reload*)
        bspc wm -r
        pkill -USR1 -x sxhkd
        ;;
    *Logout*)
        bspc quit
        ;;
    *Lock*)
        i3lock -c 000000
        ;;
esac
