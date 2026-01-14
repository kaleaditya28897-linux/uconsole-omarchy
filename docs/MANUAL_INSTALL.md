# Manual Installation (Advanced)

This document describes the manual installation process for advanced users who want full control over the installation or need to customize the base system.

> **Warning:** The standard Arch Linux ARM image will NOT work on the uConsole without significant modifications. The display requires custom device tree overlays and kernel patches. **We strongly recommend using the [hybrid installation method](../README.md#installation-recommended-hybrid-approach) instead.**

## Why Manual Installation is Complex

The uConsole uses hardware that requires custom drivers not included in standard Arch Linux ARM:

1. **Display:** The 5" DSI panel needs the `panel-cwu50` or `panel-cwd686` driver
2. **Power Management:** The AXP228 PMIC requires custom overlays
3. **Device Tree:** Custom overlays for GPIO mapping, audio routing, etc.

Without these, the device will boot but the display will remain black.

## Requirements

- Linux machine for preparation
- MicroSD card (32GB+)
- Understanding of Raspberry Pi boot process
- Ability to compile device tree overlays

## Method 1: Using Our Installer Script

Our `01-install.sh` creates a basic Arch Linux ARM installation, but **you must add the uConsole overlays manually**.

### Step 1: Create Base Installation

```bash
# Clone this repository
git clone https://github.com/yourusername/uconsole-omarchy.git
cd uconsole-omarchy

chmod +x scripts/*.sh

# Flash base Arch Linux ARM to SD card
sudo ./scripts/01-install.sh /dev/sdX
```

### Step 2: Get uConsole Overlays

Before the SD card will boot with display, you need to add the overlays.

**Option A: From ClockworkPi Repository**

```bash
# Mount the boot partition
sudo mount /dev/sdX1 /mnt

# Clone ClockworkPi's uConsole repo
git clone https://github.com/clockworkpi/uConsole.git /tmp/uconsole

# Copy overlays (if prebuilt overlays exist)
sudo cp /tmp/uconsole/Code/kernel/dts/overlays/*.dtbo /mnt/overlays/

# Update config.txt
sudo tee -a /mnt/config.txt << 'EOF'

# uConsole Display
ignore_lcd=1
dtoverlay=vc4-kms-v3d-pi4,cma-384
dtoverlay=devterm-pmu
dtoverlay=devterm-panel-uc
dtoverlay=devterm-misc
dtoverlay=audremap,pins_12_13
EOF

sudo umount /mnt
```

**Option B: Build Overlays from Source**

If prebuilt overlays aren't available, you'll need to compile them:

```bash
# Install device tree compiler
sudo pacman -S dtc

# Compile overlays from DTS source
cd /tmp/uconsole/Code/kernel/dts/overlays
for dts in *.dts; do
    dtc -@ -I dts -O dtb -o "${dts%.dts}.dtbo" "$dts"
done
```

**Option C: Extract from Working Image**

If you have ClockworkPi's official image:

```bash
# Download and extract ClockworkPi's official image
wget http://dl.clockworkpi.com/uConsole_CM4_v2.1_64bit.img.bz2
bunzip2 uConsole_CM4_v2.1_64bit.img.bz2

# Mount the boot partition from the image
sudo losetup -P /dev/loop0 uConsole_CM4_v2.1_64bit.img
sudo mount /dev/loop0p1 /mnt/clockwork-boot

# Copy overlays to your SD card
sudo mount /dev/sdX1 /mnt/myboot
sudo cp /mnt/clockwork-boot/overlays/devterm*.dtbo /mnt/myboot/overlays/
sudo cp /mnt/clockwork-boot/overlays/audremap.dtbo /mnt/myboot/overlays/

# Copy config.txt settings
grep -E "^(dtoverlay|ignore_lcd)" /mnt/clockwork-boot/config.txt >> /mnt/myboot/config.txt

sudo umount /mnt/myboot /mnt/clockwork-boot
sudo losetup -d /dev/loop0
```

### Step 3: Boot and Complete Setup

1. Insert SD card into uConsole
2. Power on (display should now work)
3. Login as `alarm` / `alarm`
4. Run the first-boot script:

```bash
su -
# password: root
./first-boot.sh
```

5. Continue with the remaining setup scripts

## Method 2: Build Custom Kernel

For full control, you can build a custom kernel with uConsole patches.

### Build Environment Setup

```bash
# On an aarch64 system or using cross-compilation
git clone https://github.com/PotatoMania/uconsole-cm3.git
cd uconsole-cm3/PKGBUILDs/linux-uconsole-rpi64

# Cross-compile for ARM64
makepkg CARCH=aarch64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
```

### Install Custom Kernel

After building:

```bash
# Copy the built package to uConsole
scp linux-uconsole-*.pkg.tar.zst alarm@uconsole:~/

# On uConsole
sudo pacman -U linux-uconsole-*.pkg.tar.zst
```

## Correct config.txt for uConsole CM4

The complete config.txt should look like this:

```ini
# =============================================================================
# uConsole CM4 Boot Configuration
# =============================================================================

disable_overscan=1
dtparam=audio=on

[pi4]
max_framebuffers=2

[all]
# Display Configuration
ignore_lcd=1
dtoverlay=vc4-kms-v3d-pi4,cma-384

# uConsole Hardware
dtoverlay=devterm-pmu
dtoverlay=devterm-panel-uc
dtoverlay=devterm-misc

# Audio
dtoverlay=audremap,pins_12_13

# USB
dtoverlay=dwc2,dr_mode=host

# I2C/SPI
dtparam=spi=on
gpio=10=ip,np
```

## Correct cmdline.txt

```
root=/dev/mmcblk0p2 rw rootwait console=tty1 loglevel=3 quiet splash
```

## Troubleshooting Manual Installation

### Display stays black

1. Verify overlays are in `/boot/overlays/`
2. Check config.txt has correct dtoverlay lines
3. Try connecting via SSH to see if system is running

### Kernel panic on boot

1. The kernel may not have the panel driver compiled
2. Try using PotatoMania's prebuilt kernel package

### WiFi not working

1. Ensure firmware files are present in `/lib/firmware/`
2. Check regulatory domain settings

### No sound

1. Verify `audremap` overlay is loaded
2. Check `/etc/asound.conf` configuration

## Resources

- [ClockworkPi uConsole GitHub](https://github.com/clockworkpi/uConsole)
- [PotatoMania's Kernel Builds](https://github.com/PotatoMania/uconsole-cm3)
- [Arch Linux ARM Wiki](https://archlinuxarm.org/)
- [ClockworkPi Forum](https://forum.clockworkpi.com)

## Getting Help

If you're stuck with manual installation, consider:

1. Using the [hybrid installation method](../README.md#installation-recommended-hybrid-approach)
2. Asking on the [ClockworkPi Forum](https://forum.clockworkpi.com)
3. Checking [existing threads](https://forum.clockworkpi.com/t/archlinux-arm-for-uconsole-cm4-living-documentation/12804)
