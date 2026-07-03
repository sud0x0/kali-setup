#!/bin/bash

# Install the most important Kali tools & configuration

set -e

# Check if running as root/sudo - this will mess up config file locations
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root or with sudo!"
    echo "Run it as your normal user: ./kali-tools-setup.sh"
    exit 1
fi

echo "=== Install the Most Important Kali Tools ==="
echo ""

# Colours for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ----------------------------
# Install Tools
# ----------------------------
echo -e "${GREEN}[1/3] Installing base tools...${NC}"
sudo apt update
sudo apt install -y openvpn curl firefox-esr golang remmina
sudo apt install -y python3-requests python3-scapy

# These are my everyday choices. Please make sure to add yours.
echo -e "${GREEN}[2/3] Installing pentesting tools...${NC}"
sudo apt install -y nmap hydra wireshark metasploit-framework bloodhound sqlmap ffuf impacket-scripts netcat-traditional responder john hashcat netexec tcpdump burpsuite cewl dnsrecon nuclei evil-winrm sslscan socat arp-scan proxychains4 seclists

# Install VS Code
ARCH=$(uname -m)

if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "Detected ARM64 architecture"
    curl -L "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64" -o /tmp/vscode.deb
elif [ "$ARCH" = "x86_64" ]; then
    echo "Detected x86_64 architecture"
    curl -L "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" -o /tmp/vscode.deb
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

sudo dpkg -i /tmp/vscode.deb
sudo apt install -f -y

# ----------------------------
# Configure Go environment
# ----------------------------
echo -e "${GREEN}[3/3] Configuring Go environment...${NC}"

# Add Go paths to zshrc if not already present
if ! grep -q "GOROOT" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# Go environment
export GOROOT=/usr/lib/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
EOF
    echo "Go environment added to ~/.zshrc"
else
    echo "Go environment already configured in ~/.zshrc"
fi

# Also add to bashrc in case bash is used
if ! grep -q "GOROOT" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# Go environment
export GOROOT=/usr/lib/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
EOF
    echo "Go environment added to ~/.bashrc"
fi

# Create Go workspace directory
mkdir -p ~/go/{bin,src,pkg}

# ----------------------------
# Setup Passwordless Sudo
# ----------------------------

SUDOERS_FILE="/etc/sudoers.d/$USER"
echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee $SUDOERS_FILE > /dev/null
sudo chmod 0440 $SUDOERS_FILE
sudo visudo -c -f $SUDOERS_FILE || sudo rm $SUDOERS_FILE

# ----------------------------
# Done
# ----------------------------
echo ""
echo "=== Setup Complete! ==="
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Reload shell: source ~/.zshrc"
echo "2. Setup BloodHound: sudo bloodhound-setup"
echo "3. Start Metasploit DB: sudo msfdb init"
echo "4. Install Foxy Proxy Standard extension in firefox and configure burp certificate"
echo ""
echo "Enjoy your tools!"