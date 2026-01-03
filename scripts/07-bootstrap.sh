#!/bin/bash
# =============================================================================
# uConsole Omarchy - Bootstrap Script
# Final configuration and system setup
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

[ "$EUID" -ne 0 ] && error "Run as root"

USERNAME="cyber"
USER_HOME="/home/${USERNAME}"

# =============================================================================
# Final Package Cleanup
# =============================================================================
log "Cleaning up packages..."

pacman -Rns $(pacman -Qdtq) 2>/dev/null || true
pacman -Scc --noconfirm

# =============================================================================
# Create Auto-start for Hyprland
# =============================================================================
log "Configuring auto-start..."

cat > ${USER_HOME}/.bash_profile << 'BASH_PROFILE'
# Auto-start Hyprland on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
BASH_PROFILE

# Also for zsh
cat > ${USER_HOME}/.zprofile << 'ZPROFILE'
# Auto-start Hyprland on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec Hyprland
fi
ZPROFILE

# =============================================================================
# Create System Info Script
# =============================================================================
log "Creating system info tools..."

cat > ${USER_HOME}/.local/bin/sysinfo << 'SYSINFO'
#!/bin/bash
# uConsole System Information

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}        ${GREEN}uConsole Omarchy${NC}               ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# System
echo -e "${YELLOW}System:${NC}"
echo "  Hostname: $(hostname)"
echo "  Kernel:   $(uname -r)"
echo "  Uptime:   $(uptime -p)"
echo ""

# Hardware
echo -e "${YELLOW}Hardware:${NC}"
echo "  CPU:      $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
echo "  Memory:   $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
echo "  Temp:     $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000 "°C"}' || echo "N/A")"
echo ""

# Battery
echo -e "${YELLOW}Battery:${NC}"
if command -v uconsole-battery-monitor &>/dev/null; then
    echo "  $(uconsole-battery-monitor)"
else
    echo "  Not available"
fi
echo ""

# Storage
echo -e "${YELLOW}Storage:${NC}"
df -h / | awk 'NR==2 {print "  Root: " $3 "/" $2 " (" $5 " used)"}'
echo ""

# Network
echo -e "${YELLOW}Network:${NC}"
echo "  WiFi:     $(iwgetid -r 2>/dev/null || echo "Not connected")"
echo "  IP:       $(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1 || echo "N/A")"
echo ""
SYSINFO
chmod +x ${USER_HOME}/.local/bin/sysinfo

# =============================================================================
# Create MOTD
# =============================================================================
log "Setting up MOTD..."

cat > /etc/motd << 'MOTD'

  ██╗   ██╗ ██████╗ ██████╗ ███╗   ██╗███████╗ ██████╗ ██╗     ███████╗
  ██║   ██║██╔════╝██╔═══██╗████╗  ██║██╔════╝██╔═══██╗██║     ██╔════╝
  ██║   ██║██║     ██║   ██║██╔██╗ ██║███████╗██║   ██║██║     █████╗
  ██║   ██║██║     ██║   ██║██║╚██╗██║╚════██║██║   ██║██║     ██╔══╝
  ╚██████╔╝╚██████╗╚██████╔╝██║ ╚████║███████║╚██████╔╝███████╗███████╗
   ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝
                        ╔═══════════════════╗
                        ║    O M A R C H Y  ║
                        ╚═══════════════════╝

MOTD

# =============================================================================
# Quick Reference Card
# =============================================================================
log "Creating quick reference..."

cat > ${USER_HOME}/.local/bin/keys << 'KEYS'
#!/bin/bash
# Hyprland Keybinding Reference

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                    HYPRLAND KEYBINDINGS                        ║
╠════════════════════════════════════════════════════════════════╣
║ SUPER + Return      Terminal          SUPER + Space    Launcher║
║ SUPER + Q           Kill window       SUPER + E        Files   ║
║ SUPER + V           Float toggle      SUPER + F        Fullscr ║
║ SUPER + H/J/K/L     Focus window      SUPER+SHIFT+HJKL Move    ║
║ SUPER + 1-6         Workspace         SUPER+SHIFT+1-6  MoveTo  ║
║ SUPER + Tab         Next workspace    SUPER + R        Resize  ║
║ SUPER + S           Scratchpad        SUPER + X        Power   ║
║ SUPER + B           Browser           SUPER+SHIFT+L    Lock    ║
║ Print               Screenshot        SHIFT+Print      Region  ║
╠════════════════════════════════════════════════════════════════╣
║                      TERMINAL (tmux)                           ║
╠════════════════════════════════════════════════════════════════╣
║ Ctrl+A |            Split horizontal  Ctrl+A -         VSplit  ║
║ Ctrl+A h/j/k/l      Navigate panes    Ctrl+A c         New win ║
║ Ctrl+A n/p          Next/prev window  Ctrl+A g         Lazygit ║
╠════════════════════════════════════════════════════════════════╣
║                        NEOVIM                                  ║
╠════════════════════════════════════════════════════════════════╣
║ Space + e           File explorer     Space + ff       Find    ║
║ Space + fg          Grep              Space + fb       Buffers ║
║ gd                  Go to definition  gr               Refs    ║
║ K                   Hover info        Space + ca       Actions ║
╚════════════════════════════════════════════════════════════════╝
EOF
KEYS
chmod +x ${USER_HOME}/.local/bin/keys

# =============================================================================
# Add welcome message to zshrc
# =============================================================================
cat >> ${USER_HOME}/.zshrc << 'WELCOME'

# Show system info on login (optional)
if [ -z "$TMUX" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    sysinfo
fi
WELCOME

# =============================================================================
# Enable Services
# =============================================================================
log "Enabling system services..."

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sshd
systemctl enable docker 2>/dev/null || true
systemctl enable tlp 2>/dev/null || true
systemctl enable uconsole-battery 2>/dev/null || true
systemctl enable seatd

# =============================================================================
# Set Permissions
# =============================================================================
log "Setting final permissions..."

chown -R ${USERNAME}:${USERNAME} ${USER_HOME}
chmod 700 ${USER_HOME}/.ssh 2>/dev/null || true
chmod 600 ${USER_HOME}/.ssh/* 2>/dev/null || true

# =============================================================================
# Generate SSH Key
# =============================================================================
log "Generating SSH key..."

if [ ! -f "${USER_HOME}/.ssh/id_ed25519" ]; then
    sudo -u ${USERNAME} ssh-keygen -t ed25519 -f ${USER_HOME}/.ssh/id_ed25519 -N "" -C "${USERNAME}@uconsole"
fi

# =============================================================================
# Final Summary
# =============================================================================
clear
echo ""
echo -e "${GREEN}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║   ██╗   ██╗ ██████╗ ██████╗ ███╗   ██╗███████╗ ██████╗ ██╗    ║
  ║   ██║   ██║██╔════╝██╔═══██╗████╗  ██║██╔════╝██╔═══██╗██║    ║
  ║   ██║   ██║██║     ██║   ██║██╔██╗ ██║███████╗██║   ██║██║    ║
  ║   ██║   ██║██║     ██║   ██║██║╚██╗██║╚════██║██║   ██║██║    ║
  ║   ╚██████╔╝╚██████╗╚██████╔╝██║ ╚████║███████║╚██████╔╝██████╗║
  ║    ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═════╝║
  ║                                                               ║
  ║              ╔═══════════════════════════╗                    ║
  ║              ║  O M A R C H Y   R E A D Y ║                    ║
  ║              ╚═══════════════════════════╝                    ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo ""
echo -e "${CYAN}Installation Complete!${NC}"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ User:     ${USERNAME} (password: cyber - CHANGE THIS!)                ║"
echo "║ Shell:    zsh + starship prompt                               ║"
echo "║ WM:       Hyprland (auto-starts on TTY1)                      ║"
echo "║ Terminal: foot                                                 ║"
echo "║ Editor:   neovim                                               ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║                         Quick Commands                         ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║ sysinfo   - System information                                 ║"
echo "║ keys      - Keybinding reference                               ║"
echo "║ lg        - Lazygit                                            ║"
echo "║ v         - Neovim                                             ║"
echo "║ update    - System update                                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Change default password: passwd"
echo "  2. Configure git: git config --global user.name/email"
echo "  3. Reboot: sudo reboot"
echo ""
echo -e "${GREEN}Enjoy your uConsole Omarchy!${NC}"
echo ""
