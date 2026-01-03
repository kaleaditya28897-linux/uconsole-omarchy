#!/bin/bash
# =============================================================================
# uConsole Omarchy - Universal Installer
# Supports CM4/CM5 with SD Card, eMMC, and PCIe/NVMe storage
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# =============================================================================
# Configuration
# =============================================================================
MOUNT_BOOT="/mnt/boot"
MOUNT_ROOT="/mnt/root"

# Detect architecture of host
HOST_ARCH=$(uname -m)

show_banner() {
    echo -e "${MAGENTA}"
    cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════════╗
  ║           uConsole Omarchy - Universal Installer              ║
  ║                                                               ║
  ║   Supports: CM4 / CM5 | SD / eMMC / NVMe                     ║
  ╚═══════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

show_help() {
    echo "Usage: sudo $0 [OPTIONS] <device>"
    echo ""
    echo "Options:"
    echo "  -m, --module <cm4|cm5>     Compute module type (default: cm4)"
    echo "  -s, --storage <sd|emmc|nvme>  Storage type (default: sd)"
    echo "  -h, --help                 Show this help"
    echo ""
    echo "Examples:"
    echo "  sudo $0 /dev/sda                    # CM4 + SD card"
    echo "  sudo $0 -m cm4 -s emmc /dev/mmcblk0 # CM4 + eMMC"
    echo "  sudo $0 -m cm5 -s nvme /dev/nvme0n1 # CM5 + NVMe"
    echo ""
    echo "Device examples:"
    echo "  SD card:  /dev/sdX or /dev/mmcblk0"
    echo "  eMMC:     /dev/mmcblk0 (when using rpiboot)"
    echo "  NVMe:     /dev/nvme0n1"
    echo ""
}

# =============================================================================
# Parse Arguments
# =============================================================================
MODULE="cm4"
STORAGE="sd"
DEVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--module)
            MODULE="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE="$2"
            shift 2
            ;;
        -h|--help)
            show_banner
            show_help
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            DEVICE="$1"
            shift
            ;;
    esac
done

# =============================================================================
# Validation
# =============================================================================
show_banner

if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo $0 ..."
fi

if [ -z "$DEVICE" ]; then
    echo "Available devices:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v "^loop"
    echo ""
    show_help
    exit 1
fi

if [[ ! "$MODULE" =~ ^(cm4|cm5)$ ]]; then
    error "Invalid module type: $MODULE (use cm4 or cm5)"
fi

if [[ ! "$STORAGE" =~ ^(sd|emmc|nvme)$ ]]; then
    error "Invalid storage type: $STORAGE (use sd, emmc, or nvme)"
fi

if [ ! -b "$DEVICE" ]; then
    error "Device not found: $DEVICE"
fi

# =============================================================================
# Determine partition naming
# =============================================================================
if [[ "$DEVICE" =~ "nvme" ]] || [[ "$DEVICE" =~ "mmcblk" ]]; then
    PART1="${DEVICE}p1"
    PART2="${DEVICE}p2"
else
    PART1="${DEVICE}1"
    PART2="${DEVICE}2"
fi

# Determine root device for cmdline.txt
case "$STORAGE" in
    sd)
        ROOT_DEV="/dev/mmcblk0p2"
        ;;
    emmc)
        ROOT_DEV="/dev/mmcblk0p2"
        ;;
    nvme)
        ROOT_DEV="/dev/nvme0n1p2"
        ;;
esac

# =============================================================================
# Confirmation
# =============================================================================
echo -e "${CYAN}Configuration:${NC}"
echo "  Module:  ${MODULE^^}"
echo "  Storage: ${STORAGE^^}"
echo "  Device:  $DEVICE"
echo "  Root:    $ROOT_DEV"
echo ""
warn "This will ERASE ALL DATA on ${DEVICE}"
read -p "Continue? (yes/no): " confirm
[ "$confirm" != "yes" ] && exit 1

# =============================================================================
# Unmount and partition
# =============================================================================
log "Unmounting any existing partitions..."
umount ${DEVICE}* 2>/dev/null || true
umount ${MOUNT_BOOT} 2>/dev/null || true
umount ${MOUNT_ROOT} 2>/dev/null || true

log "Creating partition table..."
parted -s ${DEVICE} mklabel msdos
parted -s ${DEVICE} mkpart primary fat32 1MiB 512MiB
parted -s ${DEVICE} mkpart primary ext4 512MiB 100%
parted -s ${DEVICE} set 1 boot on

# Wait for partitions to appear
sleep 2

log "Formatting partitions..."
mkfs.vfat -F 32 ${PART1}
mkfs.ext4 -F ${PART2}

log "Mounting partitions..."
mkdir -p ${MOUNT_BOOT} ${MOUNT_ROOT}
mount ${PART2} ${MOUNT_ROOT}
mkdir -p ${MOUNT_ROOT}/boot
mount ${PART1} ${MOUNT_ROOT}/boot

# =============================================================================
# Download and extract Arch Linux ARM
# =============================================================================
log "Downloading Arch Linux ARM..."
cd ${MOUNT_ROOT}

# CM5 uses a different image (when available) or same aarch64 image
ARCH_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"

curl -L -o arch.tar.gz ${ARCH_URL}

log "Extracting Arch Linux ARM (this takes a while)..."
bsdtar -xpf arch.tar.gz -C ${MOUNT_ROOT}
rm arch.tar.gz

# =============================================================================
# Configure boot - Module specific
# =============================================================================
log "Configuring boot for ${MODULE^^}..."

# Base config shared between CM4 and CM5
cat > ${MOUNT_ROOT}/boot/config.txt << 'BASECONFIG'
# =============================================================================
# uConsole Omarchy Boot Configuration
# =============================================================================

# Display settings for 5" 720x1280 panel (landscape: 1280x720)
disable_overscan=1
hdmi_force_hotplug=1

# GPU memory
gpu_mem=128

# Enable hardware
dtparam=audio=on
dtparam=i2c_arm=on
dtparam=spi=on

# Enable USB OTG
dtoverlay=dwc2,dr_mode=host

# Graphics (KMS)
dtoverlay=vc4-kms-v3d,cma-512

# I2C for power management
dtoverlay=i2c-gpio,i2c_gpio_sda=10,i2c_gpio_scl=11

BASECONFIG

# Module-specific additions
if [ "$MODULE" = "cm4" ]; then
    cat >> ${MOUNT_ROOT}/boot/config.txt << 'CM4CONFIG'
# -----------------------------------------------------------------------------
# CM4 Specific Configuration
# -----------------------------------------------------------------------------

# Display (CM4)
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1280 720 60 6 0 0 0
display_rotate=1

# Performance
arm_boost=1
over_voltage=2

# PCIe (for NVMe if used)
dtparam=pciex1
dtparam=pciex1_gen=2

# Disable unused
dtoverlay=disable-bt
CM4CONFIG

elif [ "$MODULE" = "cm5" ]; then
    cat >> ${MOUNT_ROOT}/boot/config.txt << 'CM5CONFIG'
# -----------------------------------------------------------------------------
# CM5 Specific Configuration
# -----------------------------------------------------------------------------

# CM5 uses BCM2712 (Pi 5 SoC)
# Display settings may differ

# Display (CM5 - adjust as needed)
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1280 720 60 6 0 0 0
display_rotate=1

# Performance (CM5 has more headroom)
arm_boost=1

# PCIe Gen 3 support on CM5
dtparam=pciex1
dtparam=pciex1_gen=3

# Fan control (if applicable)
dtoverlay=pwm-fan,gpiopin=14,temp0=50000,temp1=60000,temp2=70000

# Camera/Display connectors
camera_auto_detect=1
display_auto_detect=1
CM5CONFIG
fi

# Storage-specific boot configuration
if [ "$STORAGE" = "nvme" ]; then
    cat >> ${MOUNT_ROOT}/boot/config.txt << 'NVMECONFIG'

# -----------------------------------------------------------------------------
# NVMe Boot Configuration
# -----------------------------------------------------------------------------

# Enable PCIe for NVMe
dtparam=pciex1
dtparam=pciex1_gen=3

# NVMe boot requires updated bootloader
# Run: sudo rpi-eeprom-config --edit
# Add: BOOT_ORDER=0xf416
NVMECONFIG

    info "NVMe boot requires EEPROM update - see post-install instructions"
fi

# =============================================================================
# Configure cmdline.txt
# =============================================================================
log "Configuring kernel command line..."

cat > ${MOUNT_ROOT}/boot/cmdline.txt << EOF
root=${ROOT_DEV} rw rootwait console=tty1 loglevel=3 quiet splash
EOF

# For NVMe, we may need to wait for the drive
if [ "$STORAGE" = "nvme" ]; then
    echo "root=${ROOT_DEV} rw rootwait rootdelay=5 console=tty1 loglevel=3 quiet splash" > ${MOUNT_ROOT}/boot/cmdline.txt
fi

# =============================================================================
# System configuration
# =============================================================================
log "Configuring system..."

# Hostname
echo "uconsole" > ${MOUNT_ROOT}/etc/hostname

# Hosts
cat > ${MOUNT_ROOT}/etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   uconsole.localdomain uconsole
EOF

# Locale
echo "en_US.UTF-8 UTF-8" > ${MOUNT_ROOT}/etc/locale.gen
echo "LANG=en_US.UTF-8" > ${MOUNT_ROOT}/etc/locale.conf

# Console font
echo "FONT=ter-112n" > ${MOUNT_ROOT}/etc/vconsole.conf

# Enable DHCP
ln -sf /usr/lib/systemd/system/dhcpcd.service \
    ${MOUNT_ROOT}/etc/systemd/system/multi-user.target.wants/dhcpcd.service

# =============================================================================
# Create first-boot script
# =============================================================================
log "Creating first-boot script..."

cat > ${MOUNT_ROOT}/root/first-boot.sh << FIRSTBOOT
#!/bin/bash
# First boot setup for uConsole Omarchy
# Module: ${MODULE^^} | Storage: ${STORAGE^^}

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "\${GREEN}[+]\${NC} \$1"; }
warn() { echo -e "\${YELLOW}[!]\${NC} \$1"; }

echo ""
echo "=================================="
echo " uConsole Omarchy First Boot"
echo " Module: ${MODULE^^} | Storage: ${STORAGE^^}"
echo "=================================="
echo ""

log "Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm

log "Updating system..."
pacman -Syu --noconfirm

log "Installing essential packages..."
pacman -S --noconfirm --needed \\
    base-devel \\
    git \\
    wget \\
    curl \\
    vim \\
    networkmanager \\
    bluez \\
    bluez-utils \\
    terminus-font \\
    man-db \\
    man-pages

log "Enabling NetworkManager..."
systemctl disable dhcpcd
systemctl enable --now NetworkManager

log "Generating locales..."
locale-gen

log "Setting timezone..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

# CM5 specific setup
if [ "${MODULE}" = "cm5" ]; then
    log "Installing CM5-specific packages..."
    pacman -S --noconfirm --needed \\
        linux-rpi \\
        raspberrypi-firmware \\
        raspberrypi-utils
fi

# NVMe specific setup
if [ "${STORAGE}" = "nvme" ]; then
    log "Configuring NVMe boot..."
    warn "To boot from NVMe, update EEPROM:"
    warn "  sudo rpi-eeprom-config --edit"
    warn "  Set: BOOT_ORDER=0xf416"
fi

log "First boot setup complete!"
echo ""
log "Next steps:"
log "  1. Reboot if kernel was updated"
log "  2. Run: ./02-uconsole-drivers.sh"
log "  3. Run: ./02a-modem-setup.sh (if you have 4G)"
log "  4. Continue with remaining scripts"
echo ""
FIRSTBOOT
chmod +x ${MOUNT_ROOT}/root/first-boot.sh

# =============================================================================
# Create system info file
# =============================================================================
cat > ${MOUNT_ROOT}/etc/uconsole-release << EOF
UCONSOLE_MODULE=${MODULE}
UCONSOLE_STORAGE=${STORAGE}
UCONSOLE_ROOT=${ROOT_DEV}
INSTALL_DATE=$(date -I)
EOF

# =============================================================================
# Sync and unmount
# =============================================================================
log "Syncing..."
sync

log "Unmounting..."
umount ${MOUNT_ROOT}/boot
umount ${MOUNT_ROOT}

# =============================================================================
# Post-install instructions
# =============================================================================
echo ""
echo -e "${GREEN}=============================================="
echo " Installation complete!"
echo "==============================================${NC}"
echo ""
echo -e "${CYAN}Configuration:${NC}"
echo "  Module:  ${MODULE^^}"
echo "  Storage: ${STORAGE^^}"
echo "  Root:    ${ROOT_DEV}"
echo ""

if [ "$STORAGE" = "emmc" ]; then
    echo -e "${YELLOW}eMMC Installation Notes:${NC}"
    echo "  1. Remove USB connection used for rpiboot"
    echo "  2. Power on uConsole normally"
    echo "  3. Login as 'alarm' / 'alarm', su to root"
    echo ""
fi

if [ "$STORAGE" = "nvme" ]; then
    echo -e "${YELLOW}NVMe Installation Notes:${NC}"
    echo "  1. You may need an SD card for initial boot"
    echo "  2. Update EEPROM to boot from NVMe:"
    echo "     sudo rpi-eeprom-config --edit"
    echo "     Set: BOOT_ORDER=0xf416"
    echo "  3. Reboot and remove SD card"
    echo ""
fi

if [ "$MODULE" = "cm5" ]; then
    echo -e "${YELLOW}CM5 Notes:${NC}"
    echo "  - CM5 support is newer, some drivers may need updates"
    echo "  - Check ClockworkPi forums for CM5-specific patches"
    echo ""
fi

echo -e "${CYAN}Next steps:${NC}"
echo "  1. Insert storage into uConsole and boot"
echo "  2. Login as 'alarm' (password: 'alarm')"
echo "  3. su to root (password: 'root')"
echo "  4. Run: ./first-boot.sh"
echo "  5. Copy remaining scripts and continue setup"
echo ""
