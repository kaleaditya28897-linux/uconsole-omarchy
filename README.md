# uConsole Omarchy

A minimal, terminal-centric Arch Linux setup for ClockworkPi uConsole.

## Features

- **Arch Linux ARM** - Rolling release, minimal base
- **Hyprland** - Modern Wayland compositor with tiling
- **Development Environment** - Neovim, tmux, zsh, starship
- **Security Tools** - Pentesting, network analysis, forensics
- **4G Modem Support** - ModemManager + NetworkManager
- **Optimized for uConsole** - Battery management, power saving, small screen UI

## Supported Hardware

| Module | Storage Options |
|--------|-----------------|
| **CM4 / CM4 Lite** (BCM2711) | SD Card, eMMC (non-Lite only) |
| **CM4S** | SD Card |
| **CM3** | SD Card |

> **Note:** CM5 support is experimental. See [CM5 Notes](#cm5-notes).

## Requirements

- ClockworkPi uConsole with CM4, CM4 Lite, CM4S, or CM3
- MicroSD card (32GB+ recommended, Class 10 or better)
- Another Linux machine for flashing

## Installation (Recommended: Hybrid Approach)

The recommended approach uses a community-maintained Arch Linux ARM base image that includes the correct kernel and display drivers, then applies our customizations on top.

### Step 1: Download Base Image

Download the PotatoMania community image which includes:
- Patched kernel with uConsole display/power drivers
- Correct device tree overlays
- Working WiFi, display, and battery support

```bash
# Download the image (works for CM3, CM4, CM4S, CM4 Lite)
wget https://filehosting.faint.day/uconsole-stuff/archlinux-uconsole-cm3_cm4s-20250913.img.zst

# Optional: verify checksum
wget https://filehosting.faint.day/uconsole-stuff/archlinux-uconsole-cm3_cm4s-20250913.img.zst.b2sum
b2sum -c archlinux-uconsole-cm3_cm4s-20250913.img.zst.b2sum
```

### Step 2: Flash to SD Card

```bash
# Find your SD card device (BE CAREFUL - wrong device = data loss!)
lsblk

# Flash the image (replace /dev/sdX with your actual device)
zstdcat archlinux-uconsole-cm3_cm4s-20250913.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync

# Ensure write completes
sync
```

**Alternative tools:** Balena Etcher, Raspberry Pi Imager (use custom image option)

### Step 3: First Boot on uConsole

1. Insert SD card into uConsole
2. Power on - you should see the display initialize
3. Login with default credentials:
   - **User:** `ucon`
   - **Password:** `ucon`
   - Root access via `sudo` (user has sudo privileges)

> **Display stays black?** This can occasionally happen with DSI displays. Try power cycling (remove battery briefly if needed). See [Troubleshooting](#troubleshooting).

### Step 4: Initial System Setup

```bash
# Expand filesystem to use full SD card
sudo growpart /dev/mmcblk0 2
sudo resize2fs /dev/mmcblk0p2

# Initialize pacman keyring
sudo pacman-key --init
sudo pacman-key --populate archlinux archlinuxarm

# Update system
sudo pacman -Syu --noconfirm

# Install git (needed to clone this repo)
sudo pacman -S --noconfirm git
```

### Step 5: Apply Omarchy Customizations

```bash
# Clone this repository
git clone https://github.com/yourusername/uconsole-omarchy.git
cd uconsole-omarchy

# Make scripts executable
chmod +x scripts/*.sh

# Run setup scripts in order (as root)
sudo su -

cd /home/ucon/uconsole-omarchy/scripts

# Optional: 4G modem setup (if you have the 4G extension)
./02a-modem-setup.sh

# Install Hyprland and Wayland stack
./03-install-hyprland.sh

# Install development environment
./04-setup-environment.sh

# Optional: Install security/pentesting tools
./05-install-security-tools.sh

# Configure system services (power management, etc.)
./06-system-services.sh

# Final bootstrap (shell configs, dotfiles)
./07-bootstrap.sh

# Reboot to apply all changes
reboot
```

### Step 6: Start Using

After reboot, login as `cyber` (password: `cyber`) and start Hyprland:

```bash
Hyprland
```

Or enable auto-start by adding to `~/.bash_profile`:
```bash
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
```

## Alternative: Manual Installation

If you prefer to build from scratch or need more control, you can use the manual installation method. This is more complex and requires understanding of Raspberry Pi boot configuration.

See [docs/MANUAL_INSTALL.md](docs/MANUAL_INSTALL.md) for details.

> **Warning:** The manual method requires adding ClockworkPi's kernel patches and device tree overlays. The standard Arch Linux ARM image will NOT boot with a working display on uConsole.

## Default Credentials

| User | Password | Notes |
|------|----------|-------|
| `ucon` | `ucon` | Base image default, has sudo |
| `cyber` | `cyber` | Created by our scripts |
| `root` | (none) | Use sudo instead |

**Change these passwords after setup!**

## Keybindings

Run `keys` for a quick reference. Key bindings:

| Binding | Action |
|---------|--------|
| `Super + Return` | Terminal |
| `Super + Space` | App launcher |
| `Super + Q` | Kill window |
| `Super + H/J/K/L` | Focus navigation |
| `Super + 1-6` | Switch workspace |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle float |
| `Super + X` | Power menu |

## Directory Structure

```
uconsole-omarchy/
├── scripts/
│   ├── 00-rpiboot-setup.sh       # rpiboot for eMMC flashing (advanced)
│   ├── 01-install.sh             # Manual installer (advanced)
│   ├── 02-uconsole-drivers.sh    # Additional driver configs
│   ├── 02a-modem-setup.sh        # 4G modem setup
│   ├── 03-install-hyprland.sh    # Hyprland compositor
│   ├── 04-setup-environment.sh   # Dev environment
│   ├── 05-install-security-tools.sh
│   ├── 06-system-services.sh     # Power management
│   └── 07-bootstrap.sh           # Final setup
├── configs/
│   ├── waybar/                   # Status bar
│   ├── foot/                     # Terminal
│   ├── fuzzel/                   # Launcher
│   └── mako/                     # Notifications
├── LICENSE
└── README.md
```

## CM5 Notes

The Raspberry Pi CM5 uses the BCM2712 SoC (same as Pi 5). CM5 support for uConsole is still experimental:

- **Kernel:** Requires different kernel/patches than CM4
- **Overlays:** Need `clockworkpi-uconsole-cm5` overlay
- **Status:** Community efforts ongoing, check forums for latest

For CM5, see: [Arch Linux ARM for uConsole w/ RPi CM5](https://forum.clockworkpi.com/t/arch-linux-arm-for-uconsole-w-rpi-cm5/16382)

## Troubleshooting

### Display stays black after boot

The DSI display driver can occasionally fail to initialize. Try:

1. **Power cycle:** Turn off, wait 10 seconds, turn on
2. **Remove battery:** If power cycle doesn't work, remove battery briefly
3. **Check connection:** Ensure the display ribbon cable is seated properly
4. **Try SSH:** The system may be running - try `ssh ucon@uconsole.local`

### Can't find uConsole on network

```bash
# Scan your local network
nmap -sn 192.168.1.0/24

# Or check router's DHCP leases
```

### WiFi not working

```bash
# Check if WiFi is detected
ip link show wlan0

# Use NetworkManager TUI
nmtui

# Or command line
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

### 4G Modem not detected

```bash
# Check if modem is detected
lsusb | grep -i quectel

# Check ModemManager
mmcli -L

# Check status
systemctl status ModemManager

# Use modem helper (after running 02a-modem-setup.sh)
modem status
modem setup <your-apn>
modem connect
```

### Battery percentage not showing

The AXP228 power management chip requires the kernel driver:

```bash
# Check if module is loaded
lsmod | grep axp

# Check battery status
cat /sys/class/power_supply/axp20x-battery/capacity
```

### Hyprland crashes or won't start

```bash
# Check logs
journalctl --user -u hyprland
cat ~/.local/share/hyprland/hyprland.log

# Try with software rendering
WLR_RENDERER_ALLOW_SOFTWARE=1 Hyprland
```

### Audio not working

```bash
# Check PipeWire status
systemctl --user status pipewire pipewire-pulse wireplumber

# List audio devices
wpctl status

# Set default output
wpctl set-default <sink-id>
```

## Tools Included

### Development
- Neovim with LSP (Python, Go, Rust, Lua)
- tmux with vim bindings
- Git + lazygit + delta
- fzf, ripgrep, fd, bat, eza

### Security (optional, via 05-install-security-tools.sh)
- Network: nmap, masscan, wireshark, tcpdump
- Web: nikto, sqlmap, gobuster, ffuf
- Password: john, hashcat, hydra
- Wireless: aircrack-ng
- Exploitation: metasploit, radare2, pwntools
- Forensics: sleuthkit, volatility3

### System
- Docker + docker-compose
- TLP power management
- Zram swap

## Resources

- [ClockworkPi uConsole Official Repo](https://github.com/clockworkpi/uConsole)
- [ClockworkPi Forum](https://forum.clockworkpi.com)
- [PotatoMania's Arch Linux Image Builder](https://github.com/PotatoMania/uconsole-cm3-arch-image-builder)
- [ArchLinux ARM for uConsole Documentation](https://forum.clockworkpi.com/t/archlinux-arm-for-uconsole-cm4-living-documentation/12804)

## Credits

- [PotatoMania](https://github.com/PotatoMania) - Arch Linux ARM image and kernel patches
- [ClockworkPi](https://github.com/clockworkpi) - uConsole hardware and base drivers
- Community contributors on the ClockworkPi forums

## License

MIT License - see [LICENSE](LICENSE)
