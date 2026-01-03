#!/bin/bash
# =============================================================================
# uConsole Omarchy - 4G Modem Setup
# ModemManager + NetworkManager configuration for Quectel EG25-G
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
# Install ModemManager and NetworkManager
# =============================================================================
log "Installing modem and network management packages..."

pacman -S --noconfirm --needed \
    modemmanager \
    networkmanager \
    networkmanager-openconnect \
    networkmanager-openvpn \
    networkmanager-pptp \
    networkmanager-vpnc \
    nm-connection-editor \
    network-manager-applet \
    mobile-broadband-provider-info \
    usb_modeswitch \
    libqmi \
    libmbim

# =============================================================================
# USB Modeswitch Configuration for Quectel EG25-G
# =============================================================================
log "Configuring USB modeswitch for 4G modem..."

mkdir -p /etc/usb_modeswitch.d

# Quectel EG25-G configuration
cat > /etc/usb_modeswitch.d/2c7c:0125 << 'MODESWITCH'
# Quectel EG25-G 4G LTE Modem
TargetVendor=0x2c7c
TargetProduct=0x0125
MessageContent="5553424312345678000000000000061b000000020000000000000000000000"
MODESWITCH

# =============================================================================
# Udev Rules for Modem
# =============================================================================
log "Creating udev rules for modem..."

cat > /etc/udev/rules.d/77-mm-quectel.rules << 'UDEV'
# Quectel EG25-G 4G Modem
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", ATTR{idProduct}=="0125", ENV{ID_MM_DEVICE_PROCESS}="1"

# Set proper permissions
ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", MODE="0666", GROUP="dialout"

# QMI interface
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_MM_PORT_TYPE_QMI}="1"
UDEV

# Also handle other common LTE modems
cat > /etc/udev/rules.d/77-mm-simcom.rules << 'UDEV'
# SIMCom modems (SIM7600, etc)
ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="1e0e", ENV{ID_MM_DEVICE_PROCESS}="1"
UDEV

# =============================================================================
# NetworkManager Configuration
# =============================================================================
log "Configuring NetworkManager..."

mkdir -p /etc/NetworkManager/conf.d

# Main configuration
cat > /etc/NetworkManager/NetworkManager.conf << 'NMCONF'
[main]
plugins=keyfile
dns=systemd-resolved
systemd-resolved=true

[keyfile]
unmanaged-devices=none

[device]
wifi.scan-rand-mac-address=yes
wifi.backend=wpa_supplicant

[connection]
wifi.powersave=2
connection.llmnr=no
connection.mdns=no
NMCONF

# Enable modem management
cat > /etc/NetworkManager/conf.d/modem.conf << 'MODEMCONF'
[main]
# Wait for ModemManager
systemd-resolved=true

[device]
# Manage all modems
match-device=type:gsm

[connection]
# Default settings for mobile connections
connection.autoconnect-retries=3
MODEMCONF

# DNS configuration
cat > /etc/NetworkManager/conf.d/dns.conf << 'DNSCONF'
[main]
dns=systemd-resolved

[global-dns-domain-*]
servers=1.1.1.1,8.8.8.8
DNSCONF

# =============================================================================
# ModemManager Configuration
# =============================================================================
log "Configuring ModemManager..."

mkdir -p /etc/ModemManager/fcc-unlock.d

# Some modems need FCC unlock
cat > /etc/ModemManager/fcc-unlock.d/2c7c:0125 << 'FCCUNLOCK'
#!/bin/bash
# FCC unlock for Quectel EG25-G (if needed)
# Usually not required, but included for compatibility
MODEM="$1"
mmcli -m "$MODEM" --command='AT+QCFG="usbnet",0' 2>/dev/null || true
FCCUNLOCK
chmod +x /etc/ModemManager/fcc-unlock.d/2c7c:0125

# =============================================================================
# Helper Scripts
# =============================================================================
log "Creating modem helper scripts..."

mkdir -p ${USER_HOME}/.local/bin

# Modem status script
cat > ${USER_HOME}/.local/bin/modem << 'MODEMSCRIPT'
#!/bin/bash
# uConsole 4G Modem Control

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

get_modem_index() {
    mmcli -L 2>/dev/null | grep -oP '/Modem/\K[0-9]+' | head -1
}

show_status() {
    local modem=$(get_modem_index)

    if [ -z "$modem" ]; then
        echo -e "${RED}No modem detected${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check if modem is physically installed"
        echo "  2. Run: sudo systemctl status ModemManager"
        echo "  3. Check USB: lsusb | grep -i quectel"
        return 1
    fi

    echo -e "${CYAN}=== Modem Status ===${NC}"
    mmcli -m "$modem" | grep -E "(state|signal|operator|access tech|number)" | sed 's/^/  /'

    echo ""
    echo -e "${CYAN}=== SIM Status ===${NC}"
    local sim=$(mmcli -m "$modem" | grep -oP "SIM\s+\|\s+path:\s+'/org/freedesktop/ModemManager1/SIM/\K[0-9]+")
    if [ -n "$sim" ]; then
        mmcli -i "$sim" 2>/dev/null | grep -E "(imsi|operator|state)" | sed 's/^/  /'
    else
        echo "  No SIM detected"
    fi

    echo ""
    echo -e "${CYAN}=== Connection ===${NC}"
    nmcli connection show --active | grep -E "(gsm|mobile)" | sed 's/^/  /' || echo "  No active mobile connection"
}

connect() {
    local modem=$(get_modem_index)
    local apn="${1:-internet}"

    if [ -z "$modem" ]; then
        echo -e "${RED}No modem found${NC}"
        return 1
    fi

    echo -e "${GREEN}Connecting with APN: $apn${NC}"

    # Check if connection exists
    if nmcli connection show "Mobile" &>/dev/null; then
        nmcli connection up "Mobile"
    else
        # Create new connection
        nmcli connection add type gsm ifname '*' con-name "Mobile" apn "$apn"
        nmcli connection up "Mobile"
    fi
}

disconnect() {
    echo -e "${YELLOW}Disconnecting mobile...${NC}"
    nmcli connection down "Mobile" 2>/dev/null || true
}

setup_apn() {
    local apn="$1"
    local user="$2"
    local pass="$3"

    if [ -z "$apn" ]; then
        echo "Usage: modem setup <apn> [username] [password]"
        echo ""
        echo "Common APNs:"
        echo "  AT&T:      phone"
        echo "  T-Mobile:  fast.t-mobile.com"
        echo "  Verizon:   vzwinternet"
        echo "  Mint:      Wholesale"
        return 1
    fi

    # Remove existing connection
    nmcli connection delete "Mobile" 2>/dev/null || true

    # Create new connection
    if [ -n "$user" ] && [ -n "$pass" ]; then
        nmcli connection add type gsm ifname '*' con-name "Mobile" apn "$apn" user "$user" password "$pass"
    else
        nmcli connection add type gsm ifname '*' con-name "Mobile" apn "$apn"
    fi

    echo -e "${GREEN}Mobile connection configured with APN: $apn${NC}"
}

send_sms() {
    local modem=$(get_modem_index)
    local number="$1"
    local message="$2"

    if [ -z "$number" ] || [ -z "$message" ]; then
        echo "Usage: modem sms <number> <message>"
        return 1
    fi

    mmcli -m "$modem" --messaging-create-sms="number='$number',text='$message'"
    local sms_path=$(mmcli -m "$modem" --messaging-list-sms | tail -1 | grep -oP '/SMS/\K[0-9]+')
    mmcli -s "$sms_path" --send
    echo -e "${GREEN}SMS sent to $number${NC}"
}

show_signal() {
    local modem=$(get_modem_index)

    if [ -z "$modem" ]; then
        echo -e "${RED}No modem found${NC}"
        return 1
    fi

    echo -e "${CYAN}=== Signal Quality ===${NC}"
    mmcli -m "$modem" --signal-get 2>/dev/null | grep -E "(rssi|rsrp|rsrq|snr)" | sed 's/^/  /'
}

at_command() {
    local modem=$(get_modem_index)
    local cmd="$1"

    if [ -z "$cmd" ]; then
        echo "Usage: modem at <command>"
        echo "Example: modem at 'AT+CSQ'"
        return 1
    fi

    mmcli -m "$modem" --command="$cmd"
}

case "$1" in
    status|s|"")
        show_status
        ;;
    connect|c)
        connect "$2"
        ;;
    disconnect|d)
        disconnect
        ;;
    setup)
        setup_apn "$2" "$3" "$4"
        ;;
    sms)
        send_sms "$2" "$3"
        ;;
    signal|sig)
        show_signal
        ;;
    at)
        at_command "$2"
        ;;
    help|h)
        echo "uConsole Modem Control"
        echo ""
        echo "Usage: modem <command>"
        echo ""
        echo "Commands:"
        echo "  status, s       Show modem status (default)"
        echo "  connect, c      Connect to mobile network"
        echo "  disconnect, d   Disconnect from mobile network"
        echo "  setup <apn>     Configure APN settings"
        echo "  sms <num> <msg> Send SMS message"
        echo "  signal, sig     Show signal quality"
        echo "  at <cmd>        Send AT command"
        echo "  help, h         Show this help"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'modem help' for usage"
        ;;
esac
MODEMSCRIPT
chmod +x ${USER_HOME}/.local/bin/modem

# Network status script
cat > ${USER_HOME}/.local/bin/netstat-all << 'NETSTATALL'
#!/bin/bash
# Network status overview

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}=== Network Interfaces ===${NC}"
ip -br addr | sed 's/^/  /'

echo ""
echo -e "${CYAN}=== WiFi ===${NC}"
if iwgetid &>/dev/null; then
    echo "  Connected: $(iwgetid -r)"
    echo "  Signal: $(iwconfig 2>/dev/null | grep -oP 'Signal level=\K[^ ]+' || echo 'N/A')"
else
    echo "  Not connected"
fi

echo ""
echo -e "${CYAN}=== Mobile (4G) ===${NC}"
modem=$(mmcli -L 2>/dev/null | grep -oP '/Modem/\K[0-9]+' | head -1)
if [ -n "$modem" ]; then
    state=$(mmcli -m "$modem" 2>/dev/null | grep -oP "state:\s+'\K[^']+")
    operator=$(mmcli -m "$modem" 2>/dev/null | grep -oP "operator name:\s+'\K[^']+")
    signal=$(mmcli -m "$modem" 2>/dev/null | grep -oP "signal quality:\s+'\K[0-9]+")
    echo "  State: $state"
    echo "  Operator: ${operator:-N/A}"
    echo "  Signal: ${signal:-N/A}%"
else
    echo "  No modem detected"
fi

echo ""
echo -e "${CYAN}=== Active Connections ===${NC}"
nmcli connection show --active | tail -n +2 | sed 's/^/  /'

echo ""
echo -e "${CYAN}=== Public IP ===${NC}"
echo "  $(curl -s --max-time 5 ifconfig.me || echo 'Unable to determine')"
NETSTATALL
chmod +x ${USER_HOME}/.local/bin/netstat-all

# =============================================================================
# Waybar Module for Modem
# =============================================================================
log "Adding modem status to waybar..."

cat > ${USER_HOME}/.local/bin/waybar-modem << 'WAYBARMODEM'
#!/bin/bash
# Waybar modem status module

modem=$(mmcli -L 2>/dev/null | grep -oP '/Modem/\K[0-9]+' | head -1)

if [ -z "$modem" ]; then
    echo '{"text": "4G --", "tooltip": "No modem", "class": "disconnected"}'
    exit 0
fi

state=$(mmcli -m "$modem" 2>/dev/null | grep -oP "state:\s+'\K[^']+")
signal=$(mmcli -m "$modem" 2>/dev/null | grep -oP "signal quality:\s+'\K[0-9]+")
operator=$(mmcli -m "$modem" 2>/dev/null | grep -oP "operator name:\s+'\K[^']+")
access=$(mmcli -m "$modem" 2>/dev/null | grep -oP "access tech:\s+'\K[^']+")

if [ "$state" = "connected" ]; then
    class="connected"
    icon="4G"
else
    class="disconnected"
    icon="4G"
fi

tooltip="State: $state\nOperator: ${operator:-N/A}\nSignal: ${signal:-?}%\nTech: ${access:-N/A}"

echo "{\"text\": \"$icon ${signal:-?}%\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
WAYBARMODEM
chmod +x ${USER_HOME}/.local/bin/waybar-modem

# =============================================================================
# Add to Waybar Config
# =============================================================================
log "Updating waybar configuration..."

# Check if waybar config exists and add modem module
WAYBAR_CONFIG="${USER_HOME}/.config/waybar/config.jsonc"
if [ -f "$WAYBAR_CONFIG" ]; then
    # Add custom/modem module if not present
    if ! grep -q "custom/modem" "$WAYBAR_CONFIG"; then
        # This is a simple append - user may want to position it differently
        cat >> "$WAYBAR_CONFIG" << 'MODEMMODULE'

    // Add this to modules-right: "custom/modem"
    // "custom/modem": {
    //     "exec": "waybar-modem",
    //     "return-type": "json",
    //     "interval": 30,
    //     "on-click": "foot -e modem"
    // }
MODEMMODULE
        info "Added modem module config - enable in waybar config manually"
    fi
fi

# =============================================================================
# Systemd Services
# =============================================================================
log "Enabling services..."

systemctl enable ModemManager
systemctl enable NetworkManager
systemctl disable dhcpcd 2>/dev/null || true

# Start services if running
systemctl start ModemManager 2>/dev/null || true
systemctl start NetworkManager 2>/dev/null || true

# =============================================================================
# Add user to dialout group
# =============================================================================
log "Adding user to dialout group..."
usermod -aG dialout ${USERNAME}

# =============================================================================
# Set ownership
# =============================================================================
chown -R ${USERNAME}:${USERNAME} ${USER_HOME}/.local

# =============================================================================
# Reload udev
# =============================================================================
log "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

log "=============================================="
log "Modem setup complete!"
log ""
log "Commands:"
log "  modem status     - Show modem status"
log "  modem setup <apn> - Configure APN"
log "  modem connect    - Connect to network"
log "  modem disconnect - Disconnect"
log "  modem sms <num> <msg> - Send SMS"
log "  netstat-all      - Full network overview"
log ""
log "GUI: nm-connection-editor"
log "TUI: nmtui"
log ""
warn "You may need to reboot for modem to be detected"
log "=============================================="
