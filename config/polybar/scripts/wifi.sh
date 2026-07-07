#!/usr/bin/env bash

# Define the absolute script path clearly
SCRIPT_PATH="$HOME/.config/polybar/scripts/wifi.sh"
# Define the absolute theme path for Rofi
THEME_PATH="$HOME/.config/polybar/rofi/wifi.rasi"

# Function to safely send notifications
msg() {
    if type notify-send &>/dev/null && { dunstify -v &>/dev/null || pgrep -x -u "$USER" "dunst|mako|xfce4-notifyd" &>/dev/null; }; then
        notify-send -i network-wireless "$1" "$2"
    else
        echo "[$1] $2"
    fi
}

# --- SCREEN 1: MAIN MENU ---
show_main_menu() {
    local wifi_state toggle current_net status_str
    wifi_state=$(nmcli radio wifi)
    
    if [[ "$wifi_state" == "enabled" ]]; then
        toggle="    Disable Wi-Fi"
        # Get active SSID safely using device status rather than scanning the air waves again
        current_net=$(nmcli -t -f "DEVICE,TYPE,STATE,CONNECTION" device | grep -E ":wifi:connected:" | cut -d':' -f4)
        if [ -n "$current_net" ]; then
            status_str="    Connected to: $current_net"
        else
            status_str="    Disconnected"
        fi
    else
        toggle="    Enable Wi-Fi"
        status_str="    Wi-Fi is Off"
    fi

    printf "%s\n%s\n%s" "$status_str" "$toggle" "    Scan & Connect to Networks" | \
        rofi -dmenu -i -p "    Wi-Fi Control Center:" -theme "$THEME_PATH"
}

# --- SCREEN 2: SCAN & CONNECT ---
scan_and_connect() {
    msg "Wi-Fi Manager" "Scanning for available networks..."
    
    local wifi_list chosen_network chosen_id saved_connections wifi_password success pass_prompt reveal_pass toggle_option
    
    # Single nmcli run to parse all fields perfectly
    wifi_list=$(nmcli -t -f "IN-USE,SSID,SIGNAL,SECURITY" device wifi list | while IFS=: read -r in_use ssid signal security; do
        [ -z "$ssid" ] && continue
        
        # Determine security icon
        if [[ "$security" =~ "WPA" || "$security" =~ "WEP" ]]; then icon=""; else icon=""; fi
        
        # Map signal strength to explicit nerd font icons
        if [ "$signal" -ge 80 ]; then bars="󰤨"; elif [ "$signal" -ge 60 ]; then bars="󰤥"; elif [ "$signal" -ge 40 ]; then bars="󰤢"; elif [ "$signal" -ge 20 ]; then bars="󰤟"; else bars="󰤯"; fi

        if [ "$in_use" = "*" ]; then
            echo "    $ssid ::: ($bars $signal% $icon) [Connected]"
        else
            echo "    $ssid ::: ($bars $signal% $icon)"
        fi
    done | sort -u)

    chosen_network=$(echo -e "    Back to Main Menu\n$wifi_list" | rofi -dmenu -i -selected-row 1 -p "    Available Networks:" -theme "$THEME_PATH")
    
    [ -z "$chosen_network" ] || [[ "$chosen_network" =~ "Back to Main Menu" ]] && exec "$SCRIPT_PATH" --menu

    # Bulletproof Extraction: Strip the custom leading space and everything past the delimiter " :::"
    chosen_id=$(echo "$chosen_network" | sed -E 's/^    //; s/[[:space:]]*:::.*$//')
    saved_connections=$(nmcli -g NAME connection)

    # Check for an exact literal match in saved connection configurations
    if echo "$saved_connections" | grep -Fqx "$chosen_id"; then
        msg "Wi-Fi Manager" "Connecting to saved network: $chosen_id..."
        if nmcli connection up id "$chosen_id"; then
            msg "Connection Established" "Successfully connected to \"$chosen_id\"."
        else
            msg "Connection Failed" "Could not connect to profile \"$chosen_id\"."
        fi
    else
        reveal_pass=false
        while true; do
            # Accessing properties safely to check if password protection is flagged
            if [[ "$chosen_network" =~ "" ]]; then
                if [ "$reveal_pass" = true ]; then
                    pass_prompt="🔓 <span foreground='#a6e3a1'><b>Visible Mode</b></span> | $chosen_id:"
                    toggle_option="🔒 <span foreground='#f38ba8'>Switch to Hidden Mode</span>"
                    # Fixed: Used -theme-str to dynamically inject prompt markup capability into Rofi's engine
                    wifi_password=$(echo -e "$toggle_option" | rofi -dmenu -i -p "$pass_prompt" -markup-rows -theme "$THEME_PATH" -theme-str 'prompt { markup: true; }')
                else
                    pass_prompt="🔒 <span foreground='#f38ba8'><b>Hidden Mode</b></span> | $chosen_id:"
                    toggle_option="🔓 <span foreground='#a6e3a1'>Switch to Visible Mode</span>"
                    # Fixed: Used -theme-str to dynamically inject prompt markup capability into Rofi's engine
                    wifi_password=$(echo -e "$toggle_option" | rofi -dmenu -password -i -p "$pass_prompt" -markup-rows -theme "$THEME_PATH" -theme-str 'prompt { markup: true; }')
                fi
                
                [ -z "$wifi_password" ] && exit 0 
                
                if [[ "$wifi_password" =~ "Switch to" ]]; then
                    [ "$reveal_pass" = true ] && reveal_pass=false || reveal_pass=true
                    continue
                fi
                
                msg "Wi-Fi Manager" "Authenticating with $chosen_id..."
                success=$(nmcli device wifi connect "$chosen_id" password "$wifi_password" 2>&1)
                
                if [[ "$success" =~ "successfully activated" ]]; then
                    msg "Connection Established" "Successfully connected and profile saved for \"$chosen_id\"."
                    break
                else
                    msg "Authentication Failed" "Incorrect password. Please try again."
                fi
            else
                msg "Wi-Fi Manager" "Connecting to open network: $chosen_id..."
                if nmcli device wifi connect "$chosen_id"; then
                    msg "Connection Established" "Successfully connected to open network."
                fi
                break
            fi
        done
    fi
}

# --- CONTROL MANAGER ---
if [ "$1" = "--menu" ]; then
    choice=$(show_main_menu)
    case "$choice" in
        *"Enable Wi-Fi")
            nmcli radio wifi on
            msg "Wi-Fi" "Wi-Fi Enabled"
            exec "$SCRIPT_PATH" --menu
            ;;
        *"Disable Wi-Fi")
            nmcli radio wifi off
            msg "Wi-Fi" "Wi-Fi Disabled"
            exec "$SCRIPT_PATH" --menu
            ;;
        *"Scan & Connect to Networks")
            scan_and_connect
            ;;
        *)
            exit 0
            ;;
    esac
else
    # --- POLYBAR OUTPUT ---
    if [ "$(nmcli radio wifi)" = "disabled" ]; then
        echo "󰤮 Off"
    else
        active_ssid=$(nmcli -t -f "DEVICE,TYPE,STATE,CONNECTION" device | grep -E ":wifi:connected:" | cut -d':' -f4)
        if [ -n "$active_ssid" ]; then
            # Truncate length natively if the name stretches past 18 characters
            if [ "${#active_ssid}" -gt 18 ]; then
                echo "󰤨 ${active_ssid:0:15}..."
            else
                echo "󰤨 $active_ssid"
            fi
        else
            echo "󰤦 Disconnected"
        fi
    fi
fi