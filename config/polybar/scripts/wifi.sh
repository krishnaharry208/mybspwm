#!/usr/bin/env bash

# Function to safely send notifications
msg() {
    if type notify-send &>/dev/null && { dunstify -v &>/dev/null || pgrep -x "dunst" &>/dev/null || pgrep -x "mako" &>/dev/null || pgrep -x "xfce4-notifyd" &>/dev/null; }; then
        notify-send -i network-wireless "$1" "$2"
    else
        echo "[$1] $2"
    fi
}

# --- SCREEN 1: MAIN MENU ---
show_main_menu() {
    local wifi_state toggle current_net menu_options
    wifi_state=$(nmcli radio wifi)
    
    if [[ "$wifi_state" =~ "enabled" ]]; then
        toggle="󰖪  Disable Wi-Fi"
        # Get current active connection if any
        current_net=$(nmcli -t -f "ACTIVE,SSID" device wifi list | grep "^yes" | cut -d':' -f2)
        if [ -n "$current_net" ]; then
            status_str="󰄵  Connected to: $current_net"
        else
            status_str="󰤮  Disconnected"
        fi
    else
        toggle="󰖩  Enable Wi-Fi"
        status_str="󰖪  Wi-Fi is Off"
    fi

    # Build Menu
    menu_options="$status_str\n$toggle\n󰋚  Scan & Connect to Networks\n󱠢  Manage Saved Networks (Forget)"
    
    echo -e "$menu_options" | rofi -dmenu -i -p "󰖩  Wi-Fi Control Center:" -theme-str 'window {width: 450px;}'
}

# --- SCREEN 2: SCAN & CONNECT ---
scan_and_connect() {
    msg "Wi-Fi Manager" "Scanning for available networks..."
    
    local wifi_list chosen_network chosen_id saved_connections wifi_password success
    
    wifi_list=$(nmcli -t -f "IN-USE,SSID,SIGNAL,SECURITY" device wifi list | while IFS=: read -r in_use ssid signal security; do
        [ -z "$ssid" ] && continue
        
        if [[ "$security" =~ "WPA" || "$security" =~ "WEP" ]]; then icon=""; else icon=""; fi
        if [ "$signal" -ge 80 ]; then bars="󰤨"; elif [ "$signal" -ge 60 ]; then bars="󰤥"; elif [ "$signal" -ge 40 ]; then bars="󰤢"; else bars="󰤟"; fi

        if [ "$in_use" = "*" ]; then
            echo "󰄵  $ssid ::: ($bars $signal% $icon) [Connected]"
        else
            echo "$icon  $ssid ::: ($bars $signal%)"
        fi
    done | sort -u)

    chosen_network=$(echo -e "󰌪  Back to Main Menu\n$wifi_list" | rofi -dmenu -i -selected-row 1 -p "󰖩  Available Networks:" -theme-str 'window {width: 550px;}')
    
    [ -z "$chosen_network" ] && exit 0
    [ "$chosen_network" = "󰌪  Back to Main Menu" ] && exec "$0"

    # Extract exact SSID
    chosen_id=$(echo "$chosen_network" | sed -E 's/^[^[:space:]]+[[:space:]]+//; s/[[:space:]]*:::.*$//')
    saved_connections=$(nmcli -g NAME connection)

    if echo "$saved_connections" | grep -Fqx "$chosen_id"; then
        msg "Wi-Fi Manager" "Connecting to saved network: $chosen_id..."
        if nmcli connection up id "$chosen_id"; then
            msg "Connection Established" "Successfully connected to \"$chosen_id\"."
        else
            msg "Connection Failed" "Could not connect to profile \"$chosen_id\"."
        fi
    else
        # New Connection Setup loop (allows re-entry on incorrect password)
        while true; do
            if [[ "$chosen_network" =~ "" ]]; then
                wifi_password=$(rofi -dmenu -password -p "Enter Password for $chosen_id:" -theme-str 'window {width: 400px;}')
                [ -z "$wifi_password" ] && exit 0 
                
                msg "Wi-Fi Manager" "Authenticating with $chosen_id..."
                
                success=$(nmcli device wifi connect "$chosen_id" password "$wifi_password" 2>&1)
                
                if [[ "$success" =~ "successfully activated" ]]; then
                    msg "Connection Established" "Successfully connected to \"$chosen_id\"."
                    break
                else
                    notify-send -i dialog-error "Authentication Failed" "Incorrect password for \"$chosen_id\". Please try again."
                fi
            else
                msg "Wi-Fi Manager" "Connecting to open network: $chosen_id..."
                if nmcli device wifi connect "$chosen_id"; then
                    msg "Connection Established" "Successfully connected to \"$chosen_id\"."
                else
                    msg "Connection Failed" "Could not connect to open network."
                fi
                break
            fi
        done
    fi
}

# --- SCREEN 3: MANAGE / FORGET SAVED CONNECTIONS ---
manage_saved() {
    local saved_list chosen_del current_active wifi_interface
    # Get only Wireless type connections saved on the machine
    saved_list=$(nmcli -f NAME,TYPE connection show | grep "802-11-wireless" | awk -F'  +' '{print $1}')
    
    if [ -z "$saved_list" ]; then
        rofi -e "No saved Wi-Fi connections found."
        exec "$0"
    fi

    chosen_del=$(echo -e "󰌪  Back to Main Menu\n$saved_list" | rofi -dmenu -i -p "󱠢  Select Network to FORGET:" -theme-str 'window {width: 450px;}')
    
    [ -z "$chosen_del" ] && exit 0
    [ "$chosen_del" = "󰌪  Back to Main Menu" ] && exec "$0"

    # Confirm Deletion
    local confirm
    confirm=$(echo -e "No\nYes, Forget Network" | rofi -dmenu -i -p "Are you sure you want to delete $chosen_del?" -theme-str 'window {width: 400px;}')
    
    if [ "$confirm" = "Yes, Forget Network" ]; then
        # Check what network we are currently connected to right now
        current_active=$(nmcli -t -f "ACTIVE,SSID" device wifi list | grep "^yes" | cut -d':' -f2)
        
        # If the user is deleting the currently active network, disconnect first
        if [ "$chosen_del" = "$current_active" ]; then
            # Find the wireless interface name (usually wlan0 or wlp3s0)
            wifi_interface=$(nmcli -t -f "DEVICE,TYPE" device | grep ":wifi$" | cut -d':' -f1 | head -n 1)
            if [ -n "$wifi_interface" ]; then
                msg "Wi-Fi Manager" "Disconnecting from current active network..."
                nmcli device disconnect "$wifi_interface" &>/dev/null
            fi
        fi

        # Completely wipe out the connection profile
        if nmcli connection delete id "$chosen_del" &>/dev/null; then
            notify-send -i edit-delete "Network Removed" "Successfully disconnected and forgot \"$chosen_del\"."
        else
            notify-send -i dialog-error "Error" "Failed to remove \"$chosen_del\" profile properly."
        fi
    fi
    # Loop back to main menu
    exec "$0"
}

# --- MAIN EXECUTION CRADLE ---
main() {
    local choice
    choice=$(show_main_menu)
    
    case "$choice" in
        *"Enable Wi-Fi")
            nmcli radio wifi on
            msg "Wi-Fi" "Wi-Fi Enabled"
            exec "$0"
            ;;
        *"Disable Wi-Fi")
            nmcli radio wifi off
            msg "Wi-Fi" "Wi-Fi Disabled"
            exec "$0"
            ;;
        *"Scan & Connect to Networks")
            scan_and_connect
            ;;
        *"Manage Saved Networks"*)
            manage_saved
            ;;
        *)
            exit 0
            ;;
    esac
}

main
