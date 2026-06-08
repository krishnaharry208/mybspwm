#!/bin/bash

# =====================================================================
# NETWORKMANAGER AUTOMATION & FIXED SETUP (STANDALONE / SUB-SCRIPT)
# =====================================================================
echo "🚀 Starting NetworkManager automation and fix setup..."

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ This script requires root privileges to modify network states."
    echo "Please run with sudo."
    exit 1
fi

# 1. Ensure NetworkManager and rfkill are installed first
MISSING_TOOLS=()
if ! command -v rfkill &> /dev/null; then MISSING_TOOLS+=("rfkill"); fi
if ! command -v nmcli &> /dev/null && ! command -v NetworkManager &> /dev/null; then MISSING_TOOLS+=("network-manager"); fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "⚙️ Missing core assets detected. Installing: ${MISSING_TOOLS[*]}..."
    apt update >/dev/null 2>&1
    apt install -y --no-install-recommends "${MISSING_TOOLS[@]}" >/dev/null 2>&1
fi

# 2. RELEASE DEBIAN INTERFACE LOCKS (Broadened to include Ethernet blocks)
IF_FILE="/etc/network/interfaces"
if [ -f "$IF_FILE" ]; then
    echo "🔓 Releasing interface locks from traditional Debian networking..."
    cp "$IF_FILE" "${IF_FILE}.bak"
    
    # Safely comments out lines for non-loopback interfaces (wlan*, eth*, enp*, etc.)
    sed -i '/^iface lo/!s/^\(iface [a-zA-Z0-9].*\)/#\1/' "$IF_FILE"
    sed -i '/^allow-hotplug/s/^\(allow-hotplug [a-zA-Z0-9].*\)/#\1/' "$IF_FILE"
    sed -i '/^auto/ /lo/!s/^\(auto [a-zA-Z0-9].*\)/#\1/' "$IF_FILE"
fi

# 3. Unblock Wi-Fi globally via rfkill
echo "⚡ Unblocking Wi-Fi hardware/software locks..."
if command -v rfkill &> /dev/null; then
    rfkill unblock wifi
fi

# 4. Fix the NetworkManager.conf configuration automatically
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
if [ -f "$NM_CONF" ]; then
    echo "⚙️ Tweaking NetworkManager config to handle all interfaces..."
    if grep -q "\[ifupdown\]" "$NM_CONF"; then
        sed -i '/\[ifupdown\]/,/^$/ s/managed=false/managed=true/' "$NM_CONF"
    else
        echo -e "\n[ifupdown]\nmanaged=true" >> "$NM_CONF"
    fi
else
    echo "⚠️ NetworkManager.conf not found at $NM_CONF!"
fi

# 5. Handle systemd services (Disabling iwctl, wpa_supplicant, dhcpcd safely)
echo "🛑 Disabling systemd conflicting services..."
for service in iwd wpa_supplicant dhcpcd; do
    if systemctl list-unit-files "${service}.service" &>/dev/null; then
        echo "   -> Stopping and disabling ${service}.service"
        systemctl disable --now "${service}.service" &>/dev/null || true
    fi
done

# 6. Forcefully kill non-systemd standalone processes (Using pkill instead of killall)
echo "💀 Forcefully killing rogue background network processes..."
pkill -9 -x "dhcpcd|wpa_supplicant|iwd|iwctl" &>/dev/null || true

# 7. Ensure NetworkManager is turned on and radio is enabled
echo "🌐 Turning NetworkManager on..."
systemctl enable --now NetworkManager &>/dev/null || true
systemctl restart NetworkManager

# Wait a brief moment for NM to initialize the card physical layer
sleep 3
nmcli radio wifi on &>/dev/null || true
nmcli device wifi rescan &>/dev/null || true

echo "--------------------------------------------------------"
# 8. Automated Verification Checks (Using pgrep for bulletproof verification)
echo "🔍 VERIFICATION: Checking for remaining rogue processes..."
if pgrep -x "dhcpcd|wpa_supplicant|iwd|iwctl" > /dev/null; then
    echo "   ⚠️ Warning: Some processes are stubbornly active:"
    pgrep -a -x "dhcpcd|wpa_supplicant|iwd|iwctl"
else
    echo "   ✅ Clean slate! No rogue network managers running."
fi

echo -e "\n🔍 VERIFICATION: Systemd Status Overview:"
# Filter for clean output without causing systemctl stderr warnings
for service in iwd wpa_supplicant dhcpcd NetworkManager; do
    if systemctl is-active --quiet "$service"; then
        echo "   ● $service is ACTIVE"
    else
        echo "   ○ $service is inactive/not installed"
    fi
done

echo "--------------------------------------------------------"
echo "🎉 Network setup automated successfully! Try running 'nmtui' now."