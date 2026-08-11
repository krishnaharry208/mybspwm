#!/bin/bash

# --- User & Directory Resolution ---
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
SCRIPTS_SRC="$SCRIPT_DIR/scripts"
BACKUP_DIR="$REAL_HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

# Theme & Font Directories (Supporting XDG Standard and legacy ~/.fonts)
THEMES_DIR="$REAL_HOME/.local/share/themes"
FONTS_DIR="$REAL_HOME/.local/share/fonts"
LEGACY_FONTS_DIR="$REAL_HOME/.fonts"

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

check_internet() {
    if ! ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        fail "No internet connection. Please connect and try again."
        return 1
    fi
    return 0
}

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

install_packages() {
    # NOTE: xdg-user-dirs-update is NOT a real package name on Debian/Ubuntu.
    # The xdg-user-dirs-update binary ships inside the "xdg-user-dirs" package.
    local -a PACKAGES=(
        bspwm sxhkd polybar picom rofi feh dunst libnotify-bin
        brightnessctl alsa-utils pulseaudio pavucontrol
        xorg xinit lxappearance papirus-icon-theme
        breeze-icon-theme bibata-cursor-theme fastfetch
        flameshot fonts-font-awesome fonts-inter
        curl wget git unzip x11-xserver-utils libinput-tools
        fontconfig xdg-user-dirs
    )

    local -a TO_INSTALL=()
    local -a FAILED=()
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
    fi

    # Install one package at a time instead of one big batch command.
    # apt install is atomic across the whole list: a single unknown/renamed
    # package name (e.g. one missing from your distro's repos or version)
    # would otherwise abort the ENTIRE install and silently skip every
    # other valid package too. Installing individually means one bad name
    # only fails itself and gets reported, instead of blocking everything.
    for pkg in "${TO_INSTALL[@]}"; do
        if sudo apt install -y "$pkg"; then
            success "Installed: $pkg"
        else
            fail "Failed to install package: $pkg"
            FAILED+=("$pkg")
        fi
    done

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        warn "The following packages could not be installed and may need a PPA or a different name on your distro: ${FAILED[*]}"
        return 1
    fi

    success "Package installation complete."
    return 0
}

clone_theme() {
    local name="$1"
    local url="$2"
    local dest="$3"

    if [[ -d "$dest" ]]; then
        success "Theme '$name' already exists at $dest"
        return 0
    fi

    log "Cloning $name theme..."
    if ! sudo -u "$REAL_USER" git clone --depth=1 "$url" "$dest"; then
        fail "Failed to clone $name theme"
        return 1
    fi
    success "Cloned $name theme"
    return 0
}

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
        chown "$REAL_USER:$REAL_USER" "$dest" 2>/dev/null
        success "Copied: $desc -> $dest"
        return 0
    else
        fail "Failed to copy: $desc"
        return 1
    fi
}

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
        chown -R "$REAL_USER:$REAL_USER" "$dest" 2>/dev/null
        success "Copied directory: $desc -> $dest"
        return 0
    else
        fail "Failed to copy directory: $desc"
        return 1
    fi
}

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

install_external_assets() {
    log "Setting up Font and Theme directories..."
    mkdir -p "$THEMES_DIR"
    mkdir -p "$FONTS_DIR"
    mkdir -p "$LEGACY_FONTS_DIR"

    # 1. Download Sweet-Dark Theme
    log "Downloading Sweet-Dark Theme..."
    local sweet_zip="/tmp/Sweet-Dark-v40.zip"
    if wget -q --show-progress "https://github.com/EliverLara/Sweet/releases/download/v4.0/Sweet-Dark-v40.zip" -O "$sweet_zip"; then
        unzip -q -o "$sweet_zip" -d "$THEMES_DIR/"
        rm -f "$sweet_zip"
        success "Installed Sweet-Dark Theme to $THEMES_DIR"
    else
        fail "Failed to download Sweet-Dark Theme"
    fi

    # 2. Download FiraCode & Meslo Nerd Fonts
    log "Downloading FiraCode & Meslo Nerd Fonts..."
    local font_urls=(
        "FiraCode|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip"
        "Meslo|https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip"
    )

    for font_entry in "${font_urls[@]}"; do
        IFS="|" read -r font_name font_url <<< "$font_entry"
        local font_zip="/tmp/${font_name}.zip"

        log "Fetching $font_name Nerd Font..."
        if wget -q --show-progress "$font_url" -O "$font_zip"; then
            unzip -q -o "$font_zip" -d "$FONTS_DIR/"
            unzip -q -o "$font_zip" -d "$LEGACY_FONTS_DIR/"
            rm -f "$font_zip"
            success "Extracted $font_name Nerd Font"
        else
            fail "Failed to download $font_name Nerd Font"
        fi
    done

    # 3. Move local FontAwesome files if present in dotfonts
    if [[ -d "$SCRIPT_DIR/dotfonts/fontawesome/otfs" ]]; then
        log "Copying local FontAwesome OTF files..."
        cp -f "$SCRIPT_DIR/dotfonts/fontawesome/otfs/"*.otf "$FONTS_DIR/" 2>/dev/null
        cp -f "$SCRIPT_DIR/dotfonts/fontawesome/otfs/"*.otf "$LEGACY_FONTS_DIR/" 2>/dev/null
        success "Copied FontAwesome OTFs"
    fi

    # 4. Fix User Ownership
    chown -R "$REAL_USER:$REAL_USER" "$FONTS_DIR" "$LEGACY_FONTS_DIR" "$THEMES_DIR" 2>/dev/null

    # 5. Reload Font Cache
    log "Reloading Font Cache (fc-cache -vf)..."
    sudo -u "$REAL_USER" fc-cache -vf &>/dev/null || fc-cache -vf &>/dev/null
    success "Font cache successfully updated"
}

# --- Main Execution ---

main() {
    log "Starting BSPWM Installation (Error Collection Mode)..."
    
    bootstrap_local_configs

    log "Creating XDG configuration and asset directories..."
    mkdir -p "$REAL_HOME/.config"/{alacritty,fastfetch,bspwm,picom,polybar/scripts,polybar/rofi,polybar/icons,rofi/themes,sxhkd,bash,wallpapers,gtk-3.0}
    mkdir -p "$REAL_HOME/Pictures/wallpapers"
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
    safe_copy "$CONFIG_SRC/x/.Xresources" "$REAL_HOME/.Xresources" "X Resources"
    safe_copy "$CONFIG_SRC/x/.Xnord" "$REAL_HOME/.Xnord" "Nord Theme"
    
    if [[ -f "$REAL_HOME/.Xresources" ]]; then
        if [[ -n "$DISPLAY" ]]; then
            if xrdb -merge "$REAL_HOME/.Xresources"; then
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
    safe_copy_dir "$CONFIG_SRC/gtk-3.0" "$REAL_HOME/.config/gtk-3.0" "GTK 3.0 Settings"

    # 5. Copy Application Configs
    log "Copying application configurations..."
    safe_copy "$CONFIG_SRC/alacritty/alacritty.toml" "$REAL_HOME/.config/alacritty/alacritty.toml" "Alacritty"
    safe_copy "$CONFIG_SRC/fastfetch/config.jsonc" "$REAL_HOME/.config/fastfetch/config.jsonc" "Fastfetch"
    safe_copy "$CONFIG_SRC/bspwm/bspwmrc" "$REAL_HOME/.config/bspwm/bspwmrc" "Bspwm"
    safe_copy "$CONFIG_SRC/picom/picom.conf" "$REAL_HOME/.config/picom/picom.conf" "Picom"
    safe_copy "$CONFIG_SRC/rofi/config.rasi" "$REAL_HOME/.config/rofi/config.rasi" "Rofi Config"
    safe_copy "$CONFIG_SRC/rofi/themes/rofi.rasi" "$REAL_HOME/.config/rofi/themes/rofi.rasi" "Rofi Theme"
    safe_copy "$CONFIG_SRC/sxhkd/sxhkdrc" "$REAL_HOME/.config/sxhkd/sxhkdrc" "Sxhkd"

    safe_copy "$CONFIG_SRC/polybar/config.ini" "$REAL_HOME/.config/polybar/config.ini" "Polybar Config"
    safe_copy "$CONFIG_SRC/polybar/launch.sh" "$REAL_HOME/.config/polybar/launch.sh" "Polybar Launch"
    safe_copy_dir "$CONFIG_SRC/polybar/scripts" "$REAL_HOME/.config/polybar/scripts" "Polybar Scripts"
    safe_copy_dir "$CONFIG_SRC/polybar/rofi" "$REAL_HOME/.config/polybar/rofi" "Polybar Rofi"
    safe_copy_dir "$CONFIG_SRC/polybar/icons" "$REAL_HOME/.config/polybar/icons" "Polybar Icons"

    if [[ -d "$CONFIG_SRC/wallpapers" ]]; then
        safe_copy_dir "$CONFIG_SRC/wallpapers" "$REAL_HOME/.config/wallpapers" "Config Wallpapers"
    fi
    if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
        safe_copy_dir "$SCRIPT_DIR/wallpapers" "$REAL_HOME/Pictures/wallpapers" "Pictures Wallpapers"
    fi

    # 6. Install Git Themes (Nordic & Dracula)
    log "Installing Git GTK Themes..."
    clone_theme "Nordic" "https://github.com/EliverLara/Nordic.git" "$THEMES_DIR/Nordic"
    clone_theme "Dracula" "https://github.com/dracula/gtk.git" "$THEMES_DIR/Dracula"

    # 7. Install External Assets (Sweet-Dark, FiraCode, Meslo)
    install_external_assets

    # 8. Bash Configuration
    log "Migrating Bash configurations..."
    mkdir -p "$REAL_HOME/.config/bash"
    
    declare -A BASH_MAP=(
        ["bash/.bashrc"]="bashrc"
        ["bash/.bash_aliases"]="bash_aliases"
        ["bash/.profile"]="profile"
    )

    for src_rel in "${!BASH_MAP[@]}"; do
        local dest_name="${BASH_MAP[$src_rel]}"
        local src_path="$SCRIPTS_SRC/$src_rel"
        local dest_path="$REAL_HOME/.config/bash/$dest_name"
        
        safe_copy "$src_path" "$dest_path" "Bash $dest_name"
    done

    backup_config "$REAL_HOME/.profile"
    backup_config "$REAL_HOME/.bashrc"
    backup_config "$REAL_HOME/.bash_aliases"

    cat > "$REAL_HOME/.profile" <<'EOF'
if [ -f "$HOME/.config/bash/profile" ]; then . "$HOME/.config/bash/profile"; fi
EOF

    cat > "$REAL_HOME/.bashrc" <<'EOF'
if [ -f "$HOME/.config/bash/bashrc" ]; then . "$HOME/.config/bash/bashrc"; fi
EOF

    cat > "$REAL_HOME/.bash_aliases" <<'EOF'
if [ -f "$HOME/.config/bash/bash_aliases" ]; then . "$HOME/.config/bash/bash_aliases"; fi
EOF

    if command -v fastfetch &> /dev/null && ! grep -q "fastfetch" "$REAL_HOME/.config/bash/bashrc" 2>/dev/null; then
        echo -e "\n# Auto-run fastfetch\n[ -x /usr/bin/fastfetch ] && fastfetch" >> "$REAL_HOME/.config/bash/bashrc"
        success "Added fastfetch to bashrc"
    fi

    # 9. Set Executable Permissions
    log "Setting executable permissions..."
    local exec_files=(
        "$REAL_HOME/.config/bspwm/bspwmrc"
        "$REAL_HOME/.config/polybar/launch.sh"
        "$REAL_HOME/.config/polybar/scripts/"*.sh
        "$REAL_HOME/.config/wallpapers/wallpaper.sh"
    )

    for file in "${exec_files[@]}"; do
        for f in $file; do
            if [[ -f "$f" ]]; then
                chmod +x "$f"
            fi
        done
    done

    # Reclaim home ownership
    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config" "$REAL_HOME/.local" "$REAL_HOME/.fonts" "$REAL_HOME/Pictures" 2>/dev/null
    success "Permissions set"

    # 10. System Configurations
    log "Configuring system files..."
    
    write_system_file "/etc/X11/xorg.conf.d/30-touchpad.conf" 'Section "InputClass"
    Identifier "Touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "TappingButtonMap" "lrm"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "ClickMethod" "clickfinger"
    Option "AccelSpeed" "0.3"
EndSection' "Touchpad Config"

    backup_config "$REAL_HOME/.xinitrc"
    cat > "$REAL_HOME/.xinitrc" <<'EOF'
#!/bin/sh
xrdb -merge "$HOME/.Xresources"
exec dbus-launch --sh-syntax --exit-with-session bspwm
EOF
    chmod +x "$REAL_HOME/.xinitrc"

    backup_config "$REAL_HOME/.bash_profile"
    cat > "$REAL_HOME/.bash_profile" <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF

    # 11. Run Non-Network Helper Scripts
    log "Running initial helper scripts..."
    for script in filemanager.sh terminal.sh browser.sh; do
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

    # 12. Run network.sh as Final Task & Reboot
    if [[ -f "$SCRIPTS_SRC/network.sh" ]]; then
        log "Executing network.sh as final step..."
        chmod +x "$SCRIPTS_SRC/network.sh"
        if ! "$SCRIPTS_SRC/network.sh"; then
            fail "Script network.sh exited with errors"
        fi
    fi

    log "Rebooting system in 3 seconds to apply all network and session changes..."
    for i in 3 2 1; do
        echo -e "${YELLOW}$i...${RESET}"
        sleep 1
    done
    sudo reboot
}

main "$@"