# 🚀 MyBSPWM

Minimal, clean and fast BSPWM setup for Debian.

---

- BSPWM
- SXHKD
- Picom (Rounded Corners + Shadow)
- Alacritty
- Firefox ESR
- Brightness Control
- Touchpad (Tap to Click + Natural Scrolling)

---

# 📦 Installation

---

# 📁 Method 1: Git Clone (Recommended)

```bash
git clone https://github.com/krishnaharry208/mybspwm.git

cd mybspwm

chmod +x setup.sh

./setup.sh
```

✔ Best for editing or customizing configs  
✔ Full control over setup

---

# ⚡ Method 2: One Command (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/krishnaharry208/mybspwm/main/setup.sh -o setup.sh

chmod +x setup.sh

./setup.sh
```

✔ Fastest way to install  
✔ Perfect for fresh systems

---

# ⚙ What the Script Does

- Sets up Debian repositories
- Updates system packages
- Installs required packages:

  - bspwm
  - sxhkd
  - alacritty
  - picom
  - firefox-esr
  - brightnessctl
  - git
  - curl
  - xorg
  - xinit

- Installs and configures Picom
- Enables rounded corners
- Configures libinput touchpad settings
- Enables tap-to-click
- Enables natural scrolling
- Creates BSPWM config folders
- Sets `.xinitrc` to launch BSPWM
- Makes everything ready to use

---

# 🚀 How to Start

```bash
startx
```

This will launch BSPWM.

---

# ⌨ Default Keybinds

| Key | Action |
|------|--------|
| SUPER + ENTER | Open Terminal |
| SUPER + W | Open Firefox |
| SUPER + Q | Close Window |
| SUPER + H/J/K/L | Focus Window |
| SUPER + SHIFT + H/J/K/L | Move Window |
| SUPER + 1-0 | Switch Workspace |

---

# 📂 Structure

```text
mybspwm/
├── setup.sh
├── README.md
├── bspwm/
├── sxhkd/
└── picom/
```

---

# ✅ Requirements

- Fresh Debian install
- Internet connection
- User with sudo access

---

# 🖼 Recommended Extras

Optional packages you can install later:

- Polybar
- Eww
- Rofi
- Dunst
- Nitrogen
- Thunar

---

# 📜 License

MIT
