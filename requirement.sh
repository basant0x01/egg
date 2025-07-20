#!/bin/bash

# requirement.sh - Installs required dependencies for egg.sh
# Author: Auto-generated for egg.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[+] Checking and installing required dependencies...${NC}"

# List of required tools
REQUIRED_TOOLS=(jq curl perl sed awk grep)

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install function for Debian/Ubuntu
install_debian() {
    sudo apt-get update
    sudo apt-get install -y "$@"
}

# Install function for RedHat/CentOS/Fedora
install_rhel() {
    sudo yum install -y "$@"
}

# Install function for Arch
install_arch() {
    sudo pacman -Sy --noconfirm "$@"
}

# Install missing tools
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command_exists "$tool"; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${GREEN}[+] All dependencies are already installed.${NC}"
    exit 0
fi

echo -e "${RED}[*] Missing tools: ${MISSING_TOOLS[*]}${NC}"

# Detect OS and install
if [ -f /etc/debian_version ]; then
    install_debian "${MISSING_TOOLS[@]}"
elif [ -f /etc/redhat-release ]; then
    install_rhel "${MISSING_TOOLS[@]}"
elif command_exists pacman; then
    install_arch "${MISSING_TOOLS[@]}"
else
    echo -e "${RED}[!] Unsupported or undetected package manager. Please install manually:${NC} ${MISSING_TOOLS[*]}"
    exit 1
fi

echo -e "${GREEN}[+] Installation complete.${NC}"
