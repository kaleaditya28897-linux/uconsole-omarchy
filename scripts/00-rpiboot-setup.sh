#!/bin/bash
# =============================================================================
# uConsole Omarchy - rpiboot Setup
# Required for flashing eMMC on CM4/CM5
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

echo ""
echo "=================================="
echo " rpiboot Setup for eMMC Flashing"
echo "=================================="
echo ""

# Check if already installed
if command -v rpiboot &>/dev/null; then
    log "rpiboot is already installed"
    rpiboot --help | head -5
    echo ""
    info "To flash eMMC:"
    info "  1. Connect uConsole via USB with boot switch set to USB"
    info "  2. Run: sudo rpiboot"
    info "  3. Wait for eMMC to appear as /dev/sdX"
    info "  4. Run: sudo ./01-install.sh -s emmc /dev/sdX"
    exit 0
fi

[ "$EUID" -ne 0 ] && error "Run as root to install rpiboot"

# Detect distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    DISTRO="unknown"
fi

log "Detected distro: $DISTRO"

case "$DISTRO" in
    arch|manjaro|endeavouros)
        log "Installing rpiboot from AUR..."
        if command -v yay &>/dev/null; then
            sudo -u $(logname) yay -S --noconfirm rpiboot
        elif command -v paru &>/dev/null; then
            sudo -u $(logname) paru -S --noconfirm rpiboot
        else
            warn "No AUR helper found. Installing manually..."
            pacman -S --noconfirm --needed git libusb
            cd /tmp
            git clone https://github.com/raspberrypi/usbboot
            cd usbboot
            make
            cp rpiboot /usr/local/bin/
            log "Installed to /usr/local/bin/rpiboot"
        fi
        ;;

    ubuntu|debian|raspbian|linuxmint|pop)
        log "Installing rpiboot..."
        apt-get update
        apt-get install -y git libusb-1.0-0-dev pkg-config build-essential
        cd /tmp
        git clone --depth=1 https://github.com/raspberrypi/usbboot
        cd usbboot
        make
        cp rpiboot /usr/local/bin/
        log "Installed to /usr/local/bin/rpiboot"
        ;;

    fedora|rhel|centos)
        log "Installing rpiboot..."
        dnf install -y git libusb1-devel make gcc
        cd /tmp
        git clone --depth=1 https://github.com/raspberrypi/usbboot
        cd usbboot
        make
        cp rpiboot /usr/local/bin/
        log "Installed to /usr/local/bin/rpiboot"
        ;;

    *)
        warn "Unknown distro. Installing from source..."
        cd /tmp
        git clone --depth=1 https://github.com/raspberrypi/usbboot
        cd usbboot
        make
        cp rpiboot /usr/local/bin/
        log "Installed to /usr/local/bin/rpiboot"
        ;;
esac

# Create udev rules for CM4/CM5
log "Creating udev rules..."
cat > /etc/udev/rules.d/99-rpiboot.rules << 'EOF'
# Raspberry Pi CM4/CM5 in USB boot mode
SUBSYSTEM=="usb", ATTR{idVendor}=="0a5c", ATTR{idProduct}=="2764", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="0a5c", ATTR{idProduct}=="2763", MODE="0666"
# BCM2712 (CM5)
SUBSYSTEM=="usb", ATTR{idVendor}=="0a5c", ATTR{idProduct}=="2712", MODE="0666"
EOF

udevadm control --reload-rules
udevadm trigger

log "rpiboot installed successfully!"
echo ""
echo "=============================================="
echo " How to flash eMMC:"
echo "=============================================="
echo ""
echo "1. Set the boot switch on CM4/CM5 carrier to USB boot mode"
echo "   (Check your uConsole documentation for switch location)"
echo ""
echo "2. Connect uConsole to your computer via USB-C"
echo ""
echo "3. Run rpiboot to expose eMMC as mass storage:"
echo "   sudo rpiboot"
echo ""
echo "4. Wait for the eMMC to appear (check with 'lsblk')"
echo "   It will show up as /dev/sdX"
echo ""
echo "5. Run the installer:"
echo "   sudo ./01-install.sh -m cm4 -s emmc /dev/sdX"
echo ""
echo "6. After flashing, disconnect USB and flip boot switch back"
echo ""
