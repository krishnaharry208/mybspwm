#!/bin/bash

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
SCRIPTS_SRC="$SCRIPT_DIR/scripts"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# --- Colors ---
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# --- Error Tracking ---
declare -a ERRORS=()

log() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[✔]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
fail() { 
    echo -e "${RED}[✘]${RESET} $1"
    ERRORS+=("$1")
}

# --- Helper Functions ---

# Check internet connectivity
check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        fail "No internet connection. Please connect and try again."
        return 1
    fi
    return 0
}

# Auto-bootstrap missing local config files if possible
bootstrap_local_configs() {
    log "Ensuring local configuration templates exist..."
    mkdir -p "$CONFIG_SRC/x"
    
    if [[ ! -f "$CONFIG_SRC/x/.Xresources" ]]; then
        cat << 'EOF' > "$CONFIG_SRC/x/.Xresources"
Xcursor.theme: Bibata-Modern-Classic
Xcursor.size: 24
EOF
        warn "Created default template: config/x/.Xresources"
    fi

    if [[ ! -f "$CONFIG_SRC/x/.Xnord" ]]; then
        touch "$CONFIG_SRC/x/.Xnord"
        warn "Created empty template: config/x/.Xnord"
    fi
}

# Backup existing config file if it exists
backup_config() {
    local dest="$1"
    if [[ -e "$dest" ]]; then
        local parent_dir
        parent_dir="$(dirname "$dest")"
        mkdir -p "$BACKUP_DIR/$parent_dir"
        if cp -a "$dest" "$BACKUP_DIR/$dest"; then
            warn "Backed up existing: $dest"
        else
            fail "Failed to backup: $dest"
        fi
    fi
}

# Install packages 
install_packages() {
    local -a PACKAGES=(
        bspwm sxhkd polybar picom rofi feh 
        brightnessctl alsa-utils pulseaudio pavucontrol
        xorg xinit lxappearance papirus-icon-theme
        breeze-icon-theme bibata-cursor-theme fastfetch
        flameshot fonts-font-awesome fonts-inter
        curl git unzip x11-xserver-utils libinput-tools
        gnome-themes-extra gnome-themes-extra-data
    )

    local -a TO_INSTALL=()
    local pkg

    log "Checking for missing packages..."
    for pkg in "${PACKAGES[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            TO_INSTALL+=("$pkg")
        fi
    done

    if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
        success "All required packages are already installed."
        return 0
    fi

    log "Installing missing packages: ${TO_INSTALL[*]}"
    if ! sudo apt update -y; then
        fail "Failed to update package list"
        return 1
    fi

    if ! sudo apt install -y "${TO_INSTALL[@]}"; then
        fail "Failed to install one or more packages: ${TO_INSTALL[*]}"
        return 1
    fi
    
    success "Package installation complete."
    return 0
}

# Clone git repo 
clone_theme() {
    local name="$1"
    local url="$2"
    local dest="$3"

    if [[ -d "$dest" ]]; then
        success "Theme '$name' already exists at $dest"
        return 0
    fi

    log "Cloning $name theme..."
    if ! git clone --depth=1 "$url" "$dest"; then
        fail "Failed to clone $name theme"
        return 1
    fi
    success "Cloned $name theme"
    return 0
}

# Copy file with error collection
safe_copy() {
    local src="$1"
    local dest="$2"
    local desc="${3:-$src}"

    if [[ ! -f "$src" ]]; then
        fail "Source file missing: $src (Skipping $desc)"
        return 1
    fi

    backup_config "$dest"
    mkdir -p "$(dirname "$dest")"
    
    if cp -f "$src" "$dest"; then
        success "Copied: $desc -> $dest"
        return 0
    else
        fail "Failed to copy: $desc"
        return 1
    fi
}

# Copy directory
safe_copy_dir() {
    local src="$1"
    local dest="$2"
    local desc="${3:-$src}"

    if [[ ! -d "$src" ]]; then
        fail "Source directory missing: $src (Skipping $desc)"
        return 1
    fi

    backup_config "$dest"
    mkdir -p "$dest"
    
    if cp -r "$src"/. "$dest"/ 2>/dev/null; then
        success "Copied directory: $desc -> $dest"
        return 0
    else
        fail "Failed to copy directory: $desc"
        return 1
    fi
}

# Write to /etc with proper sudo and directory checks
write_system_file() {
    local path="$1"
    local content="$2"
    local desc="$3"

    if ! sudo mkdir -p "$(dirname "$path")"; then
        fail "Failed to create system directory for: $desc"
        return 1
    fi

    if echo "$content" | sudo tee "$path" > /dev/null; then
        success "Wrote system config: $desc"
        return 0
    else
        fail "Failed to write system config: $desc"
        return 1
    fi
}

# --- Main Execution ---

main() {
    log "Starting BSPWM Installation (Error Collection Mode)..."
    
    # Bootstrap missing templates locally to prevent file missing errors
    bootstrap_local_configs

    # Create directories first
    log "Creating configuration directories..."
    mkdir -p "$HOME/.config"/{alacritty,fastfetch,bspwm,picom,polybar/scripts,polybar/rofi,polybar/icons,rofi/themes,sxhkd,bash,wallpapers,gtk-3.0}
    mkdir -p "$HOME/.themes"
    mkdir -p "$HOME/Pictures/wallpapers"
    mkdir -p "$BACKUP_DIR"

    # 1. Check Internet
    if ! check_internet; then
        warn "Proceeding without internet connection, some steps may fail."
    fi

    # 2. Install Packages
    if ! install_packages; then
        fail "Package installation encountered errors."
    fi

    # 3. Copy X Resources
    log "Configuring X Resources..."
    safe_copy "$CONFIG_SRC/x/.Xresources" "$HOME/.Xresources" "X Resources"
    safe_copy "$CONFIG_SRC/x/.Xnord" "$HOME/.Xnord" "Nord Theme"
    
    if [[ -f "$HOME/.Xresources" ]]; then
        if [[ -n "$DISPLAY" ]]; then
            if xrdb -merge "$HOME/.Xresources"; then
                success "X resources merged"
            else
                fail "Failed to merge X resources"
            fi
        else
            warn "No active display found ($DISPLAY unset). Skipping live xrdb merge (will apply on next X session)."
        fi
    fi

    # 4. Copy GTK 3.0
    log "Configuring GTK 3.0..."
    safe_copy_dir "$CONFIG_SRC/gtk-3.0" "$HOME/.config/gtk-3.0" "GTK 3.0 Settings"

    # 5. Copy Application Configs
    log "Copying application configurations..."
    
    safe_copy "$CONFIG_SRC/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml" "Alacritty"
    safe_copy "$CONFIG_SRC/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc" "Fastfetch"
    safe_copy "$CONFIG_SRC/bspwm/bspwmrc" "$HOME/.config/bspwm/bspwmrc" "Bspwm"
    safe_copy "$CONFIG_SRC/picom/picom.conf" "$HOME/.config/picom/picom.conf" "Picom"
    safe_copy "$CONFIG_SRC/rofi/config.rasi" "$HOME/.config/rofi/config.rasi" "Rofi Config"
    safe_copy "$CONFIG_SRC/rofi/themes/rofi.rasi" "$HOME/.config/rofi/themes/rofi.rasi" "Rofi Theme"
    safe_copy "$CONFIG_SRC/sxhkd/sxhkdrc" "$HOME/.config/sxhkd/sxhkdrc" "Sxhkd"

    safe_copy "$CONFIG_SRC/polybar/config.ini" "$HOME/.config/polybar/config.ini" "Polybar Config"
    safe_copy "$CONFIG_SRC/polybar/launch.sh" "$HOME/.config/polybar/launch.sh" "Polybar Launch"
    safe_copy_dir "$CONFIG_SRC/polybar/scripts" "$HOME/.config/polybar/scripts" "Polybar Scripts"
    safe_copy_dir "$CONFIG_SRC/polybar/rofi" "$HOME/.config/polybar/rofi" "Polybar Rofi"
    safe_copy_dir "$CONFIG_SRC/polybar/icons" "$HOME/.config/polybar/icons" "Polybar Icons"

    if [[ -d "$CONFIG_SRC/wallpapers" ]]; then
        safe_copy_dir "$CONFIG_SRC/wallpapers" "$HOME/.config/wallpapers" "Config Wallpapers"
    fi
    if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
        safe_copy_dir "$SCRIPT_DIR/wallpapers" "$HOME/Pictures/wallpapers" "Pictures Wallpapers"
    fi

    # 6. Bash Configuration
    log "Migrating Bash configurations..."
    mkdir -p "$HOME/.config/bash"
    
    declare -A BASH_MAP=(
        ["bash/.bashrc"]="bashrc"
        ["bash/.bash_aliases"]="bash_aliases"
        ["bash/.profile"]="profile"
    )

    for src_rel in "${!BASH_MAP[@]}"; do
        local dest_name="${BASH_MAP[$src_rel]}"
        local src_path="$SCRIPTS_SRC/$src_rel"
        local dest_path="$HOME/.config/bash/$dest_name"
        
        safe_copy "$src_path" "$dest_path" "Bash $dest_name"
    done

    backup_config "$HOME/.profile"
    backup_config "$HOME/.bashrc"
    backup_config "$HOME/.bash_aliases"

    cat > "$HOME/.profile" <<'EOF'
if [ -f "$HOME/.config/bash/profile" ]; then . "$HOME/.config/bash/profile"; fi
EOF

    cat > "$HOME/.bashrc" <<'EOF'
if [ -f "$HOME/.config/bash/bashrc" ]; then . "$HOME/.config/bash/bashrc"; fi
EOF

    cat > "$HOME/.bash_aliases" <<'EOF'
if [ -f "$HOME/.config/bash/bash_aliases" ]; then . "$HOME/.config/bash/bash_aliases"; fi
EOF

    if command -v fastfetch &> /dev/null && ! grep -q "fastfetch" "$HOME/.config/bash/bashrc" 2>/dev/null; then
        echo -e "\n# Auto-run fastfetch\n[ -x /usr/bin/fastfetch ] && fastfetch" >> "$HOME/.config/bash/bashrc"
        success "Added fastfetch to bashrc"
    fi

    # 7. Set Permissions
    log "Setting executable permissions..."
    local exec_files=(
        "$HOME/.config/bspwm/bspwmrc"
        "$HOME/.config/polybar/launch.sh"
        "$HOME/.config/polybar/scripts/"*.sh
        "$HOME/.config/wallpapers/wallpaper.sh"
    )

    for file in "${exec_files[@]}"; do
        for f in $file; do
            if [[ -f "$f" ]]; then
                if chmod +x "$f"; then
                    : # Silent success
                else
                    fail "Failed to set permissions on: $f"
                fi
            fi
        done
    done
    success "Permissions set"

    # 8. System Configs
    log "Configuring system files..."
    
    write_system_file "/etc/X11/xorg.conf.d/30-touchpad.conf" 'Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection' "Touchpad Config"

    backup_config "$HOME/.xinitrc"
    cat > "$HOME/.xinitrc" <<'EOF'
#!/bin/sh
xrdb -merge "$HOME/.Xresources"
exec dbus-launch --sh-syntax --exit-with-session bspwm
EOF
    chmod +x "$HOME/.xinitrc"

    backup_config "$HOME/.bash_profile"
    cat > "$HOME/.bash_profile" <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF

    # 9. GTK Themes
    log "Installing GTK Themes..."
    clone_theme "Nordic" "https://github.com/EliverLara/Nordic.git" "$HOME/.themes/Nordic"
    clone_theme "Dracula" "https://github.com/dracula/gtk.git" "$HOME/.themes/Dracula"

    # 10. Run Helper Scripts
    log "Running helper scripts..."
    for script in filemanager.sh terminal.sh browser.sh network.sh; do
        if [[ -f "$SCRIPTS_SRC/$script" ]]; then
            chmod +x "$SCRIPTS_SRC/$script"
            log "Executing $script..."
            if ! "$SCRIPTS_SRC/$script"; then
                fail "Script $script exited with errors"
            fi
        fi
    done

    # --- FINAL SUMMARY ---
    echo ""
    echo "=============================================="
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        success "Installation Complete! No errors found."
    else
        warn "Installation Finished with ERRORS!"
        echo "=============================================="
        echo "The following steps failed:"
        echo "=============================================="
        local i=1
        for err in "${ERRORS[@]}"; do
            echo "  $i. $err"
            ((i++))
        done
        echo "=============================================="
    fi
    log "Backups stored in: $BACKUP_DIR"
    echo ""
    
   # --- OPTIONAL REBOOT PROMPT ---
    read -rp "Would you like to reboot your system now? (y/N): " choice
    case "$choice" in 
        [yY][eE][sS]|[yY])
            log "Rebooting system in 3 seconds..."
            for i in 3 2 1; do
                echo -e "${YELLOW}$i...${RESET}"
                sleep 1
            done
            sudo reboot
            ;;
        *)
            log "Reboot skipped. Please remember to restart your session later."
            ;;
    esac
}

# Run main
main "$@"