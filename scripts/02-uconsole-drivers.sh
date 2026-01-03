#!/bin/bash
# =============================================================================
# uConsole Omarchy - Hardware Drivers Installation
# Installs uConsole-specific drivers and overlays
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

[ "$EUID" -ne 0 ] && error "Run as root"

WORK_DIR="/tmp/uconsole-drivers"
mkdir -p ${WORK_DIR}
cd ${WORK_DIR}

# =============================================================================
# ClockworkPi uConsole Kernel Modules and Overlays
# =============================================================================

log "Installing kernel headers..."
pacman -S --noconfirm --needed linux-rpi-headers dkms

log "Cloning uConsole kernel modules..."
if [ ! -d "uConsole" ]; then
    git clone https://github.com/clockworkpi/uConsole.git
fi

cd uConsole/Code

# -----------------------------------------------------------------------------
# Display Panel Driver
# -----------------------------------------------------------------------------
log "Building display panel driver..."
cd kernel/dts/overlays 2>/dev/null || cd ../kernel/dts/overlays 2>/dev/null || {
    warn "Display overlay directory not found, creating manual overlay..."
    mkdir -p /tmp/uconsole-overlay
    cd /tmp/uconsole-overlay

    cat > uconsole-display-overlay.dts << 'EOF'
/dts-v1/;
/plugin/;

/ {
    compatible = "brcm,bcm2711";

    fragment@0 {
        target = <&dsi1>;
        __overlay__ {
            #address-cells = <1>;
            #size-cells = <0>;
            status = "okay";

            panel@0 {
                compatible = "clockwork,cwd686";
                reg = <0>;
                reset-gpios = <&gpio 26 1>;
                backlight = <&backlight>;
                rotation = <90>;
            };
        };
    };

    fragment@1 {
        target-path = "/";
        __overlay__ {
            backlight: backlight {
                compatible = "gpio-backlight";
                gpios = <&gpio 18 0>;
                default-on;
            };
        };
    };
};
EOF
}

# Compile overlay if source exists
if [ -f "*.dts" ] || [ -f "uconsole-display-overlay.dts" ]; then
    log "Compiling device tree overlay..."
    for dts in *.dts; do
        dtc -@ -I dts -O dtb -o "/boot/overlays/${dts%.dts}.dtbo" "$dts" 2>/dev/null || true
    done
fi

cd ${WORK_DIR}

# -----------------------------------------------------------------------------
# Audio Driver (ES8388)
# -----------------------------------------------------------------------------
log "Setting up audio driver..."
cat > /etc/modprobe.d/uconsole-audio.conf << 'EOF'
# uConsole ES8388 Audio
options snd_bcm2835 enable_headphones=1 enable_hdmi=0
EOF

# ALSA configuration for ES8388
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

# -----------------------------------------------------------------------------
# Battery/Power Management (AXP228)
# -----------------------------------------------------------------------------
log "Setting up power management..."

cat > /etc/udev/rules.d/99-uconsole-battery.rules << 'EOF'
# uConsole AXP228 Power Management
SUBSYSTEM=="power_supply", ATTR{type}=="Battery", RUN+="/usr/local/bin/uconsole-battery-monitor"
EOF

cat > /usr/local/bin/uconsole-battery-monitor << 'BATTERY'
#!/bin/bash
# uConsole Battery Monitor

BATTERY_PATH="/sys/class/power_supply/axp20x-battery"

get_battery_percent() {
    if [ -f "${BATTERY_PATH}/capacity" ]; then
        cat "${BATTERY_PATH}/capacity"
    else
        echo "?"
    fi
}

get_charging_status() {
    if [ -f "${BATTERY_PATH}/status" ]; then
        cat "${BATTERY_PATH}/status"
    else
        echo "Unknown"
    fi
}

case "$1" in
    percent)
        get_battery_percent
        ;;
    status)
        get_charging_status
        ;;
    *)
        echo "Battery: $(get_battery_percent)% ($(get_charging_status))"
        ;;
esac
BATTERY
chmod +x /usr/local/bin/uconsole-battery-monitor

# Power button handler
cat > /etc/systemd/system/uconsole-power-button.service << 'EOF'
[Unit]
Description=uConsole Power Button Handler
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/uconsole-power-handler

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/bin/uconsole-power-handler << 'POWER'
#!/bin/bash
# Handle power button events

# Monitor GPIO for power button
GPIO_PIN=4

echo "$GPIO_PIN" > /sys/class/gpio/export 2>/dev/null || true
echo "in" > /sys/class/gpio/gpio${GPIO_PIN}/direction

while true; do
    if [ "$(cat /sys/class/gpio/gpio${GPIO_PIN}/value)" = "0" ]; then
        # Short press - do nothing, long press - shutdown
        sleep 0.5
        if [ "$(cat /sys/class/gpio/gpio${GPIO_PIN}/value)" = "0" ]; then
            sleep 2
            if [ "$(cat /sys/class/gpio/gpio${GPIO_PIN}/value)" = "0" ]; then
                systemctl poweroff
            fi
        fi
    fi
    sleep 0.1
done
POWER
chmod +x /usr/local/bin/uconsole-power-handler

# -----------------------------------------------------------------------------
# Keyboard Matrix
# -----------------------------------------------------------------------------
log "Configuring keyboard..."

# The uConsole keyboard is typically handled by the firmware
# but we can add custom key mappings
mkdir -p /etc/udev/hwdb.d

cat > /etc/udev/hwdb.d/90-uconsole-keyboard.hwdb << 'EOF'
# uConsole keyboard customizations
evdev:input:*
 KEYBOARD_KEY_70039=esc
EOF

systemd-hwdb update
udevadm trigger

# -----------------------------------------------------------------------------
# WiFi/Bluetooth
# -----------------------------------------------------------------------------
log "Configuring wireless..."
pacman -S --noconfirm --needed wireless-regdb iw wpa_supplicant

# Set regulatory domain
echo "options cfg80211 ieee80211_regdom=US" > /etc/modprobe.d/wireless.conf

# -----------------------------------------------------------------------------
# 4G Module (optional) - Basic setup, run 02a-modem-setup.sh for full config
# -----------------------------------------------------------------------------
log "Setting up 4G module support (if present)..."
pacman -S --noconfirm --needed \
    modemmanager \
    networkmanager \
    usb_modeswitch \
    libqmi \
    libmbim \
    mobile-broadband-provider-info

cat > /etc/udev/rules.d/99-uconsole-4g.rules << 'EOF'
# uConsole 4G Module (Quectel EG25-G)
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", ATTR{idProduct}=="0125", ENV{ID_MM_DEVICE_PROCESS}="1"
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", MODE="0666", GROUP="dialout"
EOF

systemctl enable ModemManager
systemctl enable NetworkManager

info "Run ./02a-modem-setup.sh for full modem configuration"

# -----------------------------------------------------------------------------
# GPIO Access
# -----------------------------------------------------------------------------
log "Setting up GPIO access..."
groupadd -f gpio

cat > /etc/udev/rules.d/99-gpio.rules << 'EOF'
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/platform/soc/*.gpio/gpio && chmod -R 770 /sys/devices/platform/soc/*.gpio/gpio'"
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="/bin/sh -c 'chown root:gpio /dev/$name && chmod 660 /dev/$name'"
EOF

# -----------------------------------------------------------------------------
# Firmware
# -----------------------------------------------------------------------------
log "Installing firmware packages..."
pacman -S --noconfirm --needed \
    linux-firmware \
    raspberrypi-firmware

# -----------------------------------------------------------------------------
# Update boot config with overlays
# -----------------------------------------------------------------------------
log "Updating boot configuration..."

# Add overlay references if not present
if ! grep -q "dtoverlay=vc4-kms-v3d" /boot/config.txt; then
    cat >> /boot/config.txt << 'EOF'

# Graphics
dtoverlay=vc4-kms-v3d,cma-512

# I2C for power management
dtoverlay=i2c-gpio,i2c_gpio_sda=10,i2c_gpio_scl=11
EOF
fi

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
log "Cleaning up..."
cd /
rm -rf ${WORK_DIR}

log "=============================================="
log "Hardware drivers installation complete!"
log ""
log "A reboot is recommended before continuing."
log "After reboot, run: ./03-install-hyprland.sh"
log "=============================================="
