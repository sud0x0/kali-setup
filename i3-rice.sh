#!/bin/bash
# i3 Rice Setup Script for Kali Linux (Minimal Install)

set -uo pipefail

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

WARNINGS=()

warn() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
    WARNINGS+=("$*")
}

die() {
    echo -e "${RED}FATAL: $*${NC}" >&2
    exit 1
}

# Check if running as root/sudo - this will mess up config file locations
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root or with sudo!"
    echo "Run it as your normal user: ./i3-rice.sh"
    exit 1
fi

echo "=== i3 Rice Setup Script for Kali Linux ==="
echo ""

# ----------------------------
# Install Packages
# ----------------------------
echo -e "${GREEN}[1/9] Installing packages...${NC}"

sudo apt update || die "apt update failed. Check networking and /etc/apt/sources.list"

sudo apt install -y xserver-xorg xserver-xorg-input-all i3 xinit lightdm lightdm-gtk-greeter \
    || die "Core package install failed. Nothing below will work without these."

sudo apt install -y thunar picom feh lxappearance rofi polybar vim alacritty \
    || warn "Optional package install failed. Some rice components will be missing."

# ----------------------------
# Enable Display Manager
# ----------------------------
echo -e "${GREEN}[2/9] Enabling LightDM...${NC}"

sudo systemctl enable lightdm || warn "Could not enable the lightdm service"

# Enabling the unit is not enough. On a minimal install the default systemd
# target is multi-user.target, which never starts anything graphical.
sudo systemctl set-default graphical.target || warn "Could not set graphical.target as the default"

echo "exec i3" > ~/.xinitrc || warn "Could not write ~/.xinitrc"

# ----------------------------
# Wallpaper Setup
# ----------------------------
echo -e "${GREEN}[3/9] Setting up wallpaper...${NC}"
mkdir -p ~/.wallpaper

if [ -f "kali.jpg" ]; then
    cp kali.jpg ~/.wallpaper/ || warn "Could not copy wallpaper"
    echo "Wallpaper copied to ~/.wallpaper/"
else
    echo -e "${YELLOW}Note: Place your wallpaper as ~/.wallpaper/kali.jpg manually${NC}"
fi

# ----------------------------
# i3 Config
# ----------------------------
echo -e "${GREEN}[4/9] Configuring i3...${NC}"
mkdir -p ~/.config/i3

# Copy default config if none exists
if [ ! -f ~/.config/i3/config ]; then
    if [ -f /etc/i3/config ]; then
        cp /etc/i3/config ~/.config/i3/config
    else
        warn "/etc/i3/config not found. i3 may not be installed correctly."
    fi
fi

if [ -f ~/.config/i3/config ]; then
    # Backup existing config
    cp ~/.config/i3/config ~/.config/i3/config.backup
    echo "Backed up existing i3 config"

    # Comment out default bar section
    sed -i '/^bar {/,/^}/s/^/#/' ~/.config/i3/config

    # Comment out ALL lines containing dmenu (handles all dmenu bindings)
    sed -i '/dmenu/s/^/#/' ~/.config/i3/config

    # Comment out the "focus child" binding on Mod1+d to prevent conflict
    sed -i 's/^bindsym Mod1+d focus child/#bindsym Mod1+d focus child/' ~/.config/i3/config
    sed -i 's/^#bindsym Mod1+d focus child/#bindsym Mod1+d focus child/' ~/.config/i3/config

    if grep -q '^# Custom Rice Settings$' ~/.config/i3/config; then
        echo "Custom rice settings already present in i3 config. Skipping append."
    else
    cat >> ~/.config/i3/config << 'EOF'

# ============================================
# Custom Rice Settings
# ============================================

# Gaps
gaps inner 10
gaps outer 5

# Remove window borders and title bars
default_border pixel 0
default_floating_border pixel 0
for_window [class=".*"] border pixel 0

# Wallpaper
exec_always --no-startup-id feh --bg-scale ~/.wallpaper/kali.jpg

# Rofi instead of dmenu (using Mod1 explicitly)
bindsym Mod1+d exec --no-startup-id rofi -show drun -show-icons

# Polybar
exec_always --no-startup-id ~/.config/polybar/launch.sh

# Picom compositor
exec_always --no-startup-id picom -b --backend xrender
EOF
    fi

    echo "i3 config updated"
else
    warn "No i3 config to modify. Skipped i3 configuration."
fi

# ----------------------------
# Rofi Config
# ----------------------------
echo -e "${GREEN}[5/9] Configuring Rofi...${NC}"
mkdir -p ~/.config/rofi
rofi -dump-config > ~/.config/rofi/config.rasi 2>/dev/null || warn "Could not dump the Rofi config"
echo -e "${YELLOW}Run 'rofi-theme-selector' later to choose a theme (Material by Tomaszal recommended)${NC}"

# ----------------------------
# Polybar Config
# ----------------------------
echo -e "${GREEN}[6/9] Configuring Polybar...${NC}"
mkdir -p ~/.config/polybar
mkdir -p ~/.config/polybar/scripts

# Always start fresh - copy example config
if [ -f /usr/share/doc/polybar/examples/config.ini ]; then
    cp /usr/share/doc/polybar/examples/config.ini ~/.config/polybar/config.ini
else
    warn "Polybar example config not found at /usr/share/doc/polybar/examples/config.ini"
fi

# Create network script first
cat > ~/.config/polybar/scripts/network.sh << 'EOF'
#!/bin/bash
# Show VPN IP if connected, otherwise show eth0 IP
VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
ETH_IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -n "$VPN_IP" ]; then
    echo "VPN $VPN_IP"
elif [ -n "$ETH_IP" ]; then
    echo "eth0 $ETH_IP"
else
    echo "No network"
fi
EOF
chmod +x ~/.config/polybar/scripts/network.sh

if [ -f ~/.config/polybar/config.ini ]; then
    # Remove xwindow from modules list
    sed -i 's/ xwindow//g' ~/.config/polybar/config.ini

    # Remove xkeyboard from modules list
    sed -i 's/ xkeyboard / /g' ~/.config/polybar/config.ini

    # Replace eth with network in modules-right
    sed -i 's/ eth / network /g' ~/.config/polybar/config.ini

    # Add custom network module.
    # Guarded by a marker so re-running does not define the module twice.
    if grep -q '^\[module/network\]$' ~/.config/polybar/config.ini; then
        echo "Network module already present in Polybar config. Skipping append."
    else
    cat >> ~/.config/polybar/config.ini << 'EOF'

[module/network]
type = custom/script
exec = ~/.config/polybar/scripts/network.sh
interval = 5
EOF
    fi
else
    warn "No Polybar config.ini to modify. The bar will not start."
fi

# Create launch script
cat > ~/.config/polybar/launch.sh << 'EOF'
#!/bin/bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done
polybar example 2>&1 | tee -a /tmp/polybar.log & disown
EOF
chmod +x ~/.config/polybar/launch.sh

echo "Polybar configured"

# ----------------------------
# Alacritty Config
# ----------------------------
echo -e "${GREEN}[7/9] Configuring Alacritty...${NC}"
mkdir -p ~/.config/alacritty
cat > ~/.config/alacritty/alacritty.toml << 'EOF'
[font]
size = 14.0

[font.normal]
family = "monospace"
EOF
echo "Alacritty configured"

# ----------------------------
# GTK Dark Theme
# ----------------------------
echo -e "${GREEN}[8/9] Configuring GTK dark theme...${NC}"
mkdir -p ~/.config/gtk-3.0
cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=Kali-Dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=0
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintmedium
EOF
echo "GTK theme configured"

# ----------------------------
# Picom Config
# ----------------------------
echo -e "${GREEN}[9/9] Configuring Picom...${NC}"
mkdir -p ~/.config/picom
cat > ~/.config/picom/picom.conf << 'EOF'
backend = "xrender";
opacity-rule = [
    "90:class_g = 'Alacritty'",
    "90:class_g = 'Thunar'",
    "95:class_g = 'Rofi'"
];
inactive-opacity = 0.85;
active-opacity = 0.95;
frame-opacity = 0.9;
EOF
echo "Picom configured"

# ----------------------------
# Done
# ----------------------------
echo ""
if [ ${#WARNINGS[@]} -eq 0 ]; then
    echo -e "${GREEN}=== Setup Complete! ===${NC}"
else
    echo -e "${YELLOW}=== Setup finished with ${#WARNINGS[@]} warning(s) ===${NC}"
    for w in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}  - $w${NC}"
    done
fi
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. After login, run: rofi-theme-selector (Material by Tomaszal recommended)"
echo ""
echo "Keybindings:"
echo "  Alt+d          - Open Rofi launcher"
echo "  Alt+Enter      - Open terminal"
echo "  Alt+Shift+q    - Close window"
echo "  Alt+Shift+r    - Reload i3"
echo "  Alt+{1,2,3,..} - Change workspace"
echo "  Alt+v          - Next window below (split)"
echo "  Alt+h          - Next window right (split)"
echo ""
echo "Enjoy your rice!"