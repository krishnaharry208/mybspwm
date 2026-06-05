#!/bin/bash

# ANSI Color Elements
NORD_BLUE="\033[1;36m"
NORD_GREEN="\033[1;32m"
NORD_RED="\033[1;31m"
RESET="\033[0m"

show_menu_status() {
    local task_name="$1"
    local status_type="$2"
    local percent="${3:-0}"

    case "$status_type" in
        "RUN")
            clear
            echo -e "${NORD_BLUE}╭──────────────────────────────────────────────────────────╮${RESET}"
            echo -e "${NORD_BLUE}│${RESET}  [ 󱑤 ] Configuring Terminal...           [ ${percent}% ]     ${NORD_BLUE}│${RESET}"
            echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
            printf "${NORD_BLUE}│${RESET}  ➜ %-52s ${NORD_BLUE}│\n" "$task_name"
            echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
            ;;
        "SUCCESS")
            echo -e "     ${NORD_GREEN}✔ Process Complete${RESET}\n"
            sleep 0.5
            ;;
    esac
}

clear
echo -e "${NORD_BLUE}╭──────────────────────────────────────────────────────────╮${RESET}"
echo -e "${NORD_BLUE}│${RESET}       󰞷 CHOOSE DEFAULT TERMINAL                          ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
echo -e "${NORD_BLUE}│${RESET}  1) Alacritty (GPU Accelerated - Simple & Fast)          ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  2) Kitty (GPU Accelerated - Rich Features & Tabs)        ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  3) Skip / Keep Defaults                                  ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
echo -n "Select option [1-3]: "
read -r CHOICE

case $CHOICE in
    1)
        if dpkg -l | grep -q " alacritty "; then
            show_menu_status "Alacritty is already deployed" "SUCCESS"
        else
            show_menu_status "Deploying Alacritty Environment" "RUN" "50"
            sudo apt install -y alacritty >/dev/null 2>&1
            show_menu_status "Deploying Alacritty Environment" "RUN" "100"
            show_menu_status "Alacritty deployed" "SUCCESS"
        fi
        ;;
    2)
        if dpkg -l | grep -q " kitty "; then
            show_menu_status "Kitty is already deployed" "SUCCESS"
        else
            show_menu_status "Deploying Kitty Terminal Core" "RUN" "50"
            sudo apt install -y kitty >/dev/null 2>&1
            show_menu_status "Deploying Kitty Terminal Core" "RUN" "100"
            show_menu_status "Kitty Terminal deployed" "SUCCESS"
        fi
        ;;
    *)
        show_menu_status "Skipping custom terminal setup" "SUCCESS"
        ;;
esac