#!/bin/bash

# ============================
# INSTALL MODE 
# ============================

FAILED_PACKAGES=()
FAILED_FILES=()

SCRIPT_PATH="$(realpath "$0")"
chmod +x "$SCRIPT_PATH" 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SUBDIR="$SCRIPT_DIR/scripts"

WALLPAPER="$HOME/Pictures/wallpapers/Debian.jpg"

# ============================
# IMPROVED COOL COLORFUL UI
# ============================
show_status() {
    local task_name="$1"
    local status_type="$2" # "RUN", "SUCCESS", "FAIL", "REBOOT"
    local percent="${3:-0}"
    
    # ANSI Color Codes (Nord Palette)
    local NORD_BG="\033[43m"
    local NORD_POLAR="\033[1;30m"
    local NORD_BLUE="\033[1;36m"
    local NORD_GREEN="\033[1;32m"
    local NORD_RED="\033[1;31m"
    local NORD_YELLOW="\033[1;33m"
    local BOLD="\033[1;37m"
    local RESET="\033[0m"

    # Frame dimensions
    local terminal_width=60

    case "$status_type" in
        "RUN")
            clear
            # Calculate progress bar fill
            local bar_width=38
            local filled_chars=$(( (percent * bar_width) / 100 ))
            local empty_chars=$(( bar_width - filled_chars ))
            
            # Construct the smooth progress line
            local progress_line=""
            if [ $filled_chars -gt 0 ]; then
                progress_line+=$(printf '━%.0s' $(seq 1 $filled_chars))
            fi
            if [ $empty_chars -gt 0 ]; then
                progress_line+=$(printf '─%.0s' $(seq 1 $empty_chars))
            fi

            # Format the Big Bold Percentage Readout
            local pct_text="[ ${percent}% ]"
            
            echo -e "${NORD_BLUE}╭──────────────────────────────────────────────────────────╮${RESET}"
            printf "${NORD_BLUE}│${RESET}  ${BOLD}%-38s${RESET}   ${NORD_BLUE}%13s │\n" "DOWNLOADING & INSTALLING" "$pct_text"
            echo -e "${NORD_BLUE}├──────────────────────────────────────────────────────────┤${RESET}"
            printf "${NORD_BLUE}│${RESET}  ${NORD_BLUE}➜ ${RESET}%-51s ${NORD_BLUE}│\n" "$task_name"
            printf "${NORD_BLUE}│${RESET}  ${NORD_BLUE}%s${RESET}  ${NORD_BLUE}│\n" "$progress_line"
            echo -e "${NORD_BLUE}╰──────────────────────────────────────────────────────────╯${RESET}"
            ;;
            
        "SUCCESS")
            echo -e "     ${NORD_GREEN}✔ Successfully Processed${RESET}\n"
            sleep 0.15
            ;;
            
        "FAIL")
            echo -e "     ${NORD_RED}✘ Installation Failed${RESET}\n"
            sleep 1
            ;;
            
        "REBOOT")
            clear
            echo -e "${NORD_YELLOW}╭──────────────────────────────────────────────────────────╮${RESET}"
            echo -e "${NORD_YELLOW}│${RESET}  [ 󰐥 ] SYSTEM REBOOT INITIATED                           ${NORD_YELLOW}│${RESET}"
            echo -e "${NORD_YELLOW}├──────────────────────────────────────────────────────────┤${RESET}"
            printf "${NORD_YELLOW}│${RESET}  ➜ %-52s ${NORD_YELLOW}│\n" "Syncing files and restarting in $percent seconds..."
            echo -e "${NORD_YELLOW}╰──────────────────────────────────────────────────────────╯${RESET}"
            ;;
    esac
}

# Animate progress safely (Pre-calculated sequence prevents blinking)
animate_progress() {
    local task="$1"
    for p in 10 25 45 68 85 100; do
        show_status "$task" "RUN" "$p"
        sleep 0.08
    done
}

echo "=================================="
echo "   BSPWM SMART SAFE INSTALLER"
echo "=================================="

# ============================
# INSTALL FUNCTION (FIXED FLICKER)
# ============================
check_install() {
    local PKG=$1
    local EXTRA=${2:-}

    if dpkg -l | grep -q " $PKG "; then
        echo "[✔] $PKG already installed"
        sleep 0.05
    else
        show_status "$PKG" "RUN" "0"

        sudo apt install -y $EXTRA "$PKG" >/dev/null 2>&1 &
        local pid=$!

        local current_pct=0
        local last_pct=0

        while kill -0 $pid 2>/dev/null; do
            if [ $current_pct -lt 95 ]; then
                current_pct=$((current_pct + 5))
            fi
            
            # Only trigger 'clear' and redraw if the percentage actually changed
            if [ "$current_pct" -ne "$last_pct" ]; then
                show_status "$PKG" "RUN" "$current_pct"
                last_pct=$current_pct
            fi
            
            # Slower polling interval prevents terminal buffer thrashing
            sleep 0.4
        done

        wait $pid
        if [ $? -eq 0 ]; then
            show_status "$PKG" "RUN" "100"
            show_status "$PKG" "SUCCESS"
        else
            show_status "$PKG" "FAIL"
            FAILED_PACKAGES+=("$PKG")
        fi
    fi
}

# ============================
#  COPY
# ============================
safe_cp() {
    local SRC=$1
    local DEST=$2

    if cp -f "$SRC" "$DEST" 2>/dev/null; then
        echo "[✔] Copied: $SRC"
    else
        echo "[✘] FAILED COPY: $SRC"
        FAILED_FILES+=("$SRC")
    fi
}

# ============================
# UPDATE SYSTEM
# ============================
show_status "Updating system package repositories" "RUN" "20"
sudo apt update >/dev/null 2>&1
show_status "Updating system package repositories" "RUN" "100"
show_status "System update complete" "SUCCESS"

# ============================
# CORE PACKAGES
# ============================
for pkg in \
    bspwm sxhkd polybar picom rofi feh \
    brightnessctl alsa-utils pulseaudio pavucontrol \
    xorg xinit lxappearance papirus-icon-theme \
    breeze-icon-theme bibata-cursor-theme fastfetch flameshot \
    fonts-font-awesome fonts-inter curl git unzip x11-xserver-utils \
    libinput-tools
do
    check_install "$pkg"
done

# ==================================
# INTERACTIVE FILE MANAGER MENU
# ==================================
if [ -f "$SCRIPTS_SUBDIR/filemanager.sh" ]; then
    chmod +x "$SCRIPTS_SUBDIR/filemanager.sh"
    "$SCRIPTS_SUBDIR/filemanager.sh"
else
    echo "[✘] ERROR: filemanager.sh not found in $SCRIPTS_SUBDIR"
    FAILED_FILES+=("filemanager.sh script missing")
fi

# ==================================
# INTERACTIVE TERMINAL MENU
# ==================================
if [ -f "$SCRIPTS_SUBDIR/terminal.sh" ]; then
    chmod +x "$SCRIPTS_SUBDIR/terminal.sh"
    "$SCRIPTS_SUBDIR/terminal.sh"
else
    echo "[✘] ERROR: terminal.sh not found in $SCRIPTS_SUBDIR"
    FAILED_FILES+=("terminal.sh script missing")
fi

# ==================================
# INTERACTIVE BROWSER MENU
# ==================================
if [ -f "$SCRIPTS_SUBDIR/browser.sh" ]; then
    chmod +x "$SCRIPTS_SUBDIR/browser.sh"
    "$SCRIPTS_SUBDIR/browser.sh"
else
    echo "[✘] ERROR: browser.sh not found in $SCRIPTS_SUBDIR"
    FAILED_FILES+=("browser.sh script missing")
fi

# ============================
# TOUCHPAD CONFIG
# ============================
animate_progress "Configuring touchpad options (libinput)"
sudo mkdir -p /etc/X11/xorg.conf.d 2>/dev/null || true

sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf >/dev/null <<EOF
Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"

    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "ClickMethod" "clickfinger"
EndSection
EOF
show_status "Touchpad configuration" "SUCCESS"

# ============================
#  FONTS 
# ============================
mkdir -p "$HOME/.local/share/fonts"

# Wrapping font operations safely inside a standalone block 
(
    cd /tmp || exit
    
    # ----------------------------
    # JetBrains Mono
    # ----------------------------
    show_status "Downloading JetBrains Mono Fonts" "RUN" "30"
    if wget -q -O JetBrainsMono.zip https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip; then
        show_status "Extracting JetBrains Mono Fonts" "RUN" "75"
        unzip -oq JetBrainsMono.zip -d JetBrainsMono
        cp JetBrainsMono/fonts/ttf/*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
        show_status "JetBrains Mono" "RUN" "100"
        show_status "JetBrains Mono" "SUCCESS"
    else
        show_status "JetBrains Mono Download" "FAIL"
    fi

    # ----------------------------
    # FiraCode Nerd Font
    # ----------------------------
    show_status "Downloading FiraCode Nerd Font" "RUN" "25"
    if wget -q -O FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip; then
        show_status "Extracting FiraCode Nerd Font" "RUN" "80"
        mkdir -p FiraCodeTemp
        unzip -oq FiraCode.zip -d FiraCodeTemp
        find FiraCodeTemp -name "*.ttf" -exec cp {} "$HOME/.local/share/fonts/" \; >/dev/null 2>&1
        show_status "FiraCode Nerd Font" "RUN" "100"
        show_status "FiraCode Nerd Font" "SUCCESS"
    else
        show_status "FiraCode Nerd Font Download" "FAIL"
    fi

    # ----------------------------
    # MesloLGS NF
    # ----------------------------
    show_status "Downloading MesloLGS NF Fonts" "RUN" "20"
    wget -q -O Meslo-Regular.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
    show_status "Downloading MesloLGS NF Fonts" "RUN" "50"
    wget -q -O Meslo-Bold.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf
    show_status "Downloading MesloLGS NF Fonts" "RUN" "75"
    wget -q -O Meslo-Italic.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf
    wget -q -O Meslo-BoldItalic.ttf https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf

    cp Meslo*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
    show_status "MesloLGS NF Fonts" "RUN" "100"
    show_status "MesloLGS NF Fonts" "SUCCESS"

    fc-cache -f >/dev/null 2>&1
)

# ============================
# CONFIG COPY
# ============================
clear
echo "[+] Copying configs..."
mkdir -p ~/.config/{alacritty,fastfetch,bspwm,picom,polybar,rofi/themes,sxhkd}

safe_cp "$SCRIPT_DIR/alacritty/alacritty.toml" ~/.config/alacritty/
safe_cp "$SCRIPT_DIR/fastfetch/config.jsonc" ~/.config/fastfetch/
safe_cp "$SCRIPT_DIR/bspwm/bspwmrc" ~/.config/bspwm/
safe_cp "$SCRIPT_DIR/picom/picom.conf" ~/.config/picom/
safe_cp "$SCRIPT_DIR/polybar/config.ini" ~/.config/polybar/
safe_cp "$SCRIPT_DIR/polybar/launch.sh" ~/.config/polybar/
safe_cp "$SCRIPT_DIR/rofi/config.rasi" ~/.config/rofi/
safe_cp "$SCRIPT_DIR/rofi/themes/rofi.rasi" ~/.config/rofi/themes/
safe_cp "$SCRIPT_DIR/sxhkd/sxhkdrc" ~/.config/sxhkd/

chmod +x ~/.config/bspwm/bspwmrc 2>/dev/null || true
chmod +x ~/.config/polybar/launch.sh 2>/dev/null || true

# ============================
# FASTFETCH SETUP
# ============================
echo "[+] Configuring Fastfetch..."
touch "$HOME/.bashrc"
if ! grep -q "fastfetch" "$HOME/.bashrc"; then
cat >> "$HOME/.bashrc" <<'EOF'
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch
fi
EOF
fi

# ============================
# GTK THEMES
# ============================
mkdir -p "$HOME/.themes"
if [ ! -d "$HOME/.themes/Nordic" ]; then
    show_status "Cloning Nordic GTK Theme" "RUN" "40"
    git clone https://github.com/EliverLara/Nordic.git "$HOME/.themes/Nordic" >/dev/null 2>&1
    show_status "Cloning Nordic GTK Theme" "RUN" "100"
    show_status "Nordic Theme" "SUCCESS"
fi

if [ ! -d "$HOME/.themes/Dracula" ]; then
    show_status "Cloning Dracula GTK Theme" "RUN" "40"
    git clone https://github.com/dracula/gtk.git "$HOME/.themes/Dracula" >/dev/null 2>&1
    show_status "Cloning Dracula GTK Theme" "RUN" "100"
    show_status "Dracula Theme" "SUCCESS"
fi

# ============================
# SERVICES & ASSETS
# ============================
pulseaudio --start 2>/dev/null || true

cat > "$HOME/.xinitrc" <<EOF
#!/bin/sh
pulseaudio --start &
exec dbus-launch --sh-syntax --exit-with-session bspwm
EOF
chmod +x "$HOME/.xinitrc"

cat > "$HOME/.bash_profile" <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF

mkdir -p "$HOME/Pictures/wallpapers"
safe_cp "$SCRIPT_DIR/wallpapers/Debian.jpg" "$HOME/Pictures/wallpapers/Debian.jpg"

# ============================
# FINAL + REBOOT
# ============================
clear
echo "=================================="
echo " INSTALL COMPLETE"
echo "=================================="
echo "✔ All elements deployed correctly"
echo "=================================="

if [ ${#FAILED_PACKAGES[@]} -gt 0 ] || [ ${#FAILED_FILES[@]} -gt 0 ]; then
    printf 'Errors found inside packages: %s\n' "${FAILED_PACKAGES[*]}"
    printf 'Errors found inside files: %s\n' "${FAILED_FILES[*]}"
    echo "Press Enter to force reboot..."
    read -r
fi

sync
for i in 5 4 3 2 1; do
    show_status "" "REBOOT" "$i"
    sleep 1
done

sudo reboot