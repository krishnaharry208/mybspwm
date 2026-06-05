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
            echo -e "${NORD_BLUE}│${RESET}  [ 󱑤 ] Configuring Browser...            [ ${percent}% ]     ${NORD_BLUE}│${RESET}"
            echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
            printf "${NORD_BLUE}│${RESET}  ➜ %-52s ${NORD_BLUE}│\n" "$task_name"
            echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
            ;;
        "SUCCESS")
            echo -e "     ${NORD_GREEN}✔ Process Complete${RESET}\n"
            sleep 0.5
            ;;
        "FAIL")
            echo -e "     ${NORD_RED}✘ Process Failed${RESET}\n"
            sleep 1
            ;;
    esac
}

clear
echo -e "${NORD_BLUE}╭──────────────────────────────────────────────────────────╮${RESET}"
echo -e "${NORD_BLUE}│${RESET}       󰈹 CHOOSE WEB BROWSER                               ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
echo -e "${NORD_BLUE}│${RESET}  1) Firefox ESR (Debian Default - Stable & Secure)        ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  2) Brave Browser (Privacy Focused - Adblocker Built-in)  ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  3) Google Chrome (Standard Stable Release)                ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  4) Microsoft Edge (Chromium Engine - Features & Sync)    ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  5) Thorium Browser (Compiler Optimized - Ultra Fast)     ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}│${RESET}  6) Skip Browser Setup                                    ${NORD_BLUE}│${RESET}"
echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
echo -n "Select option [1-6]: "
read -r CHOICE

case $CHOICE in
    1)
        if dpkg -l | grep -q " firefox-esr "; then
            show_menu_status "Firefox ESR is already deployed" "SUCCESS"
        else
            show_menu_status "Deploying Firefox ESR Environment" "RUN" "50"
            sudo apt install -y firefox-esr >/dev/null 2>&1
            show_menu_status "Deploying Firefox ESR Environment" "RUN" "100"
            show_menu_status "Firefox ESR deployed" "SUCCESS"
        fi
        ;;
    2)
        if command -v brave-browser >/dev/null; then
            show_menu_status "Brave Browser is already deployed" "SUCCESS"
        else
            show_menu_status "Setting up Brave Repository keys" "RUN" "25"
            sudo apt install -y curl >/dev/null 2>&1
            sudo curl -fsSLo /usr/share/keyrings/brave-browser.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg >/dev/null 2>&1
            echo "deb [signed-by=/usr/share/keyrings/brave-browser.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave.list >/dev/null 2>&1
            
            show_menu_status "Updating package database" "RUN" "50"
            sudo apt update >/dev/null 2>&1
            
            show_menu_status "Deploying Brave Browser Package" "RUN" "75"
            sudo apt install -y brave-browser >/dev/null 2>&1
            
            show_menu_status "Deploying Brave Browser Package" "RUN" "100"
            show_menu_status "Brave Browser deployed" "SUCCESS"
        fi
        ;;
    3)
        if command -v google-chrome-stable >/dev/null; then
            show_menu_status "Google Chrome is already deployed" "SUCCESS"
        else
            show_menu_status "Downloading Google Chrome Signing Key" "RUN" "25"
            sudo apt install -y curl >/dev/null 2>&1
            sudo curl -fsSLo /usr/share/keyrings/google-chrome.gpg https://dl-ssl.google.com/linux/linux_signing_key.pub >/dev/null 2>&1
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null 2>&1
            
            show_menu_status "Updating package database" "RUN" "50"
            sudo apt update >/dev/null 2>&1
            
            show_menu_status "Deploying Google Chrome Stable" "RUN" "75"
            sudo apt install -y google-chrome-stable >/dev/null 2>&1
            
            show_menu_status "Deploying Google Chrome Stable" "RUN" "100"
            show_menu_status "Google Chrome deployed" "SUCCESS"
        fi
        ;;
    4)
        if command -v microsoft-edge-stable >/dev/null; then
            show_menu_status "Microsoft Edge is already deployed" "SUCCESS"
        else
            show_menu_status "Setting up Microsoft Edge Repository keys" "RUN" "25"
            sudo apt install -y curl gpg >/dev/null 2>&1
            sudo curl -fsSLo /usr/share/keyrings/microsoft-edge.gpg https://packages.microsoft.com/keys/microsoft.asc 
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null 2>&1
            
            show_menu_status "Updating package database" "RUN" "50"
            sudo apt update >/dev/null 2>&1
            
            show_menu_status "Deploying Microsoft Edge Stable" "RUN" "75"
            sudo apt install -y microsoft-edge-stable >/dev/null 2>&1
            
            show_menu_status "Deploying Microsoft Edge Stable" "RUN" "100"
            show_menu_status "Microsoft Edge deployed" "SUCCESS"
        fi
        ;;
    5)
        if dpkg -l | grep -q " thorium-browser "; then
            show_menu_status "Thorium Browser is already deployed" "SUCCESS"
        else
            show_menu_status "Setting up Thorium Repository keys" "RUN" "25"
            sudo apt install -y curl dirmngr GNUPG >/dev/null 2>&1
            sudo curl -fsSLo /usr/share/keyrings/thorium.gpg https://dl.thorium.rocks/debian/thorium.gpg
            echo "deb [signed-by=/usr/share/keyrings/thorium.gpg] https://dl.thorium.rocks/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thorium.list >/dev/null 2>&1
            
            show_menu_status "Updating package database" "RUN" "50"
            sudo apt update >/dev/null 2>&1
            
            show_menu_status "Deploying Thorium Browser Package" "RUN" "75"
            sudo apt install -y thorium-browser >/dev/null 2>&1
            
            show_menu_status "Deploying Thorium Browser Package" "RUN" "100"
            show_menu_status "Thorium Browser deployed" "SUCCESS"
        fi
        ;;
    *)
        show_menu_status "Skipping Web Browser setup" "SUCCESS"
        ;;
esac