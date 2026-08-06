#!/usr/bin/env bash

if bluetoothctl show | grep -q "Powered: yes"; then
    if bluetoothctl info | grep -q "Connected: yes"; then
        DEVICE=$(bluetoothctl info | awk -F': ' '/Name/ {print $2; exit}')
        echo " $DEVICE"
    else
        echo " On"
    fi
else
    echo " Off"
fi