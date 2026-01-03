# uConsole Omarchy

A minimal, terminal-centric Arch Linux setup for ClockworkPi uConsole with Raspberry Pi CM4.

## Features

- **Arch Linux ARM** - Rolling release, minimal base
- **Hyprland** - Modern Wayland compositor with tiling
- **Development Environment** - Neovim, tmux, zsh, starship
- **Security Tools** - Pentesting, network analysis, forensics
- **Optimized for uConsole** - Battery management, power saving, small screen UI

## Requirements

- ClockworkPi uConsole with Raspberry Pi CM4 (8GB RAM recommended)
- MicroSD card (32GB+ recommended)
- Another Linux machine for initial SD card preparation

## Installation

### Phase 1: Prepare SD Card (on host machine)

```bash
# Clone this repo
git clone <repo-url> uconsole-omarchy
cd uconsole-omarchy

# Make scripts executable
chmod +x scripts/*.sh

# Prepare SD card (replace /dev/sdX with your device)
sudo ./scripts/01-base-install.sh /dev/sdX
```

### Phase 2: First Boot (on uConsole)

1. Insert SD card into uConsole and power on
2. Login as `alarm` / `alarm`
3. Switch to root: `su -` (password: `root`)
4. Run first boot setup:

```bash
./first-boot.sh
```

### Phase 3: Install Components

Copy the scripts to the uConsole and run in order:

```bash
# Transfer scripts (from host)
scp -r uconsole-omarchy alarm@<uconsole-ip>:~/

# On uConsole, as root:
cd ~/uconsole-omarchy/scripts

./02-uconsole-drivers.sh    # Hardware drivers
./02a-modem-setup.sh        # 4G modem + NetworkManager (if you have 4G module)
reboot

./03-install-hyprland.sh    # Hyprland + Wayland
./04-setup-environment.sh   # Dev tools, neovim, zsh
./05-install-security-tools.sh  # Security/hacking tools
./06-system-services.sh     # Power management, services
./07-bootstrap.sh           # Final setup

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
│   ├── 01-base-install.sh      # SD card preparation
│   ├── 02-uconsole-drivers.sh  # Hardware drivers
│   ├── 03-install-hyprland.sh  # Hyprland compositor
│   ├── 04-setup-environment.sh # Dev environment
│   ├── 05-install-security-tools.sh
│   ├── 06-system-services.sh   # Power management
│   └── 07-bootstrap.sh         # Final setup
├── configs/
│   ├── hyprland/               # Hyprland config
│   ├── waybar/                 # Status bar
│   ├── foot/                   # Terminal
│   ├── fuzzel/                 # Launcher
│   └── mako/                   # Notifications
└── README.md
```

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

### Battery not showing
The AXP228 power management chip requires specific kernel modules. Check if they're loaded:
```bash
lsmod | grep axp
```

### Hyprland crashes
Check logs:
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
