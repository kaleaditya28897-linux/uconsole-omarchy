#!/bin/bash
# =============================================================================
# uConsole Omarchy - Base Arch Linux ARM Installation
# For ClockworkPi uConsole with Raspberry Pi CM4 (8GB)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

# =============================================================================
# This script prepares an SD card with Arch Linux ARM for uConsole CM4
# Run this on your host machine (not on the uConsole)
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo $0 /dev/sdX"
fi

if [ -z "$1" ]; then
    echo "Usage: sudo $0 /dev/sdX"
    echo ""
    echo "Available devices:"
    lsblk -d -o NAME,SIZE,MODEL | grep -v loop
    exit 1
fi

DEVICE="$1"
MOUNT_BOOT="/mnt/boot"
MOUNT_ROOT="/mnt/root"

# Confirm device
warn "This will ERASE ALL DATA on ${DEVICE}"
read -p "Are you sure? (yes/no): " confirm
[ "$confirm" != "yes" ] && exit 1

log "Unmounting any existing partitions..."
umount ${DEVICE}* 2>/dev/null || true

log "Creating partition table..."
parted -s ${DEVICE} mklabel msdos
parted -s ${DEVICE} mkpart primary fat32 1MiB 512MiB
parted -s ${DEVICE} mkpart primary ext4 512MiB 100%
parted -s ${DEVICE} set 1 boot on

log "Formatting partitions..."
mkfs.vfat -F 32 ${DEVICE}1
mkfs.ext4 -F ${DEVICE}2

log "Mounting partitions..."
mkdir -p ${MOUNT_BOOT} ${MOUNT_ROOT}
mount ${DEVICE}2 ${MOUNT_ROOT}
mkdir -p ${MOUNT_ROOT}/boot
mount ${DEVICE}1 ${MOUNT_ROOT}/boot

log "Downloading Arch Linux ARM..."
cd ${MOUNT_ROOT}
curl -LO http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz

log "Extracting Arch Linux ARM (this takes a while)..."
bsdtar -xpf ArchLinuxARM-rpi-aarch64-latest.tar.gz -C ${MOUNT_ROOT}
rm ArchLinuxARM-rpi-aarch64-latest.tar.gz

log "Configuring boot for CM4..."
cat > ${MOUNT_ROOT}/boot/config.txt << 'EOF'
# uConsole CM4 Configuration
# Display settings for 5" 720x1280 panel (used in landscape: 1280x720)
disable_overscan=1
hdmi_force_hotplug=1
hdmi_group=2
hdmi_mode=87
hdmi_cvt=1280 720 60 6 0 0 0
display_rotate=1

# GPU memory
gpu_mem=128

# Enable hardware
dtparam=audio=on
dtparam=i2c_arm=on
dtparam=spi=on

# Enable USB OTG
dtoverlay=dwc2,dr_mode=host

# uConsole specific overlays (will be installed later)
# dtoverlay=uconsole
# dtoverlay=uconsole-audio

# Performance
arm_boost=1
over_voltage=2

# Disable unnecessary
dtoverlay=disable-bt
EOF

cat > ${MOUNT_ROOT}/boot/cmdline.txt << 'EOF'
root=/dev/mmcblk0p2 rw rootwait console=tty1 loglevel=3 quiet splash
EOF

log "Setting up initial configuration..."
# Hostname
echo "uconsole" > ${MOUNT_ROOT}/etc/hostname

# Hosts file
cat > ${MOUNT_ROOT}/etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   uconsole.localdomain uconsole
EOF

# Enable DHCP on boot
ln -sf /usr/lib/systemd/system/dhcpcd.service \
    ${MOUNT_ROOT}/etc/systemd/system/multi-user.target.wants/dhcpcd.service

# Locale
echo "en_US.UTF-8 UTF-8" > ${MOUNT_ROOT}/etc/locale.gen
echo "LANG=en_US.UTF-8" > ${MOUNT_ROOT}/etc/locale.conf

# Console font for small screen
echo "FONT=ter-112n" > ${MOUNT_ROOT}/etc/vconsole.conf

log "Creating first-boot setup script..."
cat > ${MOUNT_ROOT}/root/first-boot.sh << 'FIRSTBOOT'
#!/bin/bash
# Run this after first boot on the uConsole

set -e

echo "[+] Initializing pacman keyring..."
pacman-key --init
pacman-key --populate archlinuxarm

echo "[+] Updating system..."
pacman -Syu --noconfirm

echo "[+] Installing essential packages..."
pacman -S --noconfirm --needed \
    base-devel \
    git \
    wget \
    curl \
    vim \
    networkmanager \
    bluez \
    bluez-utils \
    terminus-font \
    man-db \
    man-pages

echo "[+] Enabling NetworkManager..."
systemctl disable dhcpcd
systemctl enable --now NetworkManager

echo "[+] Generating locales..."
locale-gen

echo "[+] Setting timezone (change as needed)..."
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc

echo "[+] First boot setup complete!"
echo "[+] Run the next script: ./02-uconsole-drivers.sh"
FIRSTBOOT
chmod +x ${MOUNT_ROOT}/root/first-boot.sh

log "Syncing and unmounting..."
sync
umount ${MOUNT_ROOT}/boot
umount ${MOUNT_ROOT}

log "=============================================="
log "Base installation complete!"
log ""
log "Next steps:"
log "1. Insert SD card into uConsole and boot"
log "2. Login as 'alarm' with password 'alarm'"
log "3. su to root (password: root)"
log "4. Run: ./first-boot.sh"
log "5. Copy remaining scripts and continue setup"
log "=============================================="
