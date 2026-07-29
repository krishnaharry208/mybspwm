#!/usr/bin/env bash

THEME_PATH="$HOME/.config/polybar/rofi/wifi.rasi"
SCRIPT_PATH="$HOME/.config/polybar/scripts/wifi.sh"


notify_msg() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i network-wireless "$1" "$2"
    else
        echo "$1: $2"
    fi
}


show_main_menu() {

    wifi_state=$(nmcli radio wifi)

    if [[ "$wifi_state" == "enabled" ]]; then
        current=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device |
            grep ":wifi:connected:" |
            cut -d':' -f4)

        if [[ -n "$current" ]]; then
            status="󰤨 Connected: $current"
        else
            status="󰤯 Disconnected"
        fi

        toggle="󰖪 Disable Wi-Fi"

    else

        status="󰤮 Wi-Fi Off"
        toggle="󰖩 Enable Wi-Fi"

    fi


    echo -e "$status\n$toggle\n󰤨 Scan Networks" |
    rofi \
        -dmenu \
        -i \
        -p "Wi-Fi" \
        -theme "$THEME_PATH"
}


scan_networks() {

    notify_msg "Wi-Fi" "Scanning networks..."

    networks=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list |
    awk -F: '
    {
        if ($1!="") {
            if ($2>=80) icon="󰤨";
            else if ($2>=60) icon="󰤥";
            else if ($2>=40) icon="󰤢";
            else icon="󰤟";

            print $1"  "icon" "$2"%"
        }
    }' | sort -u)


    choice=$(echo -e "󰁔 Back\n$networks" |
    rofi \
        -dmenu \
        -i \
        -p "Networks" \
        -theme "$THEME_PATH")


    [[ -z "$choice" ]] && exit 0


    if [[ "$choice" == "󰁔 Back" ]]; then
        exec "$SCRIPT_PATH" --menu
    fi


    ssid=$(echo "$choice" | sed -E 's/  󰤨.*|  󰤥.*|  󰤢.*|  󰤟.*//' )


    if nmcli connection show | grep -q "$ssid"; then

        nmcli connection up id "$ssid"

    else

        password=$(rofi \
        -dmenu \
        -password \
        -p "Password:" \
        -theme "$THEME_PATH")


        [[ -z "$password" ]] && exit 0


        nmcli device wifi connect "$ssid" password "$password"

    fi
}


if [[ "$1" == "--menu" ]]; then

    option=$(show_main_menu)

    case "$option" in

        *"Enable Wi-Fi"*)
            nmcli radio wifi on
            notify_msg "Wi-Fi" "Enabled"
            ;;

        *"Disable Wi-Fi"*)
            nmcli radio wifi off
            notify_msg "Wi-Fi" "Disabled"
            ;;

        *"Scan Networks"*)
            scan_networks
            ;;

    esac

    exit 0
fi



# -------- POLYBAR OUTPUT --------

if [[ "$(nmcli radio wifi)" == "disabled" ]]; then

    echo "󰤮 Off"

else

    ssid=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device |
    grep ":wifi:connected:" |
    cut -d':' -f4)


    if [[ -n "$ssid" ]]; then

        if [[ ${#ssid} -gt 18 ]]; then
            echo "󰤨 ${ssid:0:15}..."
        else
            echo "󰤨 $ssid"
        fi

    else

        echo "󰤦 Disconnected"

    fi

fi