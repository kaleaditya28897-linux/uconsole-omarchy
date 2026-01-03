#!/bin/bash
# =============================================================================
# uConsole Omarchy - System Services
# Battery management, power optimization, and system services
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

USERNAME="cyber"
USER_HOME="/home/${USERNAME}"

# =============================================================================
# Power Management with TLP
# =============================================================================
log "Installing power management..."

pacman -S --noconfirm --needed \
    tlp \
    tlp-rdw \
    powertop \
    acpi \
    acpid

# TLP Configuration for uConsole
cat > /etc/tlp.conf << 'TLP'
# =============================================================================
# TLP Configuration for uConsole
# Optimized for battery life on ARM
# =============================================================================

TLP_ENABLE=1
TLP_DEFAULT_MODE=BAT
TLP_PERSISTENT_DEFAULT=0

# CPU
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=60
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Disk
DISK_IDLE_SECS_ON_AC=0
DISK_IDLE_SECS_ON_BAT=2
AHCI_RUNTIME_PM_ON_AC=on
AHCI_RUNTIME_PM_ON_BAT=auto
SATA_LINKPWR_ON_AC="med_power_with_dipm max_performance"
SATA_LINKPWR_ON_BAT="min_power med_power_with_dipm"

# PCIe
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto

# USB
USB_AUTOSUSPEND=1
USB_EXCLUDE_BTUSB=1
USB_EXCLUDE_PHONE=1

# WiFi
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Sound
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1

# Battery thresholds (if supported)
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
TLP

systemctl enable tlp
systemctl enable tlp-sleep

# =============================================================================
# Battery Monitoring Service
# =============================================================================
log "Creating battery monitoring service..."

cat > /usr/local/bin/uconsole-battery-daemon << 'BATDAEMON'
#!/bin/bash
# uConsole Battery Monitoring Daemon

BATTERY_PATH="/sys/class/power_supply"
LOW_THRESHOLD=15
CRITICAL_THRESHOLD=5
NOTIFIED_LOW=0
NOTIFIED_CRITICAL=0

get_battery_info() {
    local bat_path=""

    # Try different battery paths
    for path in "$BATTERY_PATH/axp20x-battery" "$BATTERY_PATH/BAT0" "$BATTERY_PATH/battery"; do
        if [ -d "$path" ]; then
            bat_path="$path"
            break
        fi
    done

    if [ -z "$bat_path" ]; then
        echo "unknown"
        return
    fi

    local capacity=$(cat "$bat_path/capacity" 2>/dev/null || echo "?")
    local status=$(cat "$bat_path/status" 2>/dev/null || echo "Unknown")

    echo "$capacity:$status"
}

notify_user() {
    local urgency="$1"
    local title="$2"
    local message="$3"

    # Try to notify via mako/notify-send
    if command -v notify-send &>/dev/null; then
        sudo -u cyber DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u cyber)/bus" \
            notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true
    fi

    # Also log
    logger -t battery-monitor "$title: $message"
}

while true; do
    info=$(get_battery_info)
    capacity="${info%%:*}"
    status="${info##*:}"

    if [ "$capacity" != "?" ] && [ "$capacity" != "unknown" ]; then
        # Reset notification flags when charging
        if [ "$status" = "Charging" ]; then
            NOTIFIED_LOW=0
            NOTIFIED_CRITICAL=0
        fi

        # Check battery levels
        if [ "$status" = "Discharging" ]; then
            if [ "$capacity" -le "$CRITICAL_THRESHOLD" ] && [ "$NOTIFIED_CRITICAL" -eq 0 ]; then
                notify_user "critical" "Battery Critical!" "Battery at ${capacity}% - Hibernating soon!"
                NOTIFIED_CRITICAL=1

                # Auto-hibernate at critical level
                sleep 30
                info=$(get_battery_info)
                new_cap="${info%%:*}"
                if [ "$new_cap" -le "$CRITICAL_THRESHOLD" ]; then
                    systemctl hibernate || systemctl suspend
                fi

            elif [ "$capacity" -le "$LOW_THRESHOLD" ] && [ "$NOTIFIED_LOW" -eq 0 ]; then
                notify_user "normal" "Battery Low" "Battery at ${capacity}% - Consider charging"
                NOTIFIED_LOW=1
            fi
        fi
    fi

    sleep 60
done
BATDAEMON
chmod +x /usr/local/bin/uconsole-battery-daemon

cat > /etc/systemd/system/uconsole-battery.service << 'BATSERVICE'
[Unit]
Description=uConsole Battery Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/uconsole-battery-daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
BATSERVICE

systemctl enable uconsole-battery

# =============================================================================
# Screen Brightness Control
# =============================================================================
log "Setting up brightness control..."

cat > /usr/local/bin/brightness << 'BRIGHTNESS'
#!/bin/bash
# uConsole brightness control

BRIGHTNESS_PATH="/sys/class/backlight"
BRIGHTNESS_FILE=""

# Find backlight device
for path in "$BRIGHTNESS_PATH"/*; do
    if [ -d "$path" ]; then
        BRIGHTNESS_FILE="$path/brightness"
        MAX_FILE="$path/max_brightness"
        break
    fi
done

if [ -z "$BRIGHTNESS_FILE" ]; then
    # Fallback to direct GPIO control
    echo "No backlight device found, using GPIO"
    exit 1
fi

MAX=$(cat "$MAX_FILE" 2>/dev/null || echo 255)
CURRENT=$(cat "$BRIGHTNESS_FILE" 2>/dev/null || echo 0)

case "$1" in
    up|+)
        NEW=$((CURRENT + MAX/10))
        [ $NEW -gt $MAX ] && NEW=$MAX
        echo $NEW > "$BRIGHTNESS_FILE"
        ;;
    down|-)
        NEW=$((CURRENT - MAX/10))
        [ $NEW -lt 1 ] && NEW=1
        echo $NEW > "$BRIGHTNESS_FILE"
        ;;
    set)
        if [ -n "$2" ]; then
            PERCENT=$2
            NEW=$((MAX * PERCENT / 100))
            echo $NEW > "$BRIGHTNESS_FILE"
        fi
        ;;
    get|"")
        PERCENT=$((CURRENT * 100 / MAX))
        echo "${PERCENT}%"
        ;;
    *)
        echo "Usage: brightness [up|down|set <percent>|get]"
        ;;
esac
BRIGHTNESS
chmod +x /usr/local/bin/brightness

# Allow users to control brightness
cat > /etc/udev/rules.d/90-backlight.rules << 'BACKLIGHT'
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
BACKLIGHT

# =============================================================================
# Lid/Suspend Handling
# =============================================================================
log "Configuring suspend/resume..."

cat > /etc/systemd/logind.conf.d/uconsole.conf << 'LOGIND'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=ignore
IdleAction=suspend
IdleActionSec=15min
LOGIND
mkdir -p /etc/systemd/logind.conf.d

# Resume hook for Hyprland
cat > /usr/lib/systemd/system-sleep/uconsole-resume << 'RESUME'
#!/bin/bash

case "$1" in
    post)
        # Give hardware time to initialize
        sleep 1

        # Reload WiFi if needed
        # modprobe -r brcmfmac && modprobe brcmfmac

        # Trigger display reconfiguration
        # wlr-randr --output DSI-1 --on
        ;;
esac
RESUME
chmod +x /usr/lib/systemd/system-sleep/uconsole-resume

# =============================================================================
# Hypridle Configuration (Screen lock/DPMS)
# =============================================================================
log "Configuring screen idle..."

mkdir -p ${USER_HOME}/.config/hypr

cat > ${USER_HOME}/.config/hypr/hypridle.conf << 'HYPRIDLE'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 150
    on-timeout = brightnessctl -s set 30%
    on-resume = brightnessctl -r
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 600
    on-timeout = systemctl suspend
}
HYPRIDLE

# Hyprlock configuration
cat > ${USER_HOME}/.config/hypr/hyprlock.conf << 'HYPRLOCK'
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 8
    noise = 0.0117
    contrast = 0.8916
    brightness = 0.7
    vibrancy = 0.1696
}

input-field {
    monitor =
    size = 250, 40
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.15
    dots_center = true
    outer_color = rgb(7aa2f7)
    inner_color = rgb(1a1b26)
    font_color = rgb(c0caf5)
    fade_on_empty = false
    placeholder_text = <i>Password...</i>
    hide_input = false
    position = 0, -20
    halign = center
    valign = center
}

label {
    monitor =
    text = $TIME
    color = rgb(c0caf5)
    font_size = 48
    font_family = JetBrainsMono Nerd Font
    position = 0, 80
    halign = center
    valign = center
}

label {
    monitor =
    text = $USER
    color = rgb(7aa2f7)
    font_size = 16
    font_family = JetBrainsMono Nerd Font
    position = 0, -70
    halign = center
    valign = center
}
HYPRLOCK

# =============================================================================
# System Performance Tuning
# =============================================================================
log "Applying system optimizations..."

cat > /etc/sysctl.d/99-uconsole.conf << 'SYSCTL'
# uConsole System Optimizations

# Virtual memory
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Network
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr

# File system
fs.inotify.max_user_watches = 524288
fs.file-max = 2097152

# Kernel
kernel.nmi_watchdog = 0
kernel.printk = 3 3 3 3
SYSCTL

# =============================================================================
# Zram Swap (for 8GB RAM)
# =============================================================================
log "Setting up zram swap..."

pacman -S --noconfirm --needed zram-generator

cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAM

# =============================================================================
# Journal Size Limit
# =============================================================================
log "Configuring journal..."

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf << 'JOURNAL'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
JOURNAL

# =============================================================================
# Auto-login (optional)
# =============================================================================
log "Setting up auto-login..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << AUTOLOGIN
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I \$TERM
AUTOLOGIN

# =============================================================================
# Set ownership
# =============================================================================
chown -R ${USERNAME}:${USERNAME} ${USER_HOME}/.config

log "=============================================="
log "System services setup complete!"
log ""
log "Installed/Configured:"
log "  - TLP power management"
log "  - Battery monitoring daemon"
log "  - Brightness control"
log "  - Suspend/resume handling"
log "  - Screen locking (hyprlock)"
log "  - Idle management (hypridle)"
log "  - Zram swap"
log "  - System optimizations"
log ""
log "Next: Run ./07-bootstrap.sh for final setup"
log "=============================================="
