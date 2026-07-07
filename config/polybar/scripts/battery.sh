#!/usr/bin/env bash

# Path: ~/.config/polybar/scripts/battery.sh

LOW_BATTERY=30
FULL_BATTERY=100

# AUTOMATICALLY DETECT CORRECT BATTERY PATH (BAT0, BAT1, etc.)
BAT_DIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

# Safety exit if your system has no battery directory detected
if [ -z "$BAT_DIR" ] || [ ! -d "$BAT_DIR" ]; then
    echo " No Bat"
    exit 1
fi

# Fix Dunst/D-Bus environment variables
export DISPLAY=${DISPLAY:-:0}
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

BATTERY_STATUS=$(cat "$BAT_DIR/status")
BATTERY_LEVEL=$(cat "$BAT_DIR/capacity")

# Lockfiles to prevent notification spam due to 1s interval
LOW_LOCK="/tmp/bat_low.lock"
FULL_LOCK="/tmp/bat_full.lock"

# Handle low battery state (triggers at 30%)
if [ "$BATTERY_LEVEL" -le "$LOW_BATTERY" ] && [ "$BATTERY_STATUS" = "Discharging" ]; then
    if [ ! -f "$LOW_LOCK" ]; then
        notify-send -u critical -i battery-low "Battery Low" "battery low please charge"
        touch "$LOW_LOCK"
    fi
else
    rm -f "$LOW_LOCK"
fi

# Handle full battery state
if [ "$BATTERY_LEVEL" -eq "$FULL_BATTERY" ] && [ "$BATTERY_STATUS" = "Charging" ]; then
    if [ ! -f "$FULL_LOCK" ]; then
        notify-send -u normal -i battery-full "Battery Charged" "Battery is fully charged. Please unplug."
        touch "$FULL_LOCK"
    fi
else
    rm -f "$FULL_LOCK"
fi

# Nord Color Formatting tags for Polybar
RED_START="%{F#BF616A}"   # Nord11 Aurora Red
GREEN_START="%{F#A3BE8C}" # Nord14 Aurora Green
COLOR_RESET="%{F-}"

# Define icons and handle states
if [ "$BATTERY_STATUS" = "Charging" ]; then
    # Static charging icon
    ICON=""
    # ENTIRE MODULE GREEN (Icon and Percentage Text)
    echo "${GREEN_START}${ICON} ${BATTERY_LEVEL}%${COLOR_RESET}"
else
    # Discharging states
    if [ "$BATTERY_LEVEL" -le 10 ]; then
        # 10% and below: ENTIRE MODULE RED + ICON BLINKING
        FRAME_FILE="/tmp/polybar_bat_crit_frame"
        [ ! -f "$FRAME_FILE" ] && echo 0 > "$FRAME_FILE"
        FRAME=$(cat "$FRAME_FILE")

        FRAMES=("  " " ")
        ICON="${FRAMES[$FRAME]}"

        NEXT_FRAME=$(( (FRAME + 1) % 2 ))
        echo "$NEXT_FRAME" > "$FRAME_FILE"
        
        echo "${RED_START}${ICON} ${BATTERY_LEVEL}%${COLOR_RESET}"

    elif [ "$BATTERY_LEVEL" -le 20 ]; then
        # 20% and below: ENTIRE MODULE SOLID RED
        ICON="  "
        echo "${RED_START}${ICON} ${BATTERY_LEVEL}%${COLOR_RESET}"

    elif [ "$BATTERY_LEVEL" -le "$LOW_BATTERY" ]; then
        # 21% to 30%: Standard behavior low icon (No special color, no blink)
        ICON="  "
        echo "$ICON $BATTERY_LEVEL%"

    else
        # Normal battery levels
        if [ "$BATTERY_LEVEL" -ge 90 ]; then ICON="";
        elif [ "$BATTERY_LEVEL" -ge 65 ]; then ICON="";
        elif [ "$BATTERY_LEVEL" -ge 40 ]; then ICON="";
        else ICON="";
        fi
        echo "$ICON $BATTERY_LEVEL%"
    fi
fi
