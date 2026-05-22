#!/bin/bash

# =========================================================
# Minimal Debian BSPWM Auto Setup
# Installs:
# - bspwm
# - sxhkd
# - alacritty
# - firefox-esr
# - picom
# - brightnessctl
# - libinput touchpad config
# =========================================================

set -e

echo "======================================"
echo " Updating system"
echo "======================================"

sudo apt update && sudo apt upgrade -y

echo "======================================"
echo " Installing packages"
echo "======================================"

sudo apt install -y \
    bspwm \
    sxhkd \
    alacritty \
    firefox-esr \
    picom \
    brightnessctl \
    xorg \
    xinit \
    libinput-tools \
    xserver-xorg-input-libinput \
    feh \
    git \
    curl \
    unzip

echo "======================================"
echo " Creating config directories"
echo "======================================"

mkdir -p ~/.config/bspwm
mkdir -p ~/.config/sxhkd
mkdir -p ~/.config/picom
mkdir -p ~/.config/alacritty

echo "======================================"
echo " Copying default bspwm configs"
echo "======================================"

cp /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/
cp /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/

chmod +x ~/.config/bspwm/bspwmrc

echo "======================================"
echo " Writing custom bspwmrc"
echo "======================================"

cat > ~/.config/bspwm/bspwmrc << 'EOF'
#!/bin/sh

pgrep -x sxhkd > /dev/null || sxhkd &

bspc monitor -d I II III IV V VI VII VIII IX X

# Window settings
bspc config border_width         1
bspc config window_gap           1
bspc config top_padding          35

bspc config split_ratio          0.52
bspc config borderless_monocle   true
bspc config gapless_monocle      true

# Rounded corners
bspc config window_corner_radius 10

# Hover focus
bspc config focus_follows_pointer true

# Startup apps
picom --config ~/.config/picom/picom.conf &
EOF

chmod +x ~/.config/bspwm/bspwmrc

echo "======================================"
echo " Writing sxhkd config"
echo "======================================"

cat > ~/.config/sxhkd/sxhkdrc << 'EOF'
# Terminal
super + Return
    alacritty

# Firefox
super + w
    firefox-esr

# Close window
super + q
    bspc node -c

# Reload sxhkd
super + Escape
    pkill -USR1 -x sxhkd

# Focus windows
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Move windows
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# Desktop switch
super + {1-9,0}
    bspc desktop -f '^{1-10}'

# Move node to desktop
super + shift + {1-9,0}
    bspc node -d '^{1-10}'

# Brightness
XF86MonBrightnessUp
    brightnessctl set +5%

XF86MonBrightnessDown
    brightnessctl set 5%-
EOF

echo "======================================"
echo " Writing picom config"
echo "======================================"

cat > ~/.config/picom/picom.conf << 'EOF'
backend = "glx";
vsync = true;

corner-radius = 10;
rounded-corners-exclude = [
  "class_g = 'Polybar'"
];

shadow = true;
shadow-radius = 12;
shadow-opacity = 0.25;

fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
EOF

echo "======================================"
echo " Setting touchpad config"
echo "======================================"

sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/30-touchpad.conf > /dev/null << 'EOF'
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

echo "======================================"
echo " Setting bspwm session"
echo "======================================"

mkdir -p ~/.config

cat > ~/.xinitrc << 'EOF'
exec bspwm
EOF

echo "======================================"
echo " Installation Complete"
echo "======================================"

echo ""
echo "Start X with:"
echo "startx"
echo ""
echo "Done."
