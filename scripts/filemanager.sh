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
            echo -e "${NORD_BLUE}│${RESET}  [ 󱑤 ] Configuring File Manager...       [ ${percent}% ]     ${NORD_BLUE}│${RESET}"
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

install_dependencies() {
    # 1. Install and update XDG standard directories
    show_menu_status "Installing and generating XDG user directories" "RUN" "15"
    sudo apt install -y xdg-user-dirs >/dev/null 2>&1
    xdg-user-dirs-update >/dev/null 2>&1

    # 2. Install virtual filesystem layers
    show_menu_status "Installing background filesystem layers" "RUN" "55"
    sudo apt install -y dbus-x11 gvfs gvfs-backends xdg-desktop-portal xdg-desktop-portal-gtk >/dev/null 2>&1
    
    show_menu_status "Installing background filesystem layers" "RUN" "100"
    show_menu_status "Dependencies integrated" "SUCCESS"
}

clear
echo -e "${NORD_BLUE}╭──────────────────────────────────────────────────────────╮${RESET}"
echo -e "${NORD_BLUE}│${RESET}       󰪶 CHOOSE SYSTEM FILE MANAGER                       ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
echo -e "${NORD_BLUE}│${RESET}  1) Thunar (Lightweight Pill - Recommended for bspwm)     ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  2) Dolphin (Advanced Feature Indexing Engine)            ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  3) Nautilus (Streamlined Modern Interface)              ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  4) Skip Environment Integration                          ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
echo -n "Select option [1-4]: "
read -r CHOICE

case $CHOICE in
    1)
        if dpkg -l | grep -q " thunar "; then
            show_menu_status "Thunar is already deployed" "SUCCESS"
        else
            install_dependencies
            show_menu_status "Deploying Thunar File Environment" "RUN" "50"
            sudo apt install -y --no-install-recommends thunar >/dev/null 2>&1
            show_menu_status "Deploying Thunar File Environment" "RUN" "100"
            show_menu_status "Thunar Framework deployed" "SUCCESS"
        fi
        ;;
    2)
        if dpkg -l | grep -q " dolphin "; then
            show_menu_status "Dolphin is already deployed" "SUCCESS"
        else
            install_dependencies
            show_menu_status "Deploying Dolphin Core Engine" "RUN" "50"
            sudo apt install -y --no-install-recommends dolphin kio-extras >/dev/null 2>&1
            show_menu_status "Deploying Dolphin Core Engine" "RUN" "100"
            show_menu_status "Dolphin Engine deployed" "SUCCESS"
        fi
        ;;
    3)
        if dpkg -l | grep -q " nautilus "; then
            show_menu_status "Nautilus is already deployed" "SUCCESS"
        else
            install_dependencies
            show_menu_status "Deploying Nautilus Interface" "RUN" "50"
            sudo apt install -y --no-install-recommends nautilus >/dev/null 2>&1
            show_menu_status "Deploying Nautilus Interface" "RUN" "100"
            show_menu_status "Nautilus deployed" "SUCCESS"
        fi
        ;;
    *)
        show_menu_status "Skipping File Manager setup" "SUCCESS"
        ;;
esac