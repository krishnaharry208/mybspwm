#!/usr/bin/env bash

# Define paths explicitly to match your layout strategy
SCRIPT_PATH="$HOME/.config/polybar/scripts/bluetooth.sh"
THEME_PATH="$HOME/.config/polybar/rofi/wifi.rasi"

# --- HELPER FUNCTIONS ---
notify() {
    if command -v notify-send &>/dev/null; then
        notify-send -i bluetooth "Bluetooth Manager" "$1"
    else
        echo "[Bluetooth] $1"
    fi
}

is_powered() {
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
}

is_connected() {
    local mac="$1"
    bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"
}

# --- DEVICE ACTIONS ---
toggle_power() {
    if is_powered; then
        bluetoothctl power off &>/dev/null
        notify "Bluetooth Turned OFF"
    else
        bluetoothctl power on &>/dev/null
        notify "Bluetooth Turned ON"
    fi
}

disconnect_all() {
    notify "Disconnecting all active connections..."
    # Explicit loop queries global addresses directly to bypass buggy helper properties
    bluetoothctl devices 2>/dev/null | while read -r _ mac _; do
        if is_connected "$mac"; then
            bluetoothctl disconnect "$mac" &>/dev/null
        fi
    done
    sleep 1
}

pair_new_device() {
    notify "Scanning for available devices (5s)..."
    
    bluetoothctl power on &>/dev/null
    bluetoothctl agent on &>/dev/null
    bluetoothctl default-agent &>/dev/null
    
    # Start background controller hardware scan safely
    bluetoothctl scan on &>/dev/null &
    local scan_pid=$!
    
    sleep 5
    kill $scan_pid &>/dev/null
    bluetoothctl scan off &>/dev/null
    
    # Grabs all visible neighborhood targets cleanly 
    local devices
    devices=$(bluetoothctl devices 2>/dev/null | grep -v "^$" || true)
    
    if [ -z "$devices" ]; then
        notify "No available devices found."
        return
    fi

    local selection
    selection=$(echo -e "$devices" | rofi -dmenu -i -p "    Available Devices:" -theme "$THEME_PATH") || return
    [ -z "$selection" ] && return

    local mac name
    mac=$(echo "$selection" | awk '{print $2}')
    name=$(echo "$selection" | cut -d' ' -f3-)

    if [ -z "$mac" ]; then
        notify "Invalid selection."
        return
    fi

    notify "Pairing with $name..."
    bluetoothctl trust "$mac" &>/dev/null
    
    if bluetoothctl pair "$mac" &>/dev/null; then
        notify "Paired with $name"
        if bluetoothctl connect "$mac" &>/dev/null; then
            notify "Connected to $name"
        fi
    else
        notify "Failed to pair with $name"
    fi
}

# --- MENU BUILDING ---
build_menu() {
    local power_status="OFF"
    local paired_devices=""

    if is_powered; then
        power_status="ON"
        
        # Bypasses the broken 'paired-devices' command by processing the global list accurately
        while read -r _ mac name; do
            [ -z "$mac" ] && continue
            
            # Verify if the device is a trusted/paired device by scanning its info layout
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
                if is_connected "$mac"; then
                    paired_devices+="    ● Connected    ::: $name [$mac]\n"
                else
                    paired_devices+="    ○ Disconnected ::: $name [$mac]\n"
                fi
            fi
        done < <(bluetoothctl devices 2>/dev/null)
    fi

    # Printf outputs clean system-level newlines to keep lines isolated inside Rofi
    printf "    Toggle Power (Currently: %s)\n    Scan & Pair New Device" "$power_status"
    
    if [ "$power_status" = "ON" ]; then
        printf "\n    Disconnect ALL Devices"
        if [ -n "$paired_devices" ]; then
            printf "\n%b" "$paired_devices"
        fi
    fi
}

handle_selection() {
    local selection="$1"
    
    case "$selection" in
        *"Toggle Power"*)
            toggle_power
            return 0
            ;;
        *"Scan & Pair"*)
            pair_new_device
            return 0
            ;;
        *"Disconnect ALL Devices"*)
            disconnect_all
            return 0
            ;;
        *"● Connected"*)
            local mac
            mac=$(echo "$selection" | grep -oE '[0-9A-Fa-f:]{17}')
            if [ -n "$mac" ]; then
                bluetoothctl disconnect "$mac" &>/dev/null && notify "Disconnected device $mac"
            fi
            return 0
            ;;
        *"○ Disconnected"*)
            local mac
            mac=$(echo "$selection" | grep -oE '[0-9A-Fa-f:]{17}')
            if [ -n "$mac" ]; then
                notify "Connecting to device..."
                bluetoothctl agent on &>/dev/null
                if bluetoothctl connect "$mac" &>/dev/null; then
                    notify "Successfully connected!"
                else
                    notify "Connection attempt failed."
                fi
            fi
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# --- MAIN LOOP ---
main() {
    while true; do
        local menu_items selection status
        menu_items=$(build_menu)
        
        # Explicit placeholder string passed to match inputbar children logic inside wifi.rasi
        selection=$(echo -e "$menu_items" | rofi -dmenu -i -p "    Bluetooth Center:" -theme "$THEME_PATH")
        
        [ -z "$selection" ] && break
        
        handle_selection "$selection"
        status=$?
        
        # Stop execution instantly if user selection dismisses menu framework
        [ $status -ne 0 ] && break
        
        sleep 0.3
    done
}

main
