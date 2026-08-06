#!/bin/bash

# --- User & Directory Resolution ---
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config"
SCRIPTS_SRC="$SCRIPT_DIR/scripts"
BACKUP_DIR="$REAL_HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"

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
        success "Updated: $desc -> $dest"
        return 0
    else
        fail "Failed to update: $desc"
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
        success "Updated directory: $desc -> $dest"
        return 0
    else
        fail "Failed to update directory: $desc"
        return 1
    fi
}

# --- Main Execution ---

main() {
    log "Starting Quick Dotfiles & Configuration Sync..."
    mkdir -p "$BACKUP_DIR"

    # 1. Update X Resources
    log "Updating X11 Resources..."
    safe_copy "$CONFIG_SRC/x/.Xresources" "$REAL_HOME/.Xresources" "X Resources"
    safe_copy "$CONFIG_SRC/x/.Xnord" "$REAL_HOME/.Xnord" "Nord Theme"

    # 2. Update GTK Configuration
    log "Updating GTK 3.0 configuration..."
    safe_copy_dir "$CONFIG_SRC/gtk-3.0" "$REAL_HOME/.config/gtk-3.0" "GTK 3.0 Settings"

    # 3. Update Application Configs
    log "Updating dotfiles in ~/.config..."
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

    # 4. Update Bash Configuration
    log "Updating Bash scripts..."
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

    # 5. Set Executable Permissions
    log "Enforcing script permissions..."
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

    chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config" 2>/dev/null

    # 6. Live Environment Reload (if X session is active)
    if [[ -n "$DISPLAY" ]]; then
        log "Active X session detected. Reloading running services..."
        
        # Merge Xresources
        xrdb -merge "$REAL_HOME/.Xresources" 2>/dev/null && success "Reloaded xrdb"

        # Reload BSPWM
        if command -v bspc &>/dev/null && pgrep -x bspwm &>/dev/null; then
            bspc wm -r && success "Reloaded BSPWM"
        fi

        # Reload SXHKD keybindings
        if pgrep -x sxhkd &>/dev/null; then
            pkill -USR1 -x sxhkd && success "Reloaded SXHKD keybindings"
        fi

        # Relaunch Polybar
        if [[ -x "$REAL_HOME/.config/polybar/launch.sh" ]]; then
            "$REAL_HOME/.config/polybar/launch.sh" &>/dev/null &
            success "Relaunched Polybar"
        fi
    fi

    echo ""
    echo "=============================================="
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        success "Sync Completed Successfully! No errors."
    else
        warn "Sync Finished with Errors!"
        for err in "${ERRORS[@]}"; do
            echo "  - $err"
        done
    fi
    log "Backups stored in: $BACKUP_DIR"
    echo "=============================================="
}

main "$@"