#!/bin/bash
# =============================================================================
# uConsole Omarchy - Hardware Drivers Installation
# Configures uConsole-specific hardware support
#
# NOTE: If using the recommended hybrid installation (PotatoMania's base image),
# the kernel and core drivers are already installed. This script adds additional
# configuration and utilities.
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

[ "$EUID" -ne 0 ] && error "Run as root"

echo ""
echo "=============================================="
echo " uConsole Hardware Configuration"
echo "=============================================="
echo ""

# =============================================================================
# Detect if running on pre-configured base image
# =============================================================================
detect_base_image() {
    # Check for PotatoMania's image markers
    if pacman -Qs linux-uconsole &>/dev/null; then
        echo "potatomania"
        return
    fi

    # Check for uConsole overlays in boot
    if [ -f /boot/overlays/devterm-panel-uc.dtbo ] || \
       [ -f /boot/overlays/uconsole.dtbo ]; then
        echo "preconfigured"
        return
    fi

    # Check if display is working (DSI panel loaded)
    if dmesg | grep -qi "panel-clockwork\|cwu50\|cwd686" 2>/dev/null; then
        echo "preconfigured"
        return
    fi

    echo "manual"
}

BASE_IMAGE=$(detect_base_image)
log "Detected base image type: ${BASE_IMAGE}"

# =============================================================================
# Detect Module Type (CM4 or CM5)
# =============================================================================
detect_module() {
    # Check /etc/uconsole-release first (set by manual installer)
    if [ -f /etc/uconsole-release ]; then
        source /etc/uconsole-release
        echo "$UCONSOLE_MODULE"
        return
    fi

    # Detect by SoC
    if grep -q "BCM2712" /proc/cpuinfo 2>/dev/null; then
        echo "cm5"
    elif grep -q "BCM2711" /proc/cpuinfo 2>/dev/null; then
        echo "cm4"
    else
        echo "cm4"  # Default to CM4
    fi
}

MODULE=$(detect_module)
log "Detected module: ${MODULE^^}"

# =============================================================================
# Skip kernel installation if using pre-configured image
# =============================================================================
if [ "$BASE_IMAGE" = "potatomania" ] || [ "$BASE_IMAGE" = "preconfigured" ]; then
    info "Pre-configured base image detected!"
    info "Skipping kernel/overlay installation (already present)"
    echo ""
else
    warn "Manual installation detected - kernel setup may be needed"
    warn "Consider using the recommended hybrid installation instead"
    warn "See README.md for details"
    echo ""

    # Original kernel installation logic for manual installs
    WORK_DIR="/tmp/uconsole-drivers"
    mkdir -p ${WORK_DIR}
    cd ${WORK_DIR}

    log "Installing kernel headers..."
    if [ "$MODULE" = "cm5" ]; then
        pacman -S --noconfirm --needed linux-rpi-16k-headers dkms 2>/dev/null || \
        pacman -S --noconfirm --needed linux-rpi-headers dkms
    else
        pacman -S --noconfirm --needed linux-rpi-headers dkms 2>/dev/null || true
    fi

    log "Cloning uConsole kernel modules..."
    if [ ! -d "uConsole" ]; then
        git clone https://github.com/clockworkpi/uConsole.git
    fi

    # Try to build overlays from source
    cd uConsole/Code
    if [ -d "kernel/dts/overlays" ]; then
        log "Building device tree overlays..."
        cd kernel/dts/overlays
        for dts in *.dts; do
            if [ -f "$dts" ]; then
                dtc -@ -I dts -O dtb -o "/boot/overlays/${dts%.dts}.dtbo" "$dts" 2>/dev/null || true
            fi
        done
    fi

    cd /
    rm -rf ${WORK_DIR}
fi

# =============================================================================
# Audio Configuration (applies to all installations)
# =============================================================================
log "Configuring audio..."

cat > /etc/modprobe.d/uconsole-audio.conf << 'EOF'
# uConsole ES8388 Audio
options snd_bcm2835 enable_headphones=1 enable_hdmi=0
EOF

# ALSA configuration
cat > /etc/asound.conf << 'EOF'
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
EOF

# =============================================================================
# Battery/Power Management Utilities
# =============================================================================
log "Setting up power management utilities..."

# Battery monitor script
cat > /usr/local/bin/uconsole-battery << 'BATTERY'
#!/bin/bash
# uConsole Battery Monitor

# Try different battery paths
BATTERY_PATHS=(
    "/sys/class/power_supply/axp20x-battery"
    "/sys/class/power_supply/BAT0"
    "/sys/class/power_supply/battery"
)

BATTERY_PATH=""
for path in "${BATTERY_PATHS[@]}"; do
    if [ -d "$path" ]; then
        BATTERY_PATH="$path"
        break
    fi
done

if [ -z "$BATTERY_PATH" ]; then
    echo "Battery not found"
    exit 1
fi

get_percent() {
    if [ -f "${BATTERY_PATH}/capacity" ]; then
        cat "${BATTERY_PATH}/capacity"
    else
        echo "?"
    fi
}

get_status() {
    if [ -f "${BATTERY_PATH}/status" ]; then
        cat "${BATTERY_PATH}/status"
    else
        echo "Unknown"
    fi
}

get_voltage() {
    if [ -f "${BATTERY_PATH}/voltage_now" ]; then
        echo "scale=2; $(cat ${BATTERY_PATH}/voltage_now) / 1000000" | bc
    else
        echo "?"
    fi
}

get_current() {
    if [ -f "${BATTERY_PATH}/current_now" ]; then
        echo "scale=0; $(cat ${BATTERY_PATH}/current_now) / 1000" | bc
    else
        echo "?"
    fi
}

case "$1" in
    percent|p)
        get_percent
        ;;
    status|s)
        get_status
        ;;
    voltage|v)
        get_voltage
        ;;
    current|c)
        get_current
        ;;
    json|j)
        echo "{\"percent\": $(get_percent), \"status\": \"$(get_status)\", \"voltage\": $(get_voltage), \"current\": $(get_current)}"
        ;;
    *)
        echo "Battery: $(get_percent)% ($(get_status))"
        echo "Voltage: $(get_voltage)V"
        echo "Current: $(get_current)mA"
        ;;
esac
BATTERY
chmod +x /usr/local/bin/uconsole-battery

# Backward compatibility
ln -sf /usr/local/bin/uconsole-battery /usr/local/bin/uconsole-battery-monitor

# =============================================================================
# Keyboard Configuration
# =============================================================================
log "Configuring keyboard..."

mkdir -p /etc/udev/hwdb.d

cat > /etc/udev/hwdb.d/90-uconsole-keyboard.hwdb << 'EOF'
# uConsole keyboard customizations
# Caps Lock as Escape (optional, comment out if not wanted)
evdev:input:*
 KEYBOARD_KEY_70039=esc
EOF

systemd-hwdb update
udevadm trigger

# =============================================================================
# WiFi/Bluetooth Configuration
# =============================================================================
log "Configuring wireless..."

pacman -S --noconfirm --needed wireless-regdb iw 2>/dev/null || true

# Set regulatory domain (change US to your country code if needed)
echo "options cfg80211 ieee80211_regdom=US" > /etc/modprobe.d/wireless.conf

# =============================================================================
# GPIO Access Configuration
# =============================================================================
log "Setting up GPIO access..."

groupadd -f gpio 2>/dev/null || true

cat > /etc/udev/rules.d/99-gpio.rules << 'EOF'
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/platform/soc/*.gpio/gpio && chmod -R 770 /sys/devices/platform/soc/*.gpio/gpio'"
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="/bin/sh -c 'chown root:gpio /dev/$name && chmod 660 /dev/$name'"
EOF

# =============================================================================
# udev Rules for uConsole Hardware
# =============================================================================
log "Installing udev rules..."

# Battery udev rule
cat > /etc/udev/rules.d/99-uconsole-battery.rules << 'EOF'
# uConsole AXP228 Power Management
SUBSYSTEM=="power_supply", ATTR{type}=="Battery", TAG+="systemd"
EOF

# 4G Module udev rule (for those who have it)
cat > /etc/udev/rules.d/99-uconsole-4g.rules << 'EOF'
# uConsole 4G Module (Quectel EG25-G)
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", ATTR{idProduct}=="0125", ENV{ID_MM_DEVICE_PROCESS}="1"
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", MODE="0666", GROUP="dialout"
EOF

udevadm control --reload-rules
udevadm trigger

# =============================================================================
# Install Firmware (if not present)
# =============================================================================
log "Checking firmware packages..."

pacman -S --noconfirm --needed linux-firmware 2>/dev/null || true

# =============================================================================
# Create system info file
# =============================================================================
if [ ! -f /etc/uconsole-release ]; then
    cat > /etc/uconsole-release << EOF
UCONSOLE_MODULE=${MODULE}
UCONSOLE_BASE_IMAGE=${BASE_IMAGE}
SETUP_DATE=$(date -I)
EOF
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log "=============================================="
log "Hardware configuration complete!"
log ""
if [ "$BASE_IMAGE" = "manual" ]; then
    warn "Manual installation detected."
    warn "You may need to add uConsole overlays to /boot/config.txt"
    warn "Required overlays: devterm-pmu, devterm-panel-uc, devterm-misc"
    echo ""
fi
log "Utilities installed:"
log "  uconsole-battery  - Check battery status"
log ""
log "Next steps:"
log "  1. Reboot if this is the first run"
log "  2. Run: ./02a-modem-setup.sh (if you have 4G modem)"
log "  3. Run: ./03-install-hyprland.sh"
log "=============================================="
