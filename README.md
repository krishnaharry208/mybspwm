
---
# 🚀 Debian BSPWM Setup
A fast, lightweight, and modern **Debian desktop environment** powered by **BSPWM**.
---
A fully automated installation script to deploy a clean, fast, and keyboard-driven BSPWM (Binary Space Partitioning Window Manager) environment on Debian/Ubuntu systems.

## ✨ Features
* Interactive installer
* Fully automated setup
* BSPWM tiling window manager
* SXHKD keyboard shortcuts

### 🎨 Appearance

* Polybar status bar
* Rofi application launcher
* Picom compositor
* JetBrainsMono & FiraCode Nerd Fonts

### ⚙️ Software Selection

| Category        | Options                            |
| --------------- | ---------------------------------- |
>| 🖥️ Terminal    | Alacritty • Kitty                  |

>| 📁 File Manager | Thunar • Dolphin • Nautilus        |

>| 🌐 Browser      | Firefox • Brave • Thorium • Chrome |

## 📦 Included

* BSPWM
* SXHKD
* Polybar
* Rofi
* Picom
* Dunst
* Feh
* Nerd Fonts
* Themes & Icons

## 🎯 Built For
>Developers • Power Users • Minimalists

> No bloat. No distractions. Just a fast and productive desktop.

> Clean • Fast • Productive
---
---
### Desktop Preview
<img src="screenshots/Desktop.png" width="100%">

---
---
### Rofi Launcher
<img src="screenshots/rofi.png" width="100%">

---
---
### Alacritty
<img src="screenshots/Alacritty.png" width="100%">

---
---
### Directories Structure
<img src="screenshots/Directory Structure.png" width="100%">

---
---
## Keybinding (sxhkd)
<img src="screenshots/sxhkd1.png" width="100%">

---
---

---
---

<img src="screenshots/sxhkd2.png" width="100%">

---
---

---
---

<img src="screenshots/sxhkd3.png" width="100%">

---
---

# 📁 Method 1: Git Clone (Recommended)
---
```bash
git clone https://github.com/mycode205/mybspwm.git
cd mybspwm
bash install.sh

```
---
# ⚡ Method 2: Quick Install
---
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mycode205/mybspwm/main/install.sh)

```
---
---




---
# This one is when the rofi and rofi theme selector icon not showing that time use this Command
---
```

# 1. Force create the applications folder structure
mkdir -p ~/.local/share/applications/

# 2. Write the fresh, clean override file directly
cat << 'EOF' > ~/.local/share/applications/rofi.desktop
[Desktop Entry]
Version=1.0
Name=Rofi
Comment=A window switcher, run dialog and dmenu replacement
Exec=rofi -show drun
Terminal=false
Type=Application
Icon=system-run
Categories=System;Utility;
EOF

# 3. Create a clean override for the theme selector as well
cat << 'EOF' > ~/.local/share/applications/rofi-theme-selector.desktop
[Desktop Entry]
Version=1.0
Name=Rofi Theme Selector
Comment=Choose a theme for Rofi
Exec=rofi-theme-selector
Terminal=false
Type=Application
Icon=preferences-system
Categories=System;Utility;
EOF

# 4. Clear the rofi memory runtime cache dump
rm -f ~/.cache/rofi*.cache

# 5. Tell X11/Debian to immediately rebuild your local launcher app database
update-desktop-database ~/.local/share/applications/

# 6. Shut down any stuck background instances
killall rofi



```
---


✔ ⚡ Lightweight. Elegant. Productive.  

---