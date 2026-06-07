#!/bin/bash

killall -q polybar

while pgrep -u $UID -x polybar >/dev/null; do
    sleep 1
done

# Auto detect primary monitor
MONITOR=$(xrandr | grep " connected primary" | cut -d" " -f1)

# fallback
if [ -z "$MONITOR" ]; then
    MONITOR=$(xrandr | grep " connected" | head -n1 | cut -d" " -f1)
fi

echo "Using monitor: $MONITOR"

MONITOR=$MONITOR polybar main &
