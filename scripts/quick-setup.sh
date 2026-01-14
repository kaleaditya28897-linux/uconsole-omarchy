#!/bin/bash
# =============================================================================
# uConsole Omarchy - Quick Setup Script
# Run this after booting from the PotatoMania base image
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

echo -e "${MAGENTA}"
cat << 'BANNER'
  ╔═══════════════════════════════════════════════════════════════╗
  ║               uConsole Omarchy - Quick Setup                  ║
  ║                                                               ║
  ║   Terminal-centric Arch Linux for your uConsole               ║
  ╚═══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo $0"
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Pre-flight checks
# =============================================================================
log "Running pre-flight checks..."

# Check if we're on the right image
if ! grep -q "aarch64\|arm" /proc/version 2>/dev/null; then
    error "This script must be run on an ARM system (uConsole)"
fi

# Check filesystem size
ROOT_SIZE=$(df -BG / | tail -1 | awk '{print $2}' | tr -d 'G')
if [ "$ROOT_SIZE" -lt 4 ]; then
    warn "Root filesystem is only ${ROOT_SIZE}GB"
    warn "Consider expanding it first:"
    warn "  sudo growpart /dev/mmcblk0 2"
    warn "  sudo resize2fs /dev/mmcblk0p2"
    echo ""
    read -p "Continue anyway? (y/N): " cont
    [ "$cont" != "y" ] && exit 1
fi

# =============================================================================
# Initialize pacman
# =============================================================================
log "Initializing package manager..."

if [ ! -f /etc/pacman.d/gnupg/trustdb.gpg ]; then
    pacman-key --init
    pacman-key --populate archlinux archlinuxarm
fi

log "Updating system packages..."
pacman -Syu --noconfirm

# =============================================================================
# Component selection
# =============================================================================
echo ""
echo "=============================================="
echo " Select components to install"
echo "=============================================="
echo ""
echo "1) Full install (Hyprland + Dev tools + Security tools)"
echo "2) Desktop only (Hyprland + basic tools)"
echo "3) Minimal (CLI tools only, no Hyprland)"
echo "4) Custom (choose each component)"
echo ""
read -p "Select option [1-4]: " INSTALL_OPTION

case "$INSTALL_OPTION" in
    1)
        INSTALL_HYPRLAND=true
        INSTALL_DEV=true
        INSTALL_SECURITY=true
        INSTALL_MODEM=false
        ;;
    2)
        INSTALL_HYPRLAND=true
        INSTALL_DEV=true
        INSTALL_SECURITY=false
        INSTALL_MODEM=false
        ;;
    3)
        INSTALL_HYPRLAND=false
        INSTALL_DEV=true
        INSTALL_SECURITY=false
        INSTALL_MODEM=false
        ;;
    4)
        read -p "Install Hyprland desktop? (Y/n): " yn
        INSTALL_HYPRLAND=$([[ "$yn" != "n" && "$yn" != "N" ]] && echo true || echo false)

        read -p "Install development tools? (Y/n): " yn
        INSTALL_DEV=$([[ "$yn" != "n" && "$yn" != "N" ]] && echo true || echo false)

        read -p "Install security/pentesting tools? (y/N): " yn
        INSTALL_SECURITY=$([[ "$yn" == "y" || "$yn" == "Y" ]] && echo true || echo false)

        read -p "Configure 4G modem? (y/N): " yn
        INSTALL_MODEM=$([[ "$yn" == "y" || "$yn" == "Y" ]] && echo true || echo false)
        ;;
    *)
        error "Invalid option"
        ;;
esac

# Ask about modem for options 1-3
if [ "$INSTALL_OPTION" != "4" ]; then
    read -p "Do you have a 4G modem to configure? (y/N): " yn
    INSTALL_MODEM=$([[ "$yn" == "y" || "$yn" == "Y" ]] && echo true || echo false)
fi

echo ""
log "Installation plan:"
info "  Hyprland:       $INSTALL_HYPRLAND"
info "  Dev tools:      $INSTALL_DEV"
info "  Security tools: $INSTALL_SECURITY"
info "  4G Modem:       $INSTALL_MODEM"
echo ""
read -p "Proceed with installation? (Y/n): " confirm
[[ "$confirm" == "n" || "$confirm" == "N" ]] && exit 0

# =============================================================================
# Run installation scripts
# =============================================================================

# Hardware configuration (always run)
log "Configuring hardware..."
"${SCRIPT_DIR}/02-uconsole-drivers.sh"

# 4G Modem
if [ "$INSTALL_MODEM" = true ]; then
    log "Configuring 4G modem..."
    "${SCRIPT_DIR}/02a-modem-setup.sh"
fi

# Hyprland
if [ "$INSTALL_HYPRLAND" = true ]; then
    log "Installing Hyprland..."
    "${SCRIPT_DIR}/03-install-hyprland.sh"
fi

# Development environment
if [ "$INSTALL_DEV" = true ]; then
    log "Installing development environment..."
    "${SCRIPT_DIR}/04-setup-environment.sh"
fi

# Security tools
if [ "$INSTALL_SECURITY" = true ]; then
    log "Installing security tools..."
    "${SCRIPT_DIR}/05-install-security-tools.sh"
fi

# System services (always run)
log "Configuring system services..."
"${SCRIPT_DIR}/06-system-services.sh"

# Bootstrap (always run)
log "Running final bootstrap..."
"${SCRIPT_DIR}/07-bootstrap.sh"

# =============================================================================
# Post-install summary
# =============================================================================
echo ""
echo -e "${GREEN}=============================================="
echo " Installation Complete!"
echo "==============================================${NC}"
echo ""
info "Default user: cyber (password: cyber)"
info "CHANGE THIS PASSWORD: passwd cyber"
echo ""

if [ "$INSTALL_HYPRLAND" = true ]; then
    info "To start Hyprland:"
    info "  1. Login as 'cyber'"
    info "  2. Run: Hyprland"
    echo ""
    info "Or add auto-start to ~/.bash_profile"
fi

echo ""
log "Rebooting in 10 seconds... (Ctrl+C to cancel)"
sleep 10
reboot
