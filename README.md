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
| **CM4** (BCM2711) | SD Card, eMMC, NVMe |
| **CM5** (BCM2712) | SD Card, eMMC, NVMe |

## Requirements

- ClockworkPi uConsole with CM4 or CM5 (8GB RAM recommended)
- Storage: MicroSD card, eMMC, or NVMe SSD (32GB+ recommended)
- Another Linux machine for initial installation

## Installation

### Quick Start (SD Card)

```bash
# Clone this repo
git clone https://github.com/kaleaditya28897-linux/uconsole-omarchy.git
cd uconsole-omarchy

# Make scripts executable
chmod +x scripts/*.sh

# Install to SD card (CM4, default)
sudo ./scripts/01-install.sh /dev/sdX
```

### Installation Options

The universal installer supports multiple configurations:

```bash
# CM4 + SD Card (default)
sudo ./scripts/01-install.sh /dev/sdX

# CM4 + eMMC
sudo ./scripts/01-install.sh -m cm4 -s emmc /dev/sdX

# CM4 + NVMe
sudo ./scripts/01-install.sh -m cm4 -s nvme /dev/nvme0n1

# CM5 + SD Card
sudo ./scripts/01-install.sh -m cm5 /dev/sdX

# CM5 + eMMC
sudo ./scripts/01-install.sh -m cm5 -s emmc /dev/sdX

# CM5 + NVMe
sudo ./scripts/01-install.sh -m cm5 -s nvme /dev/nvme0n1
```

### eMMC Installation

To flash the eMMC, you need to use `rpiboot` to expose it as a USB mass storage device:

```bash
# Install rpiboot (run once on host machine)
sudo ./scripts/00-rpiboot-setup.sh

# Set boot switch on uConsole to USB boot mode
# Connect uConsole via USB-C

# Expose eMMC
sudo rpiboot

# Wait for device to appear, then flash
sudo ./scripts/01-install.sh -m cm4 -s emmc /dev/sdX
```

### NVMe Installation

For NVMe boot, you may need to update the EEPROM:

```bash
# Flash NVMe
sudo ./scripts/01-install.sh -m cm4 -s nvme /dev/nvme0n1

# After first boot, update EEPROM for NVMe boot:
sudo rpi-eeprom-config --edit
# Set: BOOT_ORDER=0xf416
```

### First Boot (on uConsole)

1. Insert storage and power on
2. Login as `alarm` / `alarm`
3. Switch to root: `su -` (password: `root`)
4. Run first boot setup:

```bash
./first-boot.sh
```

### Install Components

Copy scripts to uConsole and run in order:

```bash
# Transfer scripts (from host)
scp -r uconsole-omarchy alarm@<uconsole-ip>:~/

# On uConsole, as root:
cd ~/uconsole-omarchy/scripts

./02-uconsole-drivers.sh      # Hardware drivers (auto-detects CM4/CM5)
./02a-modem-setup.sh          # 4G modem + NetworkManager (optional)
reboot

./03-install-hyprland.sh      # Hyprland + Wayland
./04-setup-environment.sh     # Dev tools, neovim, zsh
./05-install-security-tools.sh  # Security/hacking tools
./06-system-services.sh       # Power management, services
./07-bootstrap.sh             # Final setup

reboot
```

## Default Credentials

- **User:** `cyber`
- **Password:** `cyber` (CHANGE THIS!)

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
│   ├── 00-rpiboot-setup.sh    # rpiboot for eMMC flashing
│   ├── 01-install.sh          # Universal installer (CM4/CM5, SD/eMMC/NVMe)
│   ├── 02-uconsole-drivers.sh # Hardware drivers
│   ├── 02a-modem-setup.sh     # 4G modem setup
│   ├── 03-install-hyprland.sh # Hyprland compositor
│   ├── 04-setup-environment.sh # Dev environment
│   ├── 05-install-security-tools.sh
│   ├── 06-system-services.sh  # Power management
│   └── 07-bootstrap.sh        # Final setup
├── configs/
│   ├── waybar/                # Status bar
│   ├── foot/                  # Terminal
│   ├── fuzzel/                # Launcher
│   └── mako/                  # Notifications
├── LICENSE
└── README.md
```

## CM5 Notes

The Raspberry Pi CM5 uses the BCM2712 SoC (same as Pi 5). Key differences:

- **Performance**: Faster CPU, PCIe Gen 3 support
- **Kernel**: May require `linux-rpi-16k` package
- **Drivers**: Some uConsole-specific drivers may need updates
- **Power**: Better power management, different thermal characteristics

The installer and driver scripts automatically detect CM4 vs CM5 and apply appropriate configurations.

## Customization

### Adding packages

Edit the relevant script in `scripts/` to add packages to the installation.

### Changing keybindings

Edit `~/.config/hypr/hyprland.conf`

### Theme colors

The setup uses Tokyo Night theme. Colors can be changed in:
- `~/.config/hypr/hyprland.conf`
- `~/.config/waybar/style.css`
- `~/.config/foot/foot.ini`
- `~/.config/nvim/init.lua`

## Troubleshooting

### Display not working
Check `/boot/config.txt` display settings. The uConsole uses a DSI display that may require specific overlays.

### WiFi issues
```bash
nmtui  # TUI network manager
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

### 4G Modem not working
```bash
# Check if modem is detected
lsusb | grep -i quectel
mmcli -L

# Check ModemManager status
systemctl status ModemManager

# Use modem helper
modem status
modem setup <your-apn>
modem connect
```

### NVMe not booting
```bash
# Check EEPROM boot order
sudo rpi-eeprom-config

# Update to boot from NVMe
sudo rpi-eeprom-config --edit
# Set: BOOT_ORDER=0xf416
```

### Battery not showing
The AXP228 power management chip requires specific kernel modules:
```bash
lsmod | grep axp
```

### Hyprland crashes
```bash
journalctl --user -u hyprland
cat ~/.local/share/hyprland/hyprland.log
```

## Tools Included

### Development
- Neovim with LSP (Python, Go, Rust, Lua)
- tmux with vim bindings
- Git + lazygit + delta
- fzf, ripgrep, fd, bat, eza

### Security
- Network: nmap, masscan, wireshark, tcpdump
- Web: nikto, sqlmap, gobuster, ffuf
- Password: john, hashcat, hydra
- Wireless: aircrack-ng
- Exploitation: metasploit, radare2, pwntools
- Forensics: sleuthkit, volatility3

### System
- Docker + docker-compose
- Ansible, Terraform
- TLP power management
- Zram swap

## License

MIT License - see [LICENSE](LICENSE)
